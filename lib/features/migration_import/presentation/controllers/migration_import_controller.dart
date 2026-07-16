import 'dart:convert';
import 'dart:io' show File;

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../inventory/domain/failures/inventory_failure.dart';
import '../../../inventory/presentation/controllers/brands_controller.dart';
import '../../../inventory/presentation/controllers/categories_controller.dart';
import '../../../inventory/presentation/controllers/products_controller.dart';
import '../../../inventory/presentation/controllers/stock_levels_controller.dart';
import '../../domain/entities/import_result.dart';
import '../../domain/usecases/import_brands.dart';
import '../../domain/usecases/import_categories.dart';
import '../../domain/usecases/import_products.dart';
import '../../domain/usecases/import_stock.dart';

class MigrationImportProgress {
  final int done;
  final int total;

  const MigrationImportProgress({required this.done, required this.total});
}

class MigrationImportState {
  final String? fileName;
  final ImportTableKind? kind;
  final int parsedRowCount;
  final List<Map<String, dynamic>> preview;
  final ImportResult? result;
  final InventoryFailure? failure;
  final MigrationImportProgress? progress;
  final List<String> logs;
  final bool running;

  const MigrationImportState({
    this.fileName,
    this.kind,
    this.parsedRowCount = 0,
    this.preview = const [],
    this.result,
    this.failure,
    this.progress,
    this.logs = const [],
    this.running = false,
  });

  MigrationImportState copyWith({
    String? fileName,
    ImportTableKind? kind,
    int? parsedRowCount,
    List<Map<String, dynamic>>? preview,
    ImportResult? result,
    InventoryFailure? failure,
    MigrationImportProgress? progress,
    List<String>? logs,
    bool? running,
    bool clearResult = false,
    bool clearFailure = false,
    bool clearProgress = false,
    bool clearLogs = false,
    bool appendLog = false,
    String? logEntry,
  }) {
    List<String> nextLogs;
    if (appendLog && logEntry != null) {
      nextLogs = [
        ...(logs ?? this.logs),
        '${DateTime.now().toIso8601String().substring(11, 23)} $logEntry',
      ];
    } else if (clearLogs) {
      nextLogs = [];
    } else {
      nextLogs = logs ?? this.logs;
    }
    return MigrationImportState(
      fileName: fileName ?? this.fileName,
      kind: kind ?? this.kind,
      parsedRowCount: parsedRowCount ?? this.parsedRowCount,
      preview: preview ?? this.preview,
      result: clearResult ? null : (result ?? this.result),
      failure: clearFailure ? null : (failure ?? this.failure),
      progress: clearProgress ? null : (progress ?? this.progress),
      logs: nextLogs,
      running: running ?? this.running,
    );
  }
}

final migrationImportProvider =
    NotifierProvider<MigrationImportController, MigrationImportState>(
  MigrationImportController.new,
);

class MigrationImportController extends Notifier<MigrationImportState> {
  @override
  MigrationImportState build() => const MigrationImportState();

  static const _chunkSize = 2000;
  static const _chunkSizeStock = 1000;

  static const _fieldsByKind = <ImportTableKind, List<String>>{
    ImportTableKind.categories: ['id', 'name', 'slug', 'is_active', 'sort_order'],
    ImportTableKind.brands: ['id', 'name', 'slug', 'is_active'],
    ImportTableKind.products: [
      'id', 'sku', 'barcode', 'name', 'description', 'brand_id',
      'category_id', 'selling_price', 'cost_price', 'min_selling_price',
      'wholesale_price', 'unit_of_measure', 'tax_rate', 'reorder_point',
      'is_active', 'status', 'type',
    ],
    ImportTableKind.stock: ['product_id', 'qty_on_hand', 'avg_cost'],
  };

  List<Map<String, dynamic>> _rows = [];

  static final _csv = Csv(
    autoDetect: false,
    skipEmptyLines: true,
  );

  void _log(String m) {
    state = state.copyWith(appendLog: true, logEntry: m);
  }

  int _chunkSizeFor(ImportTableKind kind) {
    return switch (kind) {
      ImportTableKind.stock => _chunkSizeStock,
      _ => _chunkSize,
    };
  }

  Future<void> pickAndParse(ImportTableKind kind) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final f = result.files.first;
    String content;
    if (f.bytes != null) {
      content = utf8.decode(f.bytes!, allowMalformed: true);
    } else if (f.path != null) {
      content = await File(f.path!).readAsString();
    } else {
      content = '';
    }

    state = state.copyWith(
      fileName: f.name,
      kind: kind,
      clearResult: true,
      clearFailure: true,
      clearLogs: true,
    );

    if (content.trim().isEmpty) {
      _log('ERROR: file content is empty');
      state = state.copyWith(parsedRowCount: 0, preview: []);
      return;
    }

    final parsed = _csv.decode(content);
    if (parsed.isEmpty) {
      _log('ERROR: csv decoded to 0 rows');
      state = state.copyWith(parsedRowCount: 0, preview: []);
      return;
    }

    _log('Parsed ${parsed.length} CSV rows (header + ${parsed.length - 1} data)');

    final headers = parsed.first.map((c) => c.toString().trim()).toList();
    final allowed = _fieldsByKind[kind]!;
    final keepIndices = <int>[];
    for (var i = 0; i < headers.length; i++) {
      if (allowed.contains(headers[i])) {
        keepIndices.add(i);
      }
    }
    _log('Headers matched: ${keepIndices.length}/${headers.length} (kept: ${keepIndices.map((i) => headers[i]).join(', ')})');

    final rows = <Map<String, dynamic>>[];
    for (var r = 1; r < parsed.length; r++) {
      final row = <String, dynamic>{};
      for (final idx in keepIndices) {
        final val = idx < parsed[r].length
            ? parsed[r][idx].toString().trim()
            : '';
        row[headers[idx]] = val;
      }
      if (row.isNotEmpty) rows.add(row);
    }

    _rows = rows;
    _log('Mapped ${rows.length} data rows');

    state = state.copyWith(
      parsedRowCount: rows.length,
      preview: rows.take(20).toList(),
    );
  }

  Future<void> run(ImportTableKind kind, {String? branchId}) async {
    if (_rows.isEmpty) {
      _log('ERROR: no rows to import');
      state = state.copyWith(
        failure: UnknownFailure('No rows to import. Pick a CSV file first.'),
        clearResult: true,
      );
      return;
    }

    final payload = _rows;
    final total = payload.length;
    final chunkSize = _chunkSizeFor(kind);
    final numChunks = (total / chunkSize).ceil();
    _log('START kind=$kind total=$total chunkSize=$chunkSize numChunks=$numChunks');

    state = state.copyWith(
      running: true,
      progress: const MigrationImportProgress(done: 0, total: 0),
      clearResult: true,
      clearFailure: true,
    );

    var totalInserted = 0;
    var totalSkipped = 0;
    var totalOk = 0;
    var totalFailed = 0;
    final allErrors = <ImportRowError>[];
    ImportResult? finalResult;
    InventoryFailure? topFailure;

    try {
      for (var offset = 0; offset < total; offset += chunkSize) {
        final end =
            (offset + chunkSize > total) ? total : offset + chunkSize;
        final chunk = payload.sublist(offset, end);
        final chunkIndex = (offset ~/ chunkSize) + 1;
        _log('  chunk $chunkIndex/$numChunks: offset=$offset end=$end size=${chunk.length}');

        ImportResult? chunkResult;
        InventoryFailure? chunkFailure;
        switch (kind) {
          case ImportTableKind.categories:
            (chunkResult, chunkFailure) =
                await ref.read(importCategoriesUseCaseProvider).call(chunk);
          case ImportTableKind.brands:
            (chunkResult, chunkFailure) =
                await ref.read(importBrandsUseCaseProvider).call(chunk);
          case ImportTableKind.products:
            (chunkResult, chunkFailure) =
                await ref.read(importProductsUseCaseProvider).call(chunk);
          case ImportTableKind.stock:
            if (branchId == null) {
              chunkFailure =
                  UnknownFailure('No branch selected for stock import.');
              _log('  ERROR: no branchId for stock');
              break;
            }
            (chunkResult, chunkFailure) = await ref
                .read(importStockUseCaseProvider)
                .call(branchId, chunk);
        }

        if (chunkResult != null) {
          totalInserted += chunkResult.inserted;
          totalSkipped += chunkResult.skipped;
          totalOk += chunkResult.ok;
          totalFailed += chunkResult.failed;
          for (final e in chunkResult.errors) {
            allErrors.add(ImportRowError(
              row: e.row + offset + 1,
              error: e.error,
            ));
          }
          _log('  -> ins=${chunkResult.inserted} skp=${chunkResult.skipped} fail=${chunkResult.failed} errs=${chunkResult.errors.length}');
        } else if (chunkFailure != null) {
          totalFailed += chunk.length;
          allErrors.add(ImportRowError(
            row: offset + 1,
            error: chunkFailure.message,
          ));
          _log('  -> FAILED whole chunk: ${chunkFailure.message}');
        }

        state = state.copyWith(
          progress: MigrationImportProgress(done: end, total: total),
        );
      }

      _log('LOOP DONE totalOk=$totalOk inserted=$totalInserted skipped=$totalSkipped failed=$totalFailed errors=${allErrors.length}');

      finalResult = ImportResult(
        ok: totalOk,
        inserted: totalInserted,
        skipped: totalSkipped,
        failed: totalFailed,
        errors: allErrors,
      );

      if (finalResult.ok > 0) {
        _log('SUCCESS: invalidating providers + clearing rows');
        switch (kind) {
          case ImportTableKind.categories:
            ref.invalidate(categoriesProvider);
          case ImportTableKind.brands:
            ref.invalidate(brandsProvider);
          case ImportTableKind.products:
            ref.invalidate(productsProvider);
          case ImportTableKind.stock:
            ref.invalidate(stockLevelsProvider);
        }
        _rows = [];
      } else {
        _log('WARNING: 0 rows imported (all failed or skipped)');
      }
    } catch (e) {
      _log('CAUGHT top-level: $e (${e.runtimeType})');
      finalResult = ImportResult(
        ok: totalOk,
        inserted: totalInserted,
        skipped: totalSkipped,
        failed: totalFailed,
        errors: allErrors,
      );
      topFailure = UnknownFailure('$e (${e.runtimeType})');
    } finally {
      final resultStr = finalResult != null
          ? 'ok=${finalResult.ok} failed=${finalResult.failed}'
          : 'null';
      _log('FINISHED: result=$resultStr failure=$topFailure');
      state = state.copyWith(
        result: finalResult,
        failure: topFailure,
        running: false,
        clearProgress: true,
      );
    }
  }
}
