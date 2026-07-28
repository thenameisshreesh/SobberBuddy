import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';
import 'phone_auth_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

class FirebaseService {
  FirebaseService(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await PhoneAuthService.configureForPlatform();
    await ensureFirestoreOnline();
  }

  static Future<void> ensureFirestoreOnline() async {
    try {
      await FirebaseFirestore.instance.enableNetwork();
    } catch (_) {}
  }

  FirebaseAuth get auth => _auth;
  FirebaseFirestore get db => _db;
}

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});
