import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_service.dart';

class RatingService {
  RatingService(this._db);

  final FirebaseFirestore _db;

  Future<Map<String, dynamic>> rateDriver(
    String tripId,
    String consumerId,
    String driverId,
    int rating, {
    String comment = '',
  }) async {
    try {
      final ratingData = <String, dynamic>{
        'tripId': tripId,
        'ratedBy': consumerId,
        'ratedUser': driverId,
        'userType': 'driver',
        'rating': rating,
        'comment': comment,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      };

      final ratingRef = await _db.collection('ratings').add(ratingData);
      await _updateDriverRating(driverId);

      return {'id': ratingRef.id, ...ratingData};
    } catch (error) {
      debugPrint('Error rating driver: $error');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> rateConsumer(
    String tripId,
    String driverId,
    String consumerId,
    int rating, {
    String comment = '',
  }) async {
    try {
      final ratingData = <String, dynamic>{
        'tripId': tripId,
        'ratedBy': driverId,
        'ratedUser': consumerId,
        'userType': 'consumer',
        'rating': rating,
        'comment': comment,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      };

      final ratingRef = await _db.collection('ratings').add(ratingData);
      await _updateConsumerRating(consumerId);

      return {'id': ratingRef.id, ...ratingData};
    } catch (error) {
      debugPrint('Error rating consumer: $error');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTripRatings(String tripId) async {
    try {
      final querySnapshot = await _db
          .collection('ratings')
          .where('tripId', isEqualTo: tripId)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (error) {
      debugPrint('Error getting trip ratings: $error');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getRatingsGivenByUser(
    String userId, {
    int limitCount = 10,
  }) async {
    try {
      final querySnapshot = await _db
          .collection('ratings')
          .where('ratedBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limitCount)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (error) {
      debugPrint('Error getting ratings given by user: $error');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getRatingsReceivedByUser(
    String userId, {
    int limitCount = 10,
  }) async {
    try {
      final querySnapshot = await _db
          .collection('ratings')
          .where('ratedUser', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limitCount)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (error) {
      debugPrint('Error getting ratings received by user: $error');
      rethrow;
    }
  }

  Future<bool> hasUserRatedTrip(String tripId, String userId) async {
    try {
      final querySnapshot = await _db
          .collection('ratings')
          .where('tripId', isEqualTo: tripId)
          .where('ratedBy', isEqualTo: userId)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (error) {
      debugPrint('Error checking if user rated trip: $error');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserRatingStats(
    String userId, {
    String userType = 'driver',
  }) async {
    try {
      final querySnapshot = await _db
          .collection('ratings')
          .where('ratedUser', isEqualTo: userId)
          .where('userType', isEqualTo: userType)
          .get();

      var totalRatings = 0;
      var sumRatings = 0;
      final ratingDistribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (final doc in querySnapshot.docs) {
        final rating = doc.data()['rating'];
        if (rating is! int) continue;
        totalRatings++;
        sumRatings += rating;
        if (ratingDistribution.containsKey(rating)) {
          ratingDistribution[rating] = ratingDistribution[rating]! + 1;
        }
      }

      final averageRating =
          totalRatings > 0 ? sumRatings / totalRatings : 0.0;

      return {
        'totalRatings': totalRatings,
        'averageRating': (averageRating * 10).round() / 10,
        'ratingDistribution': ratingDistribution,
        'percentageBreakdown': {
          1: totalRatings > 0
              ? ((ratingDistribution[1]! / totalRatings) * 100).round()
              : 0,
          2: totalRatings > 0
              ? ((ratingDistribution[2]! / totalRatings) * 100).round()
              : 0,
          3: totalRatings > 0
              ? ((ratingDistribution[3]! / totalRatings) * 100).round()
              : 0,
          4: totalRatings > 0
              ? ((ratingDistribution[4]! / totalRatings) * 100).round()
              : 0,
          5: totalRatings > 0
              ? ((ratingDistribution[5]! / totalRatings) * 100).round()
              : 0,
        },
      };
    } catch (error) {
      debugPrint('Error getting user rating stats: $error');
      rethrow;
    }
  }

  Future<void> _updateDriverRating(String driverId) async {
    try {
      final stats = await getUserRatingStats(driverId, userType: 'driver');
      final distribution = stats['ratingDistribution'] as Map<int, int>;

      await _db.collection('drivers').doc(driverId).update({
        'rating': stats['averageRating'],
        'totalRatings': stats['totalRatings'],
        'ratingDistribution': distribution.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
        'updatedAt': DateTime.now(),
      });
    } catch (error) {
      debugPrint('Error updating driver rating: $error');
    }
  }

  Future<void> _updateConsumerRating(String consumerId) async {
    try {
      final stats = await getUserRatingStats(consumerId, userType: 'consumer');
      final distribution = stats['ratingDistribution'] as Map<int, int>;

      await _db.collection('users').doc(consumerId).update({
        'rating': stats['averageRating'],
        'totalRatings': stats['totalRatings'],
        'ratingDistribution': distribution.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
        'updatedAt': DateTime.now(),
      });
    } catch (error) {
      debugPrint('Error updating consumer rating: $error');
    }
  }
}

final ratingServiceProvider = Provider<RatingService>((ref) {
  return RatingService(ref.watch(firestoreProvider));
});
