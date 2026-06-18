class ImportResult {
  final int ok;
  final int inserted;
  final int skipped;
  final int failed;
  final List<ImportRowError> errors;

  const ImportResult({
    required this.ok,
    this.inserted = 0,
    this.skipped = 0,
    required this.failed,
    required this.errors,
  });
}

class ImportRowError {
  final int row;
  final String error;

  const ImportRowError({required this.row, required this.error});
}

enum ImportTableKind { categories, brands, products, stock }
