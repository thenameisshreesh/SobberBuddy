import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/helpers.dart';
import 'firebase_service.dart';

class TripService {
  TripService(this._db);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  bool _isDriverEligible(Map<String, dynamic> data) {
    if (data['isAvailable'] != true) return false;
    if (data['currentTrip'] != null) return false;
    final docStatus = data['documentStatus'] as String?;
    if (docStatus != null && docStatus != 'approved') return false;
    return true;
  }

  double? _parseDriverLat(Map<String, dynamic> data) {
    final loc = data['lastKnownLocation'];
    if (loc is Map) {
      return (loc['latitude'] as num?)?.toDouble();
    }
    return null;
  }

  double? _parseDriverLng(Map<String, dynamic> data) {
    final loc = data['lastKnownLocation'];
    if (loc is Map) {
      return (loc['longitude'] as num?)?.toDouble();
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> findAvailableDrivers({
    String? testDriverId,
    double? pickupLat,
    double? pickupLng,
    List<String> excludeDriverIds = const [],
  }) async {
    try {
      final driversRef = _db.collection('drivers');
      Query<Map<String, dynamic>> q;

      if (testDriverId != null) {
        q = driversRef
            .where('isAvailable', isEqualTo: true)
            .where(FieldPath.documentId, isEqualTo: testDriverId);
      } else {
        q = driversRef.where('isAvailable', isEqualTo: true);
      }

      final querySnapshot = await q.get();
      final drivers = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((d) =>
              !excludeDriverIds.contains(d['id']) &&
              _isDriverEligible(d))
          .toList();

      if (pickupLat != null && pickupLng != null) {
        drivers.sort((a, b) {
          final latA = _parseDriverLat(a);
          final lngA = _parseDriverLng(a);
          final latB = _parseDriverLat(b);
          final lngB = _parseDriverLng(b);
          final distA = latA != null && lngA != null
              ? AppHelpers.calculateDistance(pickupLat, pickupLng, latA, lngA)
              : double.infinity;
          final distB = latB != null && lngB != null
              ? AppHelpers.calculateDistance(pickupLat, pickupLng, latB, lngB)
              : double.infinity;
          return distA.compareTo(distB);
        });
      }

      return drivers;
    } catch (error, stack) {
      debugPrint('Error finding drivers: $error');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  Map<String, dynamic> _buildTripPayload(
    Map<String, dynamic> tripData,
    Map<String, dynamic> consumerInfo, {
    required double pendingFees,
    String? driverId,
  }) {
    final distance = (tripData['distance'] as num?)?.toDouble() ?? 0;
    final estimatedDuration =
        (tripData['estimatedDuration'] as num?)?.toDouble() ?? 30;
    final isNightTime = tripData['isNightTime'] as bool?;

    final existingBreakdown = tripData['fareBreakdown'];
    final finalFareBreakdown = existingBreakdown is Map<String, dynamic>
        ? FareBreakdown.fromMap(existingBreakdown)
        : AppHelpers.getFareBreakdown(
            distance,
            estimatedDuration,
            isNightTime: isNightTime,
          );

    final totalWithFees = finalFareBreakdown.total + pendingFees;
    final updatedFareBreakdown = finalFareBreakdown.toMap()
      ..['cancellationFees'] = pendingFees
      ..['total'] = totalWithFees;

    final now = DateTime.now();
    return {
      ...tripData,
      if (driverId != null) 'driverId': driverId,
      'status': tripData['status'] ?? 'pending',
      'bookingType': tripData['bookingType'] ?? 'instant',
      'fareBreakdown': updatedFareBreakdown,
      'totalFare': totalWithFees,
      'cancellationFeesIncluded': pendingFees,
      'consumerInfo': {
        'name': consumerInfo['name'],
        'phone': consumerInfo['phone'],
      },
      'vehiclePreference': tripData['vehiclePreference'] ??
          {
            'vehicleType': 'hatchback',
            'vehicleName': 'Hatchback',
            'transmissionType': 'manual',
            'transmissionName': 'Manual',
            'fareMultiplier': 1.0,
          },
      'declinedDriverIds': tripData['declinedDriverIds'] ?? <String>[],
      'offeredDriverIds': tripData['offeredDriverIds'] ?? <String>[],
      'createdAt': now,
      'updatedAt': now,
      'stages': {
        'created': now,
        'accepted': null,
        'inProgress': null,
        'completed': null,
      },
    };
  }

  Future<String> _createAndLockTrip(
    String driverId,
    Map<String, dynamic> tripData,
    Map<String, dynamic> consumerInfo, {
    double pendingFees = 0,
  }) async {
    final tripRef = _db.collection('trips').doc();
    final driverRef = _db.collection('drivers').doc(driverId);

    await _db.runTransaction((transaction) async {
      final driverSnap = await transaction.get(driverRef);
      if (!driverSnap.exists) {
        throw Exception('Driver not found');
      }
      final driverData = driverSnap.data()!;
      if (!_isDriverEligible(driverData)) {
        throw Exception('Driver unavailable');
      }

      final payload = _buildTripPayload(
        tripData,
        consumerInfo,
        pendingFees: pendingFees,
        driverId: driverId,
      );
      transaction.set(tripRef, payload);
      transaction.update(driverRef, {
        'currentTrip': tripRef.id,
        'isAvailable': false,
        'updatedAt': DateTime.now(),
      });
    });

    final consumerId = tripData['consumerId'] as String?;
    if (pendingFees > 0 && consumerId != null) {
      await _db.collection('users').doc(consumerId).update({
        'feesIncludedInTrip': tripRef.id,
        'feesIncludedAmount': pendingFees,
        'updatedAt': DateTime.now(),
      });
    }

    return tripRef.id;
  }

  Future<String> _createUnassignedTrip(
    Map<String, dynamic> tripData,
    Map<String, dynamic> consumerInfo, {
    double pendingFees = 0,
    String status = 'pending',
  }) async {
    final tripRef = _db.collection('trips').doc();
    final payload = _buildTripPayload(
      tripData,
      consumerInfo,
      pendingFees: pendingFees,
    )..['status'] = status;

    await tripRef.set(payload);

    final consumerId = tripData['consumerId'] as String?;
    if (pendingFees > 0 && consumerId != null) {
      await _db.collection('users').doc(consumerId).update({
        'feesIncludedInTrip': tripRef.id,
        'feesIncludedAmount': pendingFees,
        'updatedAt': DateTime.now(),
      });
    }
    return tripRef.id;
  }

  Future<({String tripId, Map<String, dynamic>? driver})?> _assignViaCloudFunction({
    required String tripId,
    required double pickupLat,
    required double pickupLng,
    List<String> excludeDriverIds = const [],
    String callableName = 'assignNearestDriver',
  }) async {
    try {
      final payload = callableName == 'reassignOnDecline'
          ? {'tripId': tripId}
          : {
              'tripId': tripId,
              'pickupLat': pickupLat,
              'pickupLng': pickupLng,
              'excludeDriverIds': excludeDriverIds,
            };
      final result = await _functions
          .httpsCallable(callableName)
          .call(payload);
      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['success'] != true) {
        debugPrint('Cloud Function $callableName returned: $data');
        return null;
      }
      if (data['mode'] == 'broadcast') {
        return (tripId: tripId, driver: null);
      }
      final driverId = data['driverId'] as String?;
      final driverRaw = data['driver'];
      if (driverId == null) return null;
      if (driverRaw is Map) {
        return (
          tripId: tripId,
          driver: {'id': driverId, ...Map<String, dynamic>.from(driverRaw)},
        );
      }
      final driverDoc = await getDriverById(driverId);
      if (driverDoc == null) return null;
      return (tripId: tripId, driver: driverDoc);
    } catch (error) {
      debugPrint('Cloud Function $callableName failed: $error');
      return null;
    }
  }

  Future<bool> _broadcastToNearestDrivers({
    required String tripId,
    required double pickupLat,
    required double pickupLng,
    List<String> excludeDriverIds = const [],
    String? testDriverId,
  }) async {
    final drivers = await findAvailableDrivers(
      testDriverId: testDriverId,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      excludeDriverIds: excludeDriverIds,
    );
    if (drivers.isEmpty) return false;

    final offeredIds = drivers.take(5).map((d) => d['id'] as String).toList();
    await _db.collection('trips').doc(tripId).update({
      'driverId': null,
      'status': 'pending',
      'offeredDriverIds': offeredIds,
      'updatedAt': DateTime.now(),
    });
    return true;
  }

  Future<({String tripId, Map<String, dynamic> driver})?> _clientAssignExistingTrip({
    required String tripId,
    required Map<String, dynamic> tripData,
    required Map<String, dynamic> consumerInfo,
    required double pickupLat,
    required double pickupLng,
    double pendingFees = 0,
    List<String> excludeDriverIds = const [],
    String? testDriverId,
  }) async {
    final drivers = await findAvailableDrivers(
      testDriverId: testDriverId,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      excludeDriverIds: excludeDriverIds,
    );
    if (drivers.isEmpty) return null;

    for (final driver in drivers.take(5)) {
      try {
        final driverId = driver['id'] as String;
        final driverRef = _db.collection('drivers').doc(driverId);
        final tripRef = _db.collection('trips').doc(tripId);
        await _db.runTransaction((transaction) async {
          final driverSnap = await transaction.get(driverRef);
          if (!driverSnap.exists || !_isDriverEligible(driverSnap.data()!)) {
            throw Exception('Driver unavailable');
          }
          transaction.update(tripRef, {
            'driverId': driverId,
            'status': 'pending',
            'updatedAt': DateTime.now(),
          });
          transaction.update(driverRef, {
            'currentTrip': tripId,
            'isAvailable': false,
            'updatedAt': DateTime.now(),
          });
        });
        return (tripId: tripId, driver: driver);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Creates a scheduled trip without immediate driver assignment.
  Future<String> createScheduledTrip({
    required Map<String, dynamic> tripData,
    required Map<String, dynamic> consumerInfo,
    double pendingFees = 0,
  }) {
    return _createUnassignedTrip(
      tripData,
      consumerInfo,
      pendingFees: pendingFees,
      status: 'scheduled',
    );
  }

  /// Creates trip and broadcasts to nearest available drivers.
  Future<({String tripId, Map<String, dynamic>? driver})?> assignNearestDriver({
    required Map<String, dynamic> tripData,
    required Map<String, dynamic> consumerInfo,
    required double pickupLat,
    required double pickupLng,
    double pendingFees = 0,
    List<String> excludeDriverIds = const [],
    String? testDriverId,
  }) async {
    final tripId = await _createUnassignedTrip(
      tripData,
      consumerInfo,
      pendingFees: pendingFees,
    );

    final cfResult = await _assignViaCloudFunction(
      tripId: tripId,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      excludeDriverIds: excludeDriverIds,
    );
    if (cfResult != null) return cfResult;

    final broadcastOk = await _broadcastToNearestDrivers(
      tripId: tripId,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      excludeDriverIds: excludeDriverIds,
      testDriverId: testDriverId,
    );
    if (broadcastOk) return (tripId: tripId, driver: null);

    await _db.collection('trips').doc(tripId).update({
      'status': 'no_drivers',
      'updatedAt': DateTime.now(),
    });
    return null;
  }

  Future<String> createTripWithDriver(
    Map<String, dynamic> tripData,
    String driverId,
    Map<String, dynamic> consumerInfo, {
    double pendingFees = 0,
  }) async {
    return _createAndLockTrip(
      driverId,
      tripData,
      consumerInfo,
      pendingFees: pendingFees,
    );
  }

  Future<void> cancelPendingTrip(String tripId, String consumerId) async {
    final tripRef = _db.collection('trips').doc(tripId);
    await _db.runTransaction((transaction) async {
      final tripSnap = await transaction.get(tripRef);
      if (!tripSnap.exists) throw Exception('Trip not found');
      final trip = tripSnap.data()!;
      if (trip['consumerId'] != consumerId) {
        throw Exception('Unauthorized');
      }
      final status = trip['status'] as String? ?? '';
      if (status != 'pending') {
        throw Exception('Trip cannot be cancelled in current state');
      }

      transaction.update(tripRef, {
        'status': 'cancelled',
        'cancelledBy': 'consumer',
        'cancelledAt': DateTime.now(),
        'cancellationReason': 'Cancelled while finding driver',
        'updatedAt': DateTime.now(),
      });

      final driverId = trip['driverId'] as String?;
      if (driverId != null) {
        transaction.update(_db.collection('drivers').doc(driverId), {
          'isAvailable': true,
          'currentTrip': null,
          'updatedAt': DateTime.now(),
        });
      }
    });
  }

  Future<({String tripId, Map<String, dynamic>? driver})?> reassignTrip(
    String tripId,
  ) async {
    final tripDoc = await _db.collection('trips').doc(tripId).get();
    if (!tripDoc.exists) return null;
    final trip = tripDoc.data()!;
    final pickupCoords = trip['pickupCoords'] as Map<String, dynamic>?;
    final pickupLat = (pickupCoords?['latitude'] as num?)?.toDouble();
    final pickupLng = (pickupCoords?['longitude'] as num?)?.toDouble();
    if (pickupLat == null || pickupLng == null) return null;

    final cfResult = await _assignViaCloudFunction(
      tripId: tripId,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      callableName: 'reassignOnDecline',
    );
    if (cfResult != null) return cfResult;

    final declinedDriverId = trip['driverId'] as String?;
    final declinedDriverIds = List<String>.from(
      (trip['declinedDriverIds'] as List?)?.map((e) => e.toString()) ?? [],
    );
    if (declinedDriverId != null && !declinedDriverIds.contains(declinedDriverId)) {
      declinedDriverIds.add(declinedDriverId);
    }

    if (declinedDriverId != null) {
      await _db.collection('drivers').doc(declinedDriverId).update({
        'isAvailable': true,
        'currentTrip': null,
        'updatedAt': DateTime.now(),
      });
    }

    await _db.collection('trips').doc(tripId).update({
      'status': 'pending',
      'driverId': null,
      'declinedDriverIds': declinedDriverIds,
      'offeredDriverIds': [],
      'updatedAt': DateTime.now(),
    });

    final broadcastOk = await _broadcastToNearestDrivers(
      tripId: tripId,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      excludeDriverIds: declinedDriverIds,
    );
    if (broadcastOk) return (tripId: tripId, driver: null);

    await _db.collection('trips').doc(tripId).update({
      'status': 'no_drivers',
      'updatedAt': DateTime.now(),
    });
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllTrips(
    String userId, {
    int limitCount = 20,
  }) async {
    try {
      final querySnapshot = await _db
          .collection('trips')
          .where('consumerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limitCount)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (error) {
      debugPrint('Error getting all trips: $error');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getActiveTrips(String userId) async {
    try {
      final querySnapshot = await _db
          .collection('trips')
          .where('consumerId', isEqualTo: userId)
          .where('status', whereIn: ['accepted', 'in_progress'])
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (error) {
      debugPrint('Error getting active trips: $error');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTripHistory(
    String userId, {
    int limitCount = 10,
  }) async {
    try {
      final querySnapshot = await _db
          .collection('trips')
          .where('consumerId', isEqualTo: userId)
          .where('status', whereIn: ['completed', 'cancelled'])
          .orderBy('createdAt', descending: true)
          .limit(limitCount)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (error) {
      debugPrint('Error getting trip history: $error');
      rethrow;
    }
  }

  Future<void> updateTripStatus(
    String tripId,
    String status, {
    Map<String, dynamic> additionalData = const {},
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updatedAt': DateTime.now(),
        ...additionalData,
      };

      if (status == 'in_progress') {
        updateData['stages.inProgress'] = DateTime.now();
      } else if (status == 'completed') {
        updateData['stages.completed'] = DateTime.now();
      }

      await _db.collection('trips').doc(tripId).update(updateData);
    } catch (error) {
      debugPrint('Error updating trip status: $error');
      rethrow;
    }
  }

  Future<double> cancelTrip(
    String tripId,
    String cancelledBy, {
    String reason = '',
  }) async {
    try {
      final cancellationFee = AppHelpers.getCancellationFee();

      await _db.collection('trips').doc(tripId).update({
        'status': 'cancelled',
        'cancelledBy': cancelledBy,
        'cancelledAt': DateTime.now(),
        'cancellationReason': reason,
        'cancellationFee': cancellationFee,
        'updatedAt': DateTime.now(),
      });

      return cancellationFee;
    } catch (error) {
      debugPrint('Error cancelling trip: $error');
      rethrow;
    }
  }

  Future<FareBreakdown> completeTrip(
    String tripId, {
    double? actualDistance,
    double? actualDuration,
  }) async {
    try {
      final tripDoc = await _db.collection('trips').doc(tripId).get();
      if (!tripDoc.exists) {
        throw Exception('Trip not found');
      }

      final tripData = tripDoc.data()!;
      final distance =
          actualDistance ?? (tripData['distance'] as num?)?.toDouble() ?? 0;
      final duration = actualDuration ??
          (tripData['estimatedDuration'] as num?)?.toDouble() ??
          30;
      final isNightTime = tripData['isNightTime'] as bool?;

      final finalFareBreakdown = AppHelpers.getFareBreakdown(
        distance,
        duration,
        isNightTime: isNightTime,
      );

      await _db.collection('trips').doc(tripId).update({
        'status': 'completed',
        'completedAt': DateTime.now(),
        'actualDistance': distance,
        'actualDuration': duration,
        'finalFareBreakdown': finalFareBreakdown.toMap(),
        'finalTotalFare': finalFareBreakdown.total,
        'updatedAt': DateTime.now(),
        'stages.completed': DateTime.now(),
      });

      final consumerId = tripData['consumerId'] as String?;
      if (consumerId != null) {
        await clearPendingFeesOnCompletion(consumerId, tripId);
      }

      return finalFareBreakdown;
    } catch (error) {
      debugPrint('Error completing trip: $error');
      rethrow;
    }
  }

  Stream<Map<String, dynamic>> listenToTripUpdates(String tripId) {
    return _db.collection('trips').doc(tripId).snapshots().where((doc) => doc.exists).map(
          (doc) => {'id': doc.id, ...doc.data()!},
        );
  }

  Future<Map<String, dynamic>> getTripById(String tripId) async {
    try {
      final tripDoc = await _db.collection('trips').doc(tripId).get();
      if (!tripDoc.exists) {
        throw Exception('Trip not found');
      }
      return {'id': tripDoc.id, ...tripDoc.data()!};
    } catch (error) {
      debugPrint('Error getting trip: $error');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTripStatistics(String userId) async {
    try {
      final querySnapshot = await _db
          .collection('trips')
          .where('consumerId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      var totalTrips = 0;
      var totalSpent = 0.0;

      for (final doc in querySnapshot.docs) {
        totalTrips++;
        totalSpent += AppHelpers.getTripAmount(doc.data());
      }

      Object userRating = '-';
      try {
        final ratingsSnapshot = await _db
            .collection('ratings')
            .where('ratedUser', isEqualTo: userId)
            .where('userType', isEqualTo: 'consumer')
            .get();

        if (ratingsSnapshot.docs.isNotEmpty) {
          var totalRating = 0.0;
          var ratingCount = 0;

          for (final doc in ratingsSnapshot.docs) {
            final rating = doc.data()['rating'];
            if (rating is num) {
              totalRating += rating.toDouble();
              ratingCount++;
            }
          }

          if (ratingCount > 0) {
            userRating = (totalRating / ratingCount * 10).round() / 10;
          }
        }
      } catch (ratingError) {
        debugPrint('Error getting user rating, using default: $ratingError');
      }

      return {
        'totalTrips': totalTrips,
        'totalSpent': totalSpent,
        'userRating': userRating,
      };
    } catch (error) {
      debugPrint('Error getting trip statistics: $error');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> canUserBookTrip(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {'canBook': false, 'reason': 'User not found'};
      }

      final userData = userDoc.data()!;

      if (userData['isBlocked'] == true) {
        return {
          'canBook': false,
          'reason': 'blocked',
          'message':
              'Your account has been temporarily blocked due to multiple trip cancellations. Please contact support.',
          'cancellationCount': userData['cancellationCount'] ?? 0,
          'pendingFees': userData['pendingCancellationFees'] ?? 0,
        };
      }

      return {
        'canBook': true,
        'pendingFees': userData['pendingCancellationFees'] ?? 0,
      };
    } catch (error) {
      debugPrint('Error checking user booking eligibility: $error');
      return {'canBook': false, 'reason': 'Error checking eligibility'};
    }
  }

  Future<Map<String, dynamic>> cancelTripByConsumer(
    String tripId,
    String userId, {
    String reason = '',
  }) async {
    try {
      final tripDoc = await _db.collection('trips').doc(tripId).get();
      if (!tripDoc.exists) {
        throw Exception('Trip not found');
      }

      final tripData = tripDoc.data()!;
      final tripStatus = tripData['status'] as String? ?? '';
      final shouldChargeFee =
          tripStatus == 'accepted' || tripStatus == 'in_progress';
      final cancellationFee =
          shouldChargeFee ? AppHelpers.getCancellationFee() : 0.0;

      await _db.collection('trips').doc(tripId).update({
        'status': 'cancelled',
        'cancelledBy': 'consumer',
        'cancelledAt': DateTime.now(),
        'cancellationReason': reason,
        'cancellationFee': cancellationFee,
        'feeApplied': shouldChargeFee,
        'tripStatusAtCancellation': tripStatus,
        'updatedAt': DateTime.now(),
      });

      final userDoc = await _db.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};

      var userUpdate = <String, dynamic>{
        'updatedAt': DateTime.now(),
      };

      if (shouldChargeFee) {
        final newCancellationCount =
            ((userData['cancellationCount'] as num?)?.toInt() ?? 0) + 1;
        final existingPendingFees =
            (userData['pendingCancellationFees'] as num?)?.toDouble() ?? 0;
        final newPendingFees = existingPendingFees + cancellationFee;

        userUpdate = {
          ...userUpdate,
          'cancellationCount': newCancellationCount,
          'lastCancellationAt': DateTime.now(),
          'pendingCancellationFees': newPendingFees,
        };

        if (newCancellationCount >= 3) {
          userUpdate['isBlocked'] = true;
          userUpdate['blockedAt'] = DateTime.now();
          userUpdate['blockedReason'] =
              'Multiple trip cancellations after driver acceptance (3 or more)';
        }

        await _db.collection('users').doc(userId).update(userUpdate);

        return {
          'cancellationFee': cancellationFee,
          'success': true,
          'isBlocked': newCancellationCount >= 3,
          'cancellationCount': newCancellationCount,
          'totalPendingFees': newPendingFees,
          'feeApplied': true,
          'reason': 'Driver had already accepted the trip',
        };
      }

      await _db.collection('users').doc(userId).update(userUpdate);

      return {
        'cancellationFee': 0,
        'success': true,
        'isBlocked': false,
        'cancellationCount': userData['cancellationCount'] ?? 0,
        'totalPendingFees': userData['pendingCancellationFees'] ?? 0,
        'feeApplied': false,
        'reason': 'No fee applied - driver had not accepted the trip yet',
      };
    } catch (error) {
      debugPrint('Error cancelling trip: $error');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getDriverById(String driverId) async {
    final doc = await _db.collection('drivers').doc(driverId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  Future<void> clearPendingFeesOnCompletion(String userId, String tripId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};

      if (userData['feesIncludedInTrip'] == tripId) {
        await _db.collection('users').doc(userId).update({
          'pendingCancellationFees': 0,
          'feesIncludedInTrip': null,
          'feesIncludedAmount': 0,
          'feesClearedAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        });
      }
    } catch (error) {
      debugPrint('Error clearing pending fees: $error');
    }
  }
}

final tripServiceProvider = Provider<TripService>((ref) {
  return TripService(ref.watch(firestoreProvider));
});
