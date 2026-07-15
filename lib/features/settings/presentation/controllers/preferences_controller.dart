import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/ui_preferences.dart';
import '../../domain/failures/settings_failure.dart';
import '../../domain/usecases/settings_usecases.dart';

final preferencesProvider =
    AsyncNotifierProvider<PreferencesController, UiPreferences>(
  PreferencesController.new,
);

class PreferencesController extends AsyncNotifier<UiPreferences> {
  @override
  Future<UiPreferences> build() async {
    final (prefs, failure) = await ref.read(loadUiPreferencesUseCaseProvider)();
    if (failure != null) throw failure;
    return prefs;
  }

  /// Saves the changed fields (coalesce-merge server-side) and reflects them.
  Future<SettingsFailure?> save({
    String? theme,
    String? language,
    String? defaultBranchId,
  }) async {
    final failure = await ref.read(saveUiPreferencesUseCaseProvider)(
      theme: theme,
      language: language,
      defaultBranchId: defaultBranchId,
    );
    if (failure != null) return failure;
    final current = state.value ?? UiPreferences.empty;
    state = AsyncData(UiPreferences(
      theme: theme ?? current.theme,
      language: language ?? current.language,
      defaultBranchId: defaultBranchId ?? current.defaultBranchId,
    ));
    return null;
  }
}
