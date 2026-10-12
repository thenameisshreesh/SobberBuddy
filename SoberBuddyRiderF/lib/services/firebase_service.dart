import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';

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
    if (Firebase.apps.isEmpty) {
      // On Android, initialize from google-services.json so the Firebase Android
      // appId always matches the installed package (com.soberbuddy.rider vs .dev).
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    }

    assert(() {
      final opts = Firebase.app().options;
      debugPrint(
        'Firebase ready project=${opts.projectId} appId=${opts.appId}',
      );
      return true;
    }());

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
