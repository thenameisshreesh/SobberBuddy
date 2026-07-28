import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_service.dart';

class SosService {
  SosService({FirebaseFirestore? db}) : _db = db ?? FirebaseService.db;

  final FirebaseFirestore _db;

  Future<void> triggerSos({
    required String tripId,
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    await _db.collection('sos_events').add({
      'tripId': tripId,
      'userId': userId,
      'userType': 'driver',
      'latitude': latitude,
      'longitude': longitude,
      'status': 'active',
      'createdAt': DateTime.now(),
    });
    await _db.collection('trips').doc(tripId).update({
      'sosTriggered': true,
      'updatedAt': DateTime.now(),
    });
  }
}
