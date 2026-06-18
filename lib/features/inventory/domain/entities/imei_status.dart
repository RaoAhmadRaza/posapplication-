enum ImeiStatus {
  available,
  sold,
  returned,
  transferred,
  scrapped,
  reserved,
  inTransit,
}

extension ImeiStatusX on ImeiStatus {
  String get dbValue {
    switch (this) {
      case ImeiStatus.available: return 'AVAILABLE';
      case ImeiStatus.sold: return 'SOLD';
      case ImeiStatus.returned: return 'RETURNED';
      case ImeiStatus.transferred: return 'TRANSFERRED';
      case ImeiStatus.scrapped: return 'SCRAPPED';
      case ImeiStatus.reserved: return 'RESERVED';
      case ImeiStatus.inTransit: return 'IN_TRANSIT';
    }
  }

  static ImeiStatus fromDb(String value) {
    switch (value) {
      case 'AVAILABLE': return ImeiStatus.available;
      case 'SOLD': return ImeiStatus.sold;
      case 'RETURNED': return ImeiStatus.returned;
      case 'TRANSFERRED': return ImeiStatus.transferred;
      case 'SCRAPPED': return ImeiStatus.scrapped;
      case 'RESERVED': return ImeiStatus.reserved;
      case 'IN_TRANSIT': return ImeiStatus.inTransit;
      default: throw ArgumentError('Unknown imei_status: $value');
    }
  }
}
