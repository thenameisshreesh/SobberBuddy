import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/helpers.dart';
import 'firebase_service.dart';

class PaymentService {
  PaymentService(this._db);

  final FirebaseFirestore _db;

  Future<Map<String, dynamic>> createPayment(Map<String, dynamic> tripData) async {
    try {
      final totalFare = tripData['finalTotalFare'] ?? tripData['totalFare'];
      final earnings = AppHelpers.calculateEarnings(totalFare as num);

      final paymentData = <String, dynamic>{
        'tripId': tripData['id'],
        'consumerId': tripData['consumerId'],
        'driverId': tripData['driverId'],
        'totalAmount': totalFare,
        'driverEarnings': earnings.driver,
        'companyEarnings': earnings.company,
        'paymentMethod': tripData['paymentMethod'] ?? 'cash',
        'status': 'pending',
        'fareBreakdown':
            tripData['finalFareBreakdown'] ?? tripData['fareBreakdown'],
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      };

      final paymentRef = await _db.collection('payments').add(paymentData);
      return {'id': paymentRef.id, ...paymentData};
    } catch (error) {
      debugPrint('Error creating payment: $error');
      rethrow;
    }
  }

  Future<void> updatePaymentStatus(
    String paymentId,
    String status, {
    Map<String, dynamic> additionalData = const {},
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': DateTime.now(),
        ...additionalData,
      };

      if (status == 'completed') {
        updateData['completedAt'] = DateTime.now();
      } else if (status == 'failed') {
        updateData['failedAt'] = DateTime.now();
      }

      await _db.collection('payments').doc(paymentId).update(updateData);
    } catch (error) {
      debugPrint('Error updating payment status: $error');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getPaymentByTripId(String tripId) async {
    try {
      final querySnapshot = await _db
          .collection('payments')
          .where('tripId', isEqualTo: tripId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      return {'id': doc.id, ...doc.data()};
    } catch (error) {
      debugPrint('Error getting payment: $error');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory(
    String userId, {
    int limitCount = 10,
  }) async {
    try {
      final querySnapshot = await _db
          .collection('payments')
          .where('consumerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limitCount)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (error) {
      debugPrint('Error getting payment history: $error');
      rethrow;
    }
  }

  Future<void> confirmCashPayment(String paymentId, String confirmedBy) async {
    try {
      await _db.collection('payments').doc(paymentId).update({
        'status': 'completed',
        'confirmedBy': confirmedBy,
        'confirmedAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });
    } catch (error) {
      debugPrint('Error confirming cash payment: $error');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserSpendingStats(String userId) async {
    try {
      final querySnapshot = await _db
          .collection('payments')
          .where('consumerId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      var totalSpent = 0.0;
      var totalTrips = 0;
      final monthlySpending = <String, double>{};

      for (final doc in querySnapshot.docs) {
        final payment = doc.data();
        final amount = (payment['totalAmount'] as num?)?.toDouble() ?? 0;
        totalSpent += amount;
        totalTrips++;

        final createdAt = payment['createdAt'];
        DateTime? date;
        if (createdAt is Timestamp) {
          date = createdAt.toDate();
        } else if (createdAt is DateTime) {
          date = createdAt;
        }

        if (date != null) {
          final monthKey =
              '${date.year}-${date.month.toString().padLeft(2, '0')}';
          monthlySpending[monthKey] =
              (monthlySpending[monthKey] ?? 0) + amount;
        }
      }

      return {
        'totalSpent': totalSpent,
        'totalTrips': totalTrips,
        'averageSpentPerTrip':
            totalTrips > 0 ? (totalSpent / totalTrips).round() : 0,
        'monthlySpending': monthlySpending,
      };
    } catch (error) {
      debugPrint('Error getting spending stats: $error');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCancellationFee(
    String tripId,
    String userId,
    double amount,
  ) async {
    try {
      final cancellationData = <String, dynamic>{
        'tripId': tripId,
        'consumerId': userId,
        'amount': amount,
        'type': 'cancellation_fee',
        'status': 'pending',
        'description': 'Trip cancellation fee',
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      };

      final feeRef = await _db.collection('fees').add(cancellationData);
      return {'id': feeRef.id, ...cancellationData};
    } catch (error) {
      debugPrint('Error creating cancellation fee: $error');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingFees(String userId) async {
    try {
      final querySnapshot = await _db
          .collection('fees')
          .where('consumerId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (error) {
      debugPrint('Error getting pending fees: $error');
      rethrow;
    }
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(ref.watch(firestoreProvider));
});
