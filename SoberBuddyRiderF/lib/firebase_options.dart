import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCIIIMvfiDr0-2j58ExxoH91gAOIOF9XCU',
    appId: '1:411558557396:web:a86ccded1b4b6254bc6d41',
    messagingSenderId: '411558557396',
    projectId: 'soberbuddy-8367f',
    authDomain: 'soberbuddy-8367f.firebaseapp.com',
    storageBucket: 'soberbuddy-8367f.firebasestorage.app',
    measurementId: 'G-9FPJC95X48',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB3DLN7vacRT6RyadXT4n3hA_dVTm1gBV4',
    appId: '1:411558557396:android:29e502e5a6fdcfd4bc6d41',
    messagingSenderId: '411558557396',
    projectId: 'soberbuddy-8367f',
    authDomain: 'soberbuddy-8367f.firebaseapp.com',
    storageBucket: 'soberbuddy-8367f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCIIIMvfiDr0-2j58ExxoH91gAOIOF9XCU',
    appId: '1:411558557396:ios:placeholder',
    messagingSenderId: '411558557396',
    projectId: 'soberbuddy-8367f',
    authDomain: 'soberbuddy-8367f.firebaseapp.com',
    storageBucket: 'soberbuddy-8367f.firebasestorage.app',
    iosBundleId: 'com.soberbuddy.rider',
  );
}
