enum StockMovementType {
  sale,
  purchaseReceipt,
  returnIn,
  returnOut,
  transferOut,
  transferIn,
  adjustment,
  scrap,
  openingBalance,
}

extension StockMovementTypeX on StockMovementType {
  String get dbValue {
    switch (this) {
      case StockMovementType.sale:
        return 'SALE';
      case StockMovementType.purchaseReceipt:
        return 'PURCHASE_RECEIPT';
      case StockMovementType.returnIn:
        return 'RETURN_IN';
      case StockMovementType.returnOut:
        return 'RETURN_OUT';
      case StockMovementType.transferOut:
        return 'TRANSFER_OUT';
      case StockMovementType.transferIn:
        return 'TRANSFER_IN';
      case StockMovementType.adjustment:
        return 'ADJUSTMENT';
      case StockMovementType.scrap:
        return 'SCRAP';
      case StockMovementType.openingBalance:
        return 'OPENING_BALANCE';
    }
  }

  static StockMovementType fromDb(String value) {
    switch (value) {
      case 'SALE':
        return StockMovementType.sale;
      case 'PURCHASE_RECEIPT':
        return StockMovementType.purchaseReceipt;
      case 'RETURN_IN':
        return StockMovementType.returnIn;
      case 'RETURN_OUT':
        return StockMovementType.returnOut;
      case 'TRANSFER_OUT':
        return StockMovementType.transferOut;
      case 'TRANSFER_IN':
        return StockMovementType.transferIn;
      case 'ADJUSTMENT':
        return StockMovementType.adjustment;
      case 'SCRAP':
        return StockMovementType.scrap;
      case 'OPENING_BALANCE':
        return StockMovementType.openingBalance;
      default:
        throw ArgumentError('Unknown stock_movement_type: $value');
    }
  }
}
