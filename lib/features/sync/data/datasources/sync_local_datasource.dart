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
    _db = await openDatabase(path, version: 1, onCreate: _createSchema);
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
        status TEXT NOT NULL DEFAULT 'PENDING', created_at TEXT NOT NULL
      )''');
    await db.execute(
        'CREATE TABLE sync_meta(key TEXT PRIMARY KEY, value TEXT)');
    await db.execute('CREATE INDEX idx_products_name ON ref_products(name)');
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
        "SELECT COUNT(*) AS n FROM outbox WHERE status = 'PENDING'");
    return (rows.first['n'] as int?) ?? 0;
  }
}
