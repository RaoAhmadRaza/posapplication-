import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/number_series_info.dart';
import '../../domain/usecases/settings_usecases.dart';

/// Read-only list of number series. No mutations exposed (config is fixed here).
final numberSeriesProvider =
    FutureProvider<List<NumberSeriesInfo>>((ref) async {
  final (series, failure) = await ref.read(loadNumberSeriesUseCaseProvider)();
  if (failure != null) throw failure;
  return series;
});
