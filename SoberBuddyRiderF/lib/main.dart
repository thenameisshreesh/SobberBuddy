import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_IN');
  await FirebaseService.initialize();
  await NotificationService(FirebaseFirestore.instance).initialize();

  runApp(
    const ProviderScope(
      child: SoberBuddyApp(),
    ),
  );
}
