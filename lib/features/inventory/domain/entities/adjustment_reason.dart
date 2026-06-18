enum AdjustmentReason {
  damage,
  theft,
  expired,
  recount,
  openingBalance,
  writeOff,
  other,
}

extension AdjustmentReasonX on AdjustmentReason {
  String get dbValue {
    switch (this) {
      case AdjustmentReason.damage: return 'DAMAGE';
      case AdjustmentReason.theft: return 'THEFT';
      case AdjustmentReason.expired: return 'EXPIRED';
      case AdjustmentReason.recount: return 'RECOUNT';
      case AdjustmentReason.openingBalance: return 'OPENING_BALANCE';
      case AdjustmentReason.writeOff: return 'WRITE_OFF';
      case AdjustmentReason.other: return 'OTHER';
    }
  }

  static AdjustmentReason fromDb(String value) {
    switch (value) {
      case 'DAMAGE': return AdjustmentReason.damage;
      case 'THEFT': return AdjustmentReason.theft;
      case 'EXPIRED': return AdjustmentReason.expired;
      case 'RECOUNT': return AdjustmentReason.recount;
      case 'OPENING_BALANCE': return AdjustmentReason.openingBalance;
      case 'WRITE_OFF': return AdjustmentReason.writeOff;
      case 'OTHER': return AdjustmentReason.other;
      default: throw ArgumentError('Unknown adjustment_reason: $value');
    }
  }
}
