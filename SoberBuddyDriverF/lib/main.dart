import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app/router.dart';
import 'core/constants/theme.dart';
import 'providers/auth_provider.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  await NotificationService.instance.initialize();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.surface,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const SoberBuddyDriverApp());
}

class SoberBuddyDriverApp extends StatefulWidget {
  const SoberBuddyDriverApp({super.key});

  @override
  State<SoberBuddyDriverApp> createState() => _SoberBuddyDriverAppState();
}

class _SoberBuddyDriverAppState extends State<SoberBuddyDriverApp> {
  late final AuthProvider _authProvider;
  bool _appReady = false;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _prepareApp();
  }

  Future<void> _prepareApp() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _appReady = true);
  }

  @override
  void dispose() {
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_appReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car, size: 80, color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'SoberBuddyDriver',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: _authProvider,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'SoberBuddyDriver',
        theme: AppTheme.darkTheme,
        routerConfig: createRouter(_authProvider),
      ),
    );
  }
}
