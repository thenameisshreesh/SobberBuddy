import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SosService {
  SosService({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Future<void> triggerSos({
    required String tripId,
    required String userId,
    required String userType,
    required double latitude,
    required double longitude,
    List<Map<String, String>> emergencyContacts = const [],
  }) async {
    await _db.collection('sos_events').add({
      'tripId': tripId,
      'userId': userId,
      'userType': userType,
      'latitude': latitude,
      'longitude': longitude,
      'emergencyContacts': emergencyContacts,
      'status': 'active',
      'createdAt': DateTime.now(),
    });

    await _db.collection('trips').doc(tripId).update({
      'sosTriggered': true,
      'updatedAt': DateTime.now(),
    });

    try {
      final callable = _functions.httpsCallable('onSosTriggered');
      await callable.call({
        'tripId': tripId,
        'userId': userId,
        'userType': userType,
        'latitude': latitude,
        'longitude': longitude,
        'emergencyContacts': emergencyContacts,
      });
    } catch (_) {}
  }
}
