enum StockCountStatus {
  draft,
  inProgress,
  completed,
  cancelled,
}

extension StockCountStatusX on StockCountStatus {
  String get dbValue {
    switch (this) {
      case StockCountStatus.draft: return 'DRAFT';
      case StockCountStatus.inProgress: return 'IN_PROGRESS';
      case StockCountStatus.completed: return 'COMPLETED';
      case StockCountStatus.cancelled: return 'CANCELLED';
    }
  }

  static StockCountStatus fromDb(String value) {
    switch (value) {
      case 'DRAFT': return StockCountStatus.draft;
      case 'IN_PROGRESS': return StockCountStatus.inProgress;
      case 'COMPLETED': return StockCountStatus.completed;
      case 'CANCELLED': return StockCountStatus.cancelled;
      default: throw ArgumentError('Unknown stock_count_status: $value');
    }
  }
}
