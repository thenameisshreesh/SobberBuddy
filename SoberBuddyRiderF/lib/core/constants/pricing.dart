class Pricing {
  static const baseFare = 350.0;
  static const baseDistance = 5.0;
  static const baseTime = 30.0;
  static const perKmAfterBase = 20.0;
  static const perMinAfterBase = 5.0;
  static const nightCharges = 200.0;
  static const cancellationFee = 100.0;
  static const driverShare = 0.8;
  static const companyShare = 0.2;
  static const nightStartHour = 22;
  static const nightEndHour = 6;
}

String formatCurrency(num? amount) {
  if (amount == null) return '-';
  return '₹${amount.round()}';
}
