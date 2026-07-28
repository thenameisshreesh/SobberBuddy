import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FareBreakdown {
  FareBreakdown({
    required this.baseFare,
    required this.distanceCharge,
    required this.timeCharge,
    required this.nightCharge,
    required this.total,
  });

  final int baseFare;
  final int distanceCharge;
  final int timeCharge;
  final int nightCharge;
  final int total;
}

class EarningsSplit {
  EarningsSplit({
    required this.total,
    required this.driver,
    required this.company,
  });

  final int total;
  final int driver;
  final int company;
}

class Helpers {
  static String formatCurrency(num amount) => '₹${amount.round()}';

  static int calculateFare(
    double distanceKm, {
    double timeMinutes = 0,
    bool isNightTime = false,
  }) {
    const baseFare = 350;
    const baseDistance = 5.0;
    const baseTime = 30.0;
    const perKmRate = 20;
    const perMinRate = 5;
    const nightCharge = 200;

    var totalFare = baseFare;

    if (distanceKm > baseDistance) {
      totalFare += ((distanceKm - baseDistance) * perKmRate).round();
    }
    if (timeMinutes > baseTime) {
      totalFare += ((timeMinutes - baseTime) * perMinRate).round();
    }
    if (isNightTime) {
      totalFare += nightCharge;
    }
    return totalFare;
  }

  static bool isNightTime([DateTime? date]) {
    final hour = (date ?? DateTime.now()).hour;
    return hour >= 22 || hour < 6;
  }

  static EarningsSplit calculateEarnings(num totalFare) {
    final total = totalFare.round();
    return EarningsSplit(
      total: total,
      driver: (total * 0.8).round(),
      company: (total * 0.2).round(),
    );
  }

  static String formatDate(dynamic date) {
    if (date == null) return 'N/A';
    DateTime dateObj;
    if (date is Timestamp) {
      dateObj = date.toDate();
    } else if (date is DateTime) {
      dateObj = date;
    } else {
      return 'N/A';
    }
    return DateFormat('d MMM y, hh:mm a').format(dateObj);
  }

  static String formatDuration(num minutes) {
    if (minutes < 60) {
      return '${minutes.round()} min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = (minutes % 60).round();
    return '${hours}h ${remainingMinutes}m';
  }

  static FareBreakdown getFareBreakdown(
    double distanceKm,
    double timeMinutes, {
    bool isNightTime = false,
  }) {
    const baseFare = 350;
    const baseDistance = 5.0;
    const baseTime = 30.0;
    const perKmRate = 20;
    const perMinRate = 5;
    const nightCharge = 200;

    var distanceCharge = 0;
    var timeCharge = 0;
    var night = 0;

    if (distanceKm > baseDistance) {
      distanceCharge =
          ((distanceKm - baseDistance) * perKmRate).round();
    }
    if (timeMinutes > baseTime) {
      timeCharge = ((timeMinutes - baseTime) * perMinRate).round();
    }
    if (isNightTime) {
      night = nightCharge;
    }

    return FareBreakdown(
      baseFare: baseFare,
      distanceCharge: distanceCharge,
      timeCharge: timeCharge,
      nightCharge: night,
      total: baseFare + distanceCharge + timeCharge + night,
    );
  }

  static num getTripAmount(Map<String, dynamic> trip) {
    final finalTotalFare = trip['finalTotalFare'];
    if (finalTotalFare is num) return finalTotalFare;

    final breakdownTotal = trip['fareBreakdown']?['total'];
    if (breakdownTotal is num) return breakdownTotal;

    final totalFare = trip['totalFare'];
    if (totalFare is num) return totalFare;

    final fare = trip['fare'];
    if (fare is num) return fare;

    return 0;
  }
}
