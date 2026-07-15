/// The subset of ui_preferences the Settings hub edits (theme/language/default branch).
class UiPreferences {
  final String theme;
  final String language;
  final String? defaultBranchId;

  const UiPreferences({
    required this.theme,
    required this.language,
    required this.defaultBranchId,
  });

  static const empty =
      UiPreferences(theme: 'light', language: 'en', defaultBranchId: null);
}
