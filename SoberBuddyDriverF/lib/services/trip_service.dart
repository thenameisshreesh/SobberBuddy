import 'dart:async';

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/helpers.dart';
import '../models/trip_model.dart';
import 'firebase_service.dart';

class TripService {
  TripService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseService.db;

  final FirebaseFirestore _db;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? listenForAssignedTrips(
    String driverId,
    void Function(QuerySnapshot<Map<String, dynamic>>) callback,
  ) {
    return _db
        .collection('trips')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(callback);
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? listenForOfferedTrips(
    String driverId,
    void Function(QuerySnapshot<Map<String, dynamic>>) callback,
  ) {
    return _db
        .collection('trips')
        .where('offeredDriverIds', arrayContains: driverId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(callback);
  }

  /// Listens for broadcast offers and direct admin assigns (pending only).
  MergedTripListener listenForDriverTrips(
    String driverId,
    void Function(TripModel? trip) callback,
  ) {
    QuerySnapshot<Map<String, dynamic>>? offeredSnap;
    QuerySnapshot<Map<String, dynamic>>? assignedSnap;

    void emit() {
      TripModel? trip;
      for (final snap in [assignedSnap, offeredSnap]) {
        if (snap == null) continue;
        for (final doc in snap.docs) {
          final candidate = TripModel.fromDoc(doc);
          if (candidate.status == 'pending') {
            trip = candidate;
            break;
          }
        }
        if (trip != null) break;
      }
      callback(trip);
    }

    final offeredSub = listenForOfferedTrips(driverId, (snap) {
      offeredSnap = snap;
      emit();
    });
    final assignedSub = listenForAssignedTrips(driverId, (snap) {
      assignedSnap = snap;
      emit();
    });

    return MergedTripListener([offeredSub, assignedSub]);
  }

  Future<void> updateDriverAvailability(
    String driverId,
    bool isAvailable, {
    Map<String, double>? location,
  }) async {
    final updateData = <String, dynamic>{
      'isAvailable': isAvailable,
      'updatedAt': DateTime.now(),
    };

    if (location != null) {
      updateData['lastKnownLocation'] = location;
    }
    if (!isAvailable) {
      updateData['currentTrip'] = null;
    }

    await _db.collection('drivers').doc(driverId).update(updateData);
  }

  Future<void> updateTripStatus(
    String tripId,
    String status, {
    Map<String, dynamic> additionalData = const {},
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
      'updatedAt': DateTime.now(),
      ...additionalData,
    };

    switch (status) {
      case 'accepted':
        updateData['stages.accepted'] = DateTime.now();
        updateData['acceptedAt'] = DateTime.now();
      case 'declined':
        updateData['stages.declined'] = DateTime.now();
      case 'in_progress':
        updateData['stages.inProgress'] = DateTime.now();
        updateData['startedAt'] = DateTime.now();
      case 'completed':
        updateData['stages.completed'] = DateTime.now();
        updateData['completedAt'] = DateTime.now();
    }

    await _db.collection('trips').doc(tripId).update(updateData);
  }

  Future<Map<String, dynamic>> completeTrip(
    String tripId,
    double? actualDistance,
    double? actualDuration,
  ) async {
    final tripDoc = await _db.collection('trips').doc(tripId).get();
    if (!tripDoc.exists) {
      throw Exception('Trip not found');
    }

    final tripData = tripDoc.data()!;
    final distance = actualDistance ?? (tripData['distance'] as num?)?.toDouble() ?? 0;
    final duration =
        actualDuration ?? (tripData['estimatedDuration'] as num?)?.toDouble() ?? 0;
    final isNight = tripData['isNightTime'] as bool? ?? false;

    final breakdown = Helpers.getFareBreakdown(distance, duration, isNightTime: isNight);
    final earnings = Helpers.calculateEarnings(breakdown.total);

    final completionData = {
      'status': 'completed',
      'completedAt': DateTime.now(),
      'actualDistance': distance,
      'actualDuration': duration,
      'finalFareBreakdown': {
        'baseFare': breakdown.baseFare,
        'distanceCharge': breakdown.distanceCharge,
        'timeCharge': breakdown.timeCharge,
        'nightCharge': breakdown.nightCharge,
        'total': breakdown.total,
      },
      'finalTotalFare': breakdown.total,
      'driverEarnings': earnings.driver,
      'companyEarnings': earnings.company,
      'updatedAt': DateTime.now(),
      'stages.completed': DateTime.now(),
    };

    await _db.collection('trips').doc(tripId).update(completionData);

    return {
      'fareBreakdown': completionData['finalFareBreakdown'],
      'earnings': {
        'driver': earnings.driver,
        'company': earnings.company,
        'total': earnings.total,
      },
    };
  }

  Future<void> startTrip(String tripId) async {
    await updateTripStatus(tripId, 'in_progress');
  }

  Future<List<TripModel>> getAllDriverTrips(
    String driverId, {
    int limit = 50,
  }) async {
    return getDriverTripHistory(driverId, limit: limit);
  }

  Future<List<TripModel>> getDriverTripHistory(
    String driverId, {
    int limit = 20,
  }) async {
    final snapshot = await _db
        .collection('trips')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map(TripModel.fromDoc).toList();
  }

  Future<Map<String, dynamic>> getDriverEarningsStats(String driverId) async {
    final snapshot = await _db
        .collection('trips')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed')
        .get();

    var totalTrips = 0;
    var totalEarnings = 0;
    var totalDistance = 0.0;
    var totalDuration = 0.0;

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final weekAgo = todayStart.subtract(const Duration(days: 7));
    final monthAgo = DateTime(today.year, today.month - 1, today.day);

    var todayEarnings = 0;
    var weekEarnings = 0;
    var monthEarnings = 0;
    var todayTrips = 0;
    var weekTrips = 0;
    var monthTrips = 0;

    for (final doc in snapshot.docs) {
      final trip = doc.data();
      final completedAt = (trip['completedAt'] as Timestamp?)?.toDate();
      if (completedAt == null) continue;

      final earnings = (trip['driverEarnings'] as num?)?.round() ??
          Helpers.calculateEarnings(Helpers.getTripAmount(trip)).driver;

      totalTrips++;
      totalEarnings += earnings;
      totalDistance += (trip['actualDistance'] ?? trip['distance'] ?? 0) as num;
      totalDuration += (trip['actualDuration'] ?? trip['estimatedDuration'] ?? 0) as num;

      if (completedAt.isAfter(todayStart) || completedAt.isAtSameMomentAs(todayStart)) {
        todayEarnings += earnings;
        todayTrips++;
      }
      if (completedAt.isAfter(weekAgo)) {
        weekEarnings += earnings;
        weekTrips++;
      }
      if (completedAt.isAfter(monthAgo)) {
        monthEarnings += earnings;
        monthTrips++;
      }
    }

    return {
      'total': {
        'trips': totalTrips,
        'earnings': totalEarnings,
        'distance': (totalDistance * 10).round() / 10,
        'duration': totalDuration.round(),
        'averageEarnings':
            totalTrips > 0 ? (totalEarnings / totalTrips).round() : 0,
      },
      'today': {'trips': todayTrips, 'earnings': todayEarnings},
      'week': {'trips': weekTrips, 'earnings': weekEarnings},
      'month': {'trips': monthTrips, 'earnings': monthEarnings},
    };
  }

  Future<List<Map<String, dynamic>>> getDriverPayouts(String driverId) async {
    final snapshot = await _db
        .collection('payouts')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  Future<void> acceptTrip(String tripId, String driverId) async {
    final tripRef = _db.collection('trips').doc(tripId);
    final driverRef = _db.collection('drivers').doc(driverId);

    await _db.runTransaction((transaction) async {
      final tripSnap = await transaction.get(tripRef);
      final driverSnap = await transaction.get(driverRef);
      if (!tripSnap.exists || !driverSnap.exists) {
        throw Exception('Trip or driver not found');
      }

      final trip = tripSnap.data()!;
      final status = trip['status'] as String? ?? '';
      if (status != 'pending') {
        throw Exception('Trip is no longer available');
      }

      final existingDriver = trip['driverId'] as String?;
      if (existingDriver != null && existingDriver != driverId) {
        throw Exception('Trip already accepted by another driver');
      }

      final offered = List<String>.from(
        (trip['offeredDriverIds'] as List?)?.map((e) => e.toString()) ?? [],
      );
      final isOffered = offered.contains(driverId);
      final isDirectAssign = existingDriver == driverId;
      if (!isOffered && !isDirectAssign && existingDriver != null) {
        throw Exception('You are not offered this trip');
      }
      if (existingDriver == null && !isOffered) {
        throw Exception('You are not offered this trip');
      }

      final driver = driverSnap.data()!;
      if (driver['isAvailable'] != true || driver['currentTrip'] != null) {
        throw Exception('You are not available');
      }

      transaction.update(tripRef, {
        'driverId': driverId,
        'status': 'accepted',
        'offeredDriverIds': <String>[],
        'acceptedAt': DateTime.now(),
        'updatedAt': DateTime.now(),
        'stages.accepted': DateTime.now(),
      });
      transaction.update(driverRef, {
        'isAvailable': false,
        'currentTrip': tripId,
        'updatedAt': DateTime.now(),
      });
    });
  }

  Future<void> declineTrip(String tripId, String driverId, {String reason = 'Driver declined'}) async {
    final tripRef = _db.collection('trips').doc(tripId);

    await _db.runTransaction((transaction) async {
      final tripSnap = await transaction.get(tripRef);
      if (!tripSnap.exists) throw Exception('Trip not found');
      final trip = tripSnap.data()!;
      if ((trip['status'] as String? ?? '') != 'pending') return;
      if (trip['driverId'] != null) return;

      final offered = List<String>.from(
        (trip['offeredDriverIds'] as List?)?.map((e) => e.toString()) ?? [],
      );
      if (!offered.contains(driverId)) return;

      offered.remove(driverId);
      final declined = List<String>.from(
        (trip['declinedDriverIds'] as List?)?.map((e) => e.toString()) ?? [],
      );
      if (!declined.contains(driverId)) declined.add(driverId);

      final update = <String, dynamic>{
        'offeredDriverIds': offered,
        'declinedDriverIds': declined,
        'updatedAt': DateTime.now(),
      };
      if (offered.isEmpty) {
        update['status'] = 'no_drivers';
      }
      transaction.update(tripRef, update);
    });
  }

  Future<void> updateDriverLocation(
    String driverId,
    double latitude,
    double longitude, {
    String? activeTripId,
  }) async {
    final updateData = <String, dynamic>{
      'lastKnownLocation': {'latitude': latitude, 'longitude': longitude},
      'locationUpdatedAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    };
    await _db.collection('drivers').doc(driverId).update(updateData);

    if (activeTripId != null) {
      final tripUpdate = <String, dynamic>{
        'driverLocation': {'latitude': latitude, 'longitude': longitude},
        'updatedAt': DateTime.now(),
      };

      final tripDoc = await _db.collection('trips').doc(activeTripId).get();
      if (tripDoc.exists) {
        final trip = tripDoc.data()!;
        final status = trip['status'] as String?;
        if (status == 'accepted') {
          final pickup = trip['pickupCoords'] as Map<String, dynamic>?;
          final pickupLat = (pickup?['latitude'] as num?)?.toDouble();
          final pickupLng = (pickup?['longitude'] as num?)?.toDouble();
          if (pickupLat != null && pickupLng != null) {
            final distanceKm = _haversineKm(latitude, longitude, pickupLat, pickupLng);
            const avgSpeedKmh = 30.0;
            final etaMinutes = math.max(1, (distanceKm / avgSpeedKmh * 60).ceil());
            tripUpdate['etaMinutes'] = etaMinutes;
          }
        }
      }

      await _db.collection('trips').doc(activeTripId).update(tripUpdate);
    }
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);

  Future<TripModel?> getActiveTrip(String driverId) async {
    final snapshot = await _db
        .collection('trips')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['accepted', 'in_progress'])
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return TripModel.fromDoc(snapshot.docs.first);
  }

  Future<void> clearPendingFeesOnCompletion(
    String userId,
    String tripId,
  ) async {
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
    } catch (_) {}
  }

  Future<TripModel?> getTripById(String tripId) async {
    final doc = await _db.collection('trips').doc(tripId).get();
    if (!doc.exists) return null;
    return TripModel.fromDoc(doc);
  }
}

class MergedTripListener {
  MergedTripListener(this._subs);

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?> _subs;

  void cancel() {
    for (final sub in _subs) {
      sub?.cancel();
    }
  }
}
