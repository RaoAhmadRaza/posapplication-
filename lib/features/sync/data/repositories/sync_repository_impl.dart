import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase.dart';
import '../../domain/entities/cached_customer.dart';
import '../../domain/entities/cached_product.dart';
import '../../domain/entities/sale_intent.dart';
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
