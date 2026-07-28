import 'package:flutter_test/flutter_test.dart';
import 'package:sober_buddy_rider/core/constants/pricing.dart';
import 'package:sober_buddy_rider/core/utils/helpers.dart';

void main() {
  group('Fare calculation', () {
    test('base fare within 5km day time', () {
      final breakdown = AppHelpers.getFareBreakdown(3, 20, isNightTime: false);
      expect(breakdown.total, Pricing.baseFare);
    });

    test('extra distance charges', () {
      final breakdown = AppHelpers.getFareBreakdown(10, 20, isNightTime: false);
      expect(breakdown.distanceCharge, 100); // 5km * 20
      expect(breakdown.total, 450);
    });

    test('night charges added', () {
      final breakdown = AppHelpers.getFareBreakdown(3, 20, isNightTime: true);
      expect(breakdown.nightCharge, Pricing.nightCharges);
      expect(breakdown.total, Pricing.baseFare + Pricing.nightCharges);
    });

    test('cancellation fee constant', () {
      expect(AppHelpers.getCancellationFee(), 100);
    });

    test('driver earnings split', () {
      final earnings = AppHelpers.calculateEarnings(500);
      expect(earnings.driver, 400);
      expect(earnings.company, 100);
    });
  });
}
