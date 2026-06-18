enum StockTransferStatus {
  draft,
  inTransit,
  partiallyReceived,
  received,
  cancelled,
}

extension StockTransferStatusX on StockTransferStatus {
  String get dbValue {
    switch (this) {
      case StockTransferStatus.draft: return 'DRAFT';
      case StockTransferStatus.inTransit: return 'IN_TRANSIT';
      case StockTransferStatus.partiallyReceived: return 'PARTIALLY_RECEIVED';
      case StockTransferStatus.received: return 'RECEIVED';
      case StockTransferStatus.cancelled: return 'CANCELLED';
    }
  }

  static StockTransferStatus fromDb(String value) {
    switch (value) {
      case 'DRAFT': return StockTransferStatus.draft;
      case 'IN_TRANSIT': return StockTransferStatus.inTransit;
      case 'PARTIALLY_RECEIVED': return StockTransferStatus.partiallyReceived;
      case 'RECEIVED': return StockTransferStatus.received;
      case 'CANCELLED': return StockTransferStatus.cancelled;
      default: throw ArgumentError('Unknown stock_transfer_status: $value');
    }
  }
}
