import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The ONLY place sqflite is touched for the sync feature. Hand-written DAOs,
/// raw SQL — NO drift/isar/build_runner (standing project rule). The database is
/// opened lazily on first use and cached.
class SyncLocalDataSource {
  Database? _db;

  static const _dbName = 'lumina_sync.db';
  static const _watermarkKey = 'reference_watermark';

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(path,
        version: 2, onCreate: _createSchema, onUpgrade: _upgrade);
    return _db!;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ref_products(
        id TEXT PRIMARY KEY, sku TEXT, name TEXT, barcode TEXT,
        selling_price REAL, min_selling_price REAL, tax_rate REAL,
        tax_inclusive INTEGER, is_active INTEGER, updated_at TEXT
      )''');
    await db.execute('''
      CREATE TABLE ref_customers(
        id TEXT PRIMARY KEY, name TEXT, phone TEXT, credit_limit REAL,
        status TEXT, updated_at TEXT
      )''');
    await db.execute('''
      CREATE TABLE outbox(
        id TEXT PRIMARY KEY, idempotency_key TEXT NOT NULL, intent_type TEXT NOT NULL,
        payload_json TEXT NOT NULL, client_created_at TEXT NOT NULL, local_ref TEXT,
        status TEXT NOT NULL DEFAULT 'PENDING', created_at TEXT NOT NULL,
        server_outbox_id TEXT, invoice_id TEXT, invoice_number TEXT,
        attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT, synced_at TEXT
      )''');
    await db.execute(
        'CREATE TABLE sync_meta(key TEXT PRIMARY KEY, value TEXT)');
    await db.execute('CREATE INDEX idx_products_name ON ref_products(name)');
    await db.execute('CREATE INDEX idx_outbox_local_ref ON outbox(local_ref)');
  }

  // v1 → v2: reconciliation + drain bookkeeping columns on the outbox.
  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      for (final col in const [
        'server_outbox_id TEXT',
        'invoice_id TEXT',
        'invoice_number TEXT',
        'attempts INTEGER NOT NULL DEFAULT 0',
        'last_error TEXT',
        'synced_at TEXT',
      ]) {
        await db.execute('ALTER TABLE outbox ADD COLUMN $col');
      }
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_outbox_local_ref ON outbox(local_ref)');
    }
  }

  // ---- watermark -----------------------------------------------------------
  Future<String?> getWatermark() async {
    final db = await _open();
    final rows = await db.query('sync_meta',
        where: 'key = ?', whereArgs: [_watermarkKey], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setWatermark(String value) async {
    final db = await _open();
    await db.insert('sync_meta', {'key': _watermarkKey, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---- reference upsert / evict (one delete signal: deleted_at present) -----
  Future<void> applyProducts(
      List<Map<String, Object?>> upserts, List<String> deletedIds) async {
    final db = await _open();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in deletedIds) {
        batch.delete('ref_products', where: 'id = ?', whereArgs: [id]);
      }
      for (final row in upserts) {
        batch.insert('ref_products', row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> applyCustomers(
      List<Map<String, Object?>> upserts, List<String> deletedIds) async {
    final db = await _open();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in deletedIds) {
        batch.delete('ref_customers', where: 'id = ?', whereArgs: [id]);
      }
      for (final row in upserts) {
        batch.insert('ref_customers', row,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  // ---- cache-first reads ---------------------------------------------------
  Future<List<Map<String, Object?>>> searchProducts(String query) async {
    final db = await _open();
    final like = '%${query.trim()}%';
    return db.query('ref_products',
        where:
            'is_active = 1 AND (name LIKE ? OR sku LIKE ? OR barcode LIKE ?)',
        whereArgs: [like, like, like],
        orderBy: 'name',
        limit: 50);
  }

  Future<Map<String, Object?>?> productById(String id) async {
    final db = await _open();
    final rows =
        await db.query('ref_products', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> allCustomers() async {
    final db = await _open();
    return db.query('ref_customers', orderBy: 'name', limit: 500);
  }

  // ---- outbox --------------------------------------------------------------
  Future<void> insertOutbox(Map<String, Object?> row) async {
    final db = await _open();
    await db.insert('outbox', row,
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> pendingCount() async {
    final db = await _open();
    final rows = await db.rawQuery(
        "SELECT COUNT(*) AS n FROM outbox WHERE status IN ('PENDING','FAILED')");
    return (rows.first['n'] as int?) ?? 0;
  }

  // ---- drain (oldest-first, serial) ----------------------------------------
  static const maxAttempts = 5; // ponytail: transient retry cap; then it waits for a manual retry

  Future<List<Map<String, Object?>>> drainable() async {
    final db = await _open();
    // PENDING first, then FAILED under the retry cap; strictly oldest-first.
    return db.query('outbox',
        where: "status = 'PENDING' OR (status = 'FAILED' AND attempts < ?)",
        whereArgs: [maxAttempts],
        orderBy: 'client_created_at ASC');
  }

  Future<void> markApplied(String id, String serverOutboxId, String? invoiceId,
      String? invoiceNumber) async {
    final db = await _open();
    await db.update(
        'outbox',
        {
          'status': 'DONE',
          'server_outbox_id': serverOutboxId,
          'invoice_id': invoiceId,
          'invoice_number': invoiceNumber,
          'last_error': null,
          'synced_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> markAbandoned(
      String id, String serverOutboxId, String error) async {
    final db = await _open();
    await db.update(
        'outbox',
        {'status': 'ABANDONED', 'server_outbox_id': serverOutboxId, 'last_error': error},
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> markFailed(String id, String? serverOutboxId, String error) async {
    final db = await _open();
    await db.rawUpdate(
        'UPDATE outbox SET status = ?, server_outbox_id = ?, last_error = ?, attempts = attempts + 1 WHERE id = ?',
        ['FAILED', serverOutboxId, error, id]);
  }

  Future<List<Map<String, Object?>>> allIntents() async {
    final db = await _open();
    return db.query('outbox', orderBy: 'client_created_at DESC', limit: 200);
  }

  /// Reconciliation: a customer with provisional paper (local_ref) can be found
  /// by local_ref OR the real invoice_number once it applied.
  Future<List<Map<String, Object?>>> findByRef(String query) async {
    final db = await _open();
    final like = '%${query.trim()}%';
    return db.query('outbox',
        where: 'local_ref LIKE ? OR invoice_number LIKE ?',
        whereArgs: [like, like],
        orderBy: 'client_created_at DESC',
        limit: 50);
  }

  Future<String?> getLastSyncAt() async {
    final db = await _open();
    final rows = await db.query('sync_meta',
        where: 'key = ?', whereArgs: ['last_sync_at'], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setLastSyncAt(String value) async {
    final db = await _open();
    await db.insert('sync_meta', {'key': 'last_sync_at', 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
