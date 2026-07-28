import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_service.dart';

class SupportService {
  SupportService(this._db);

  final FirebaseFirestore _db;

  Future<String> createTicket({
    required String userId,
    required String userType,
    required String category,
    required String description,
    String? tripId,
  }) async {
    final ref = await _db.collection('support_tickets').add({
      'userId': userId,
      'userType': userType,
      'category': category,
      'description': description,
      if (tripId != null) 'tripId': tripId,
      'status': 'open',
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
    return ref.id;
  }

  Stream<List<Map<String, dynamic>>> watchUserTickets(String userId) {
    return _db
        .collection('support_tickets')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}

final supportServiceProvider = Provider<SupportService>((ref) {
  return SupportService(ref.watch(firestoreProvider));
});
