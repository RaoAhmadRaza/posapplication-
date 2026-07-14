import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/drilldown.dart';
import '../../domain/usecases/load_drilldown.dart';

/// Loads a drilldown list for the given args; cached per-args via family.
final drilldownProvider =
    FutureProvider.autoDispose.family<List<DrilldownRow>, DrilldownArgs>(
  (ref, args) async {
    final (rows, failure) =
        await ref.read(loadDrilldownUseCaseProvider).call(args);
    if (failure != null) throw failure;
    return rows;
  },
);
