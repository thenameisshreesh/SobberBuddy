import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../constants/pricing.dart';

class FareBreakdown {
  const FareBreakdown({
    required this.baseFare,
    required this.distanceCharge,
    required this.timeCharge,
    required this.nightCharge,
    required this.total,
    this.cancellationFees = 0,
  });

  final double baseFare;
  final double distanceCharge;
  final double timeCharge;
  final double nightCharge;
  final double total;
  final double cancellationFees;

  Map<String, dynamic> toMap() => {
        'baseFare': baseFare,
        'distanceCharge': distanceCharge,
        'timeCharge': timeCharge,
        'nightCharge': nightCharge,
        'total': total,
        if (cancellationFees > 0) 'cancellationFees': cancellationFees,
      };

  factory FareBreakdown.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const FareBreakdown(
        baseFare: 0,
        distanceCharge: 0,
        timeCharge: 0,
        nightCharge: 0,
        total: 0,
      );
    }
    return FareBreakdown(
      baseFare: _parseDouble(map['baseFare']),
      distanceCharge: _parseDouble(map['distanceCharge']),
      timeCharge: _parseDouble(map['timeCharge']),
      nightCharge: _parseDouble(map['nightCharge']),
      total: _parseDouble(map['total']),
      cancellationFees: _parseDouble(map['cancellationFees']),
    );
  }
}

double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return 0;
}

class Earnings {
  const Earnings({required this.total, required this.driver, required this.company});
  final int total;
  final int driver;
  final int company;
}

class AppHelpers {
  static bool isNightTime([DateTime? date]) {
    final hour = (date ?? DateTime.now()).hour;
    return hour >= Pricing.nightStartHour || hour < Pricing.nightEndHour;
  }

  static int calculateFare(double distanceKm, {double timeMinutes = 0, bool? isNightTime}) {
    final night = isNightTime ?? AppHelpers.isNightTime();
    return getFareBreakdown(distanceKm, timeMinutes, isNightTime: night).total.round();
  }

  static FareBreakdown getFareBreakdown(
    double distanceKm,
    double timeMinutes, {
    bool? isNightTime,
  }) {
    final night = isNightTime ?? AppHelpers.isNightTime();
    var distanceCharge = 0.0;
    var timeCharge = 0.0;

    if (distanceKm > Pricing.baseDistance) {
      distanceCharge = (distanceKm - Pricing.baseDistance) * Pricing.perKmAfterBase;
    }
    if (timeMinutes > Pricing.baseTime) {
      timeCharge = (timeMinutes - Pricing.baseTime) * Pricing.perMinAfterBase;
    }
    final nightCharge = night ? Pricing.nightCharges : 0.0;
    final total = Pricing.baseFare + distanceCharge + timeCharge + nightCharge;

    return FareBreakdown(
      baseFare: Pricing.baseFare,
      distanceCharge: distanceCharge.roundToDouble(),
      timeCharge: timeCharge.roundToDouble(),
      nightCharge: nightCharge,
      total: total.roundToDouble(),
    );
  }

  static Earnings calculateEarnings(num totalFare) {
    final total = totalFare.round();
    return Earnings(
      total: total,
      driver: (total * Pricing.driverShare).round(),
      company: (total * Pricing.companyShare).round(),
    );
  }

  static double getCancellationFee() => Pricing.cancellationFee;

  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
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
    return DateFormat('d MMM yyyy, hh:mm a').format(dateObj);
  }

  static String formatDuration(double minutes) {
    if (minutes < 60) return '${minutes.round()} min';
    final hours = minutes ~/ 60;
    final remaining = minutes.round() % 60;
    return '${hours}h ${remaining}m';
  }

  static String formatStatus(String? status) {
    if (status == null || status.isEmpty) return '';
    return status
        .split('_')
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  static double getTripAmount(Map<String, dynamic> trip) {
    for (final key in ['finalTotalFare', 'totalFare', 'fare']) {
      final value = trip[key];
      if (value is num) return value.toDouble();
    }
    final breakdown = trip['fareBreakdown'];
    if (breakdown is Map && breakdown['total'] is num) {
      return (breakdown['total'] as num).toDouble();
    }
    return 0;
  }

  static double _deg2rad(double deg) => deg * pi / 180;
}
