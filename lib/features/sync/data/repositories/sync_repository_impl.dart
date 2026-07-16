import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase.dart';
import '../../domain/entities/cached_customer.dart';
import '../../domain/entities/cached_product.dart';
import '../../domain/entities/outbox_entry.dart';
import '../../domain/entities/sale_intent.dart';
import '../../domain/entities/sync_exception.dart';
import '../../domain/failures/sync_failure.dart';
import '../../domain/repositories/sync_repository.dart';
import '../datasources/sync_local_datasource.dart';
import '../datasources/sync_remote_datasource.dart';

class SyncRepositoryImpl implements SyncRepository {
  SyncRepositoryImpl(this._remote, this._local);
  final SyncRemoteDataSource _remote;
  final SyncLocalDataSource _local;

  @override
  Future<SyncFailure?> pullReference() async {
    try {
      final since = await _local.getWatermark();
      final res = await _remote.pullReference(since);

      final products = (res['products'] as List?) ?? const [];
      final pUpserts = <Map<String, Object?>>[];
      final pDeleted = <String>[];
      for (final row in products.cast<Map<String, dynamic>>()) {
        if (row['deleted_at'] != null) {
          pDeleted.add(row['id'] as String);
        } else {
          pUpserts.add(_productRow(row));
        }
      }
      await _local.applyProducts(pUpserts, pDeleted);

      final customers = (res['customers'] as List?) ?? const [];
      final cUpserts = <Map<String, Object?>>[];
      final cDeleted = <String>[];
      for (final row in customers.cast<Map<String, dynamic>>()) {
        if (row['deleted_at'] != null) {
          cDeleted.add(row['id'] as String);
        } else {
          cUpserts.add(_customerRow(row));
        }
      }
      await _local.applyCustomers(cUpserts, cDeleted);

      final watermark = res['watermark'];
      if (watermark != null) await _local.setWatermark(watermark.toString());
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<(List<CachedProduct>, SyncFailure?)> searchProducts(String query) async {
    try {
      final rows = await _local.searchProducts(query);
      return (rows.map(_cachedProduct).toList(), null);
    } catch (e) {
      return (<CachedProduct>[], _cache(e));
    }
  }

  @override
  Future<(CachedProduct?, SyncFailure?)> productById(String id) async {
    try {
      final row = await _local.productById(id);
      return (row == null ? null : _cachedProduct(row), null);
    } catch (e) {
      return (null, _cache(e));
    }
  }

  @override
  Future<(List<CachedCustomer>, SyncFailure?)> loadCustomers() async {
    try {
      final rows = await _local.allCustomers();
      return (rows.map(_cachedCustomer).toList(), null);
    } catch (e) {
      return (<CachedCustomer>[], _cache(e));
    }
  }

  @override
  Future<SyncFailure?> enqueueSaleIntent(SaleIntent intent) async {
    try {
      await _local.insertOutbox({
        'id': intent.id,
        'idempotency_key': intent.idempotencyKey,
        'intent_type': 'SALE',
        'payload_json': jsonEncode(intent.payload),
        'client_created_at': intent.clientCreatedAt,
        'local_ref': intent.localRef,
        'status': intent.status,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return null;
    } catch (e) {
      return _cache(e);
    }
  }

  @override
  Future<(int, SyncFailure?)> pendingIntentCount() async {
    try {
      return (await _local.pendingCount(), null);
    } catch (e) {
      return (0, _cache(e));
    }
  }

  @override
  Future<(DrainSummary, SyncFailure?)> drainOutbox() async {
    try {
      final rows = await _local.drainable(); // OLDEST-FIRST
      var applied = 0, abandoned = 0, failed = 0;
      // ONE AT A TIME — serial replay is the whole reason there is nothing to merge.
      for (final row in rows) {
        final id = row['id'] as String;
        final key = row['idempotency_key'] as String;
        final localRef = (row['local_ref'] as String?) ?? '';
        final clientCreatedAt = row['client_created_at'] as String;
        final payload = jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
        final branchId = payload['branch_id'] as String;

        Map<String, dynamic> push;
        try {
          push = await _remote.pushIntent(
            idempotencyKey: key,
            branchId: branchId,
            payload: payload,
            clientCreatedAt: clientCreatedAt,
            localRef: localRef,
            deviceId: payload['device_id'] as String?,
          );
        } catch (e) {
          await _local.markFailed(id, null, _mapError(e).message);
          failed++;
          continue;
        }
        final oid = push['outbox_id'] as String?;
        if (oid == null) {
          await _local.markFailed(id, null, 'push returned no outbox id');
          failed++;
          continue;
        }
        // Already applied server-side (a prior drain got this far) → reconcile only.
        if (push['status'] == 'APPLIED') {
          await _reconcileApplied(id, oid, key, null);
          applied++;
          continue;
        }

        Map<String, dynamic> rep;
        try {
          rep = await _remote.replayIntent(oid);
        } catch (e) {
          await _local.markFailed(id, oid, _mapError(e).message);
          failed++;
          continue;
        }
        if (rep['applied'] == true || rep['skipped'] == true) {
          await _reconcileApplied(id, oid, key, rep['invoice_id']?.toString());
          applied++;
        } else if (rep['terminal'] == true) {
          await _local.markAbandoned(id, oid, rep['error']?.toString() ?? 'terminal failure');
          abandoned++;
        } else {
          await _local.markFailed(id, oid, rep['error']?.toString() ?? 'transient failure');
          failed++;
        }
      }
      await _local.setLastSyncAt(DateTime.now().toUtc().toIso8601String());
      return ((applied: applied, abandoned: abandoned, failed: failed), null);
    } catch (e) {
      return ((applied: 0, abandoned: 0, failed: 0), _mapError(e));
    }
  }

  Future<void> _reconcileApplied(
      String id, String oid, String key, String? invoiceId) async {
    // Fetch the REAL invoice number so provisional paper (local_ref) is searchable.
    final inv = await _remote.invoiceForKey(key);
    await _local.markApplied(
        id, oid, (invoiceId ?? inv?['id'])?.toString(), inv?['invoice_number']?.toString());
  }

  @override
  Future<(List<OutboxEntry>, SyncFailure?)> loadIntents() async {
    try {
      final rows = await _local.allIntents();
      return (rows.map(_outboxEntry).toList(), null);
    } catch (e) {
      return (<OutboxEntry>[], _cache(e));
    }
  }

  @override
  Future<(List<OutboxEntry>, SyncFailure?)> findByRef(String query) async {
    try {
      final rows = await _local.findByRef(query);
      return (rows.map(_outboxEntry).toList(), null);
    } catch (e) {
      return (<OutboxEntry>[], _cache(e));
    }
  }

  @override
  Future<(List<SyncException>, SyncFailure?)> loadOpenExceptions() async {
    try {
      final rows = await _remote.loadOpenExceptions();
      return (rows.map(_syncException).toList(), null);
    } catch (e) {
      return (<SyncException>[], _mapError(e));
    }
  }

  @override
  Future<SyncFailure?> resolveException(String id, String note) async {
    try {
      await _remote.resolveException(id, note);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<SyncFailure?> retryIntent(String outboxId) async {
    try {
      await _remote.retryIntent(outboxId);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<String?> lastSyncAt() => _local.getLastSyncAt();

  OutboxEntry _outboxEntry(Map<String, Object?> r) => OutboxEntry(
        id: r['id'] as String,
        idempotencyKey: r['idempotency_key'] as String,
        localRef: (r['local_ref'] as String?) ?? '',
        invoiceNumber: r['invoice_number'] as String?,
        status: (r['status'] as String?) ?? 'PENDING',
        clientCreatedAt: (r['client_created_at'] as String?) ?? '',
        attempts: (r['attempts'] as int?) ?? 0,
        lastError: r['last_error'] as String?,
      );

  SyncException _syncException(Map<String, dynamic> j) {
    final raw = j['payload_json'];
    final payload = raw is Map
        ? raw.cast<String, dynamic>()
        : (raw is String ? jsonDecode(raw) as Map<String, dynamic> : <String, dynamic>{});
    return SyncException(
      id: j['id'] as String,
      outboxId: j['outbox_id'] as String,
      errorCode: (j['error_code'] as String?) ?? 'ERR_UNKNOWN',
      errorDetail: j['error_detail'] as String?,
      payload: payload,
      createdAt: (j['created_at'] as String?) ?? '',
    );
  }

  // ---- mapping -------------------------------------------------------------
  Map<String, Object?> _productRow(Map<String, dynamic> j) => {
        'id': j['id'],
        'sku': j['sku'],
        'name': j['name'],
        'barcode': j['barcode'],
        'selling_price': _num(j['selling_price']),
        'min_selling_price': _num(j['min_selling_price']),
        'tax_rate': _num(j['tax_rate']) ?? 0,
        'tax_inclusive': (j['tax_inclusive'] == true) ? 1 : 0,
        'is_active': (j['is_active'] == false) ? 0 : 1,
        'updated_at': j['updated_at']?.toString(),
      };

  Map<String, Object?> _customerRow(Map<String, dynamic> j) => {
        'id': j['id'],
        'name': j['name'],
        'phone': j['phone'],
        'credit_limit': _num(j['credit_limit']) ?? 0,
        'status': j['status']?.toString(),
        'updated_at': j['updated_at']?.toString(),
      };

  CachedProduct _cachedProduct(Map<String, Object?> r) => CachedProduct(
        id: r['id'] as String,
        sku: (r['sku'] as String?) ?? '',
        name: (r['name'] as String?) ?? '',
        barcode: r['barcode'] as String?,
        sellingPrice: (r['selling_price'] as num?)?.toDouble() ?? 0,
        minSellingPrice: (r['min_selling_price'] as num?)?.toDouble(),
        taxRate: (r['tax_rate'] as num?)?.toDouble() ?? 0,
        taxInclusive: (r['tax_inclusive'] as int? ?? 0) == 1,
        isActive: (r['is_active'] as int? ?? 1) == 1,
        updatedAt: (r['updated_at'] as String?) ?? '',
      );

  CachedCustomer _cachedCustomer(Map<String, Object?> r) => CachedCustomer(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? '',
        phone: r['phone'] as String?,
        creditLimit: (r['credit_limit'] as num?)?.toDouble() ?? 0,
        status: (r['status'] as String?) ?? '',
        updatedAt: (r['updated_at'] as String?) ?? '',
      );

  double? _num(Object? v) => v == null ? null : (v as num).toDouble();

  SyncFailure _mapError(Object e) {
    if (e is PostgrestException) {
      if (e.code == '42501' ||
          e.message.toLowerCase().contains('permission')) {
        return const SyncPermissionFailure();
      }
      return SyncUnknownFailure(e.message);
    }
    if (e is SocketException || e is TimeoutException) {
      return const SyncNetworkFailure();
    }
    return SyncUnknownFailure(e.toString());
  }

  SyncFailure _cache(Object e) => SyncCacheFailure(e.toString());
}

// ---- providers (feature wiring) --------------------------------------------
final syncLocalDataSourceProvider =
    Provider<SyncLocalDataSource>((ref) => SyncLocalDataSource());

final syncRemoteDataSourceProvider =
    Provider<SyncRemoteDataSource>((ref) => SyncRemoteDataSource(supabase));

final syncRepositoryProvider = Provider<SyncRepository>((ref) => SyncRepositoryImpl(
      ref.read(syncRemoteDataSourceProvider),
      ref.read(syncLocalDataSourceProvider),
    ));
