import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../services/firebase_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/phone_auth_service.dart';
import '../domain/user_profile.dart';

class AuthState {
  const AuthState({
    this.user,
    this.userProfile,
    this.userType,
    this.loading = false,
    this.error,
  });

  final User? user;
  final UserProfile? userProfile;
  final String? userType;
  final bool loading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    UserProfile? userProfile,
    String? userType,
    bool? loading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      userProfile: clearUser ? null : (userProfile ?? this.userProfile),
      userType: clearUser ? null : (userType ?? this.userType),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AccountStatusResult {
  const AccountStatusResult({
    required this.isDeleted,
    this.userData,
    this.message,
  });

  final bool isDeleted;
  final UserProfile? userData;
  final String? message;
}

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<User?>? _authSubscription;
  bool _isCheckingAccount = false;
  bool _isSigningUp = false;
  final _phoneAuth = PhoneAuthService();

  FirebaseService get _firebase => ref.read(firebaseServiceProvider);
  FirebaseAuth get _auth => _firebase.auth;
  FirebaseFirestore get _db => _firebase.db;

  @override
  AuthState build() {
    ref.onDispose(() {
      _authSubscription?.cancel();
      _authSubscription = null;
    });

    _authSubscription ??= _auth.authStateChanges().listen(_onAuthStateChanged);

    return const AuthState(loading: true);
  }

  Future<T> retryOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
  }) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        debugPrint('Attempt $attempt failed: $error');
        if (attempt == maxRetries) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 1000 * attempt));
        await FirebaseService.ensureFirestoreOnline();
      }
    }
    throw StateError('retryOperation exhausted retries');
  }

  Future<AccountStatusResult> checkAccountStatus(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return const AccountStatusResult(isDeleted: false);
      }

      final userData = UserProfile.fromFirestore(userDoc.data()!);

      if (userData.accountStatus == 'deleted' || userData.isActive == false) {
        return AccountStatusResult(
          isDeleted: true,
          userData: userData,
          message:
              'This account has been deleted. Please contact support if you need assistance.',
        );
      }

      return AccountStatusResult(isDeleted: false, userData: userData);
    } catch (error) {
      debugPrint('Error checking account status: $error');
      return const AccountStatusResult(isDeleted: false);
    }
  }

  Future<UserProfile?> fetchUserData(String uid) {
    return retryOperation(() async {
      debugPrint('Fetching user data for: $uid');
      await FirebaseService.ensureFirestoreOnline();

      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = UserProfile.fromFirestore(userDoc.data()!);
        debugPrint('User data fetched: ${userData.userType}');
        return userData;
      }

      debugPrint('No user document found');
      return null;
    });
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    debugPrint(
      'Auth state changed: ${firebaseUser != null ? 'User logged in' : 'No user'}',
    );

    if (_isSigningUp) {
      debugPrint('Signup in progress, deferring auth listener');
      return;
    }

    if (_isCheckingAccount) {
      debugPrint('Already checking account, skipping...');
      return;
    }

    if (firebaseUser != null) {
      _isCheckingAccount = true;
      try {
        await FirebaseService.ensureFirestoreOnline();

        debugPrint('Checking account status for: ${firebaseUser.uid}');
        final accountCheck = await checkAccountStatus(firebaseUser.uid);

        if (accountCheck.isDeleted) {
          debugPrint('Account is deleted, signing out...');
          state = AuthState(
            loading: false,
            error: accountCheck.message,
          );
          await _auth.signOut();
          return;
        }

        final userData = accountCheck.userData;

        if (userData != null) {
          debugPrint('Account is active, user type: ${userData.userType}');

          if (userData.userType != AppConfig.userType) {
            debugPrint('Wrong user type, signing out...');
            final errorMsg =
                'This app is for ${AppConfig.userType}s only. Please use the ${userData.userType} app.';
            state = AuthState(loading: false, error: errorMsg);
            await _auth.signOut();
            return;
          }

          state = AuthState(
            user: firebaseUser,
            userProfile: userData,
            userType: userData.userType,
            loading: false,
          );
          debugPrint('User logged in successfully');
        } else {
          debugPrint('No user data found, signing out...');
          state = const AuthState(
            loading: false,
            error: 'User profile not found',
          );
          await _auth.signOut();
        }
      } catch (error) {
        debugPrint('Error fetching user data: $error');
        state = AuthState(
          loading: false,
          error: error.toString(),
        );
      } finally {
        _isCheckingAccount = false;
      }
    } else {
      state = const AuthState(loading: false);
      _isCheckingAccount = false;
    }
  }

  Future<void> logout() async {
    try {
      debugPrint('Logging out user...');
      state = const AuthState(loading: false);
      await _auth.signOut();
      debugPrint('User logged out successfully');
    } catch (error) {
      debugPrint('Logout error: $error');
      state = state.copyWith(error: 'Failed to log out. Please try again.');
      rethrow;
    }
  }

  Future<String?> sendPhoneOtp(
    String phone, {
    bool forceResend = false,
    bool signInOnAutoVerify = true,
  }) async {
    final completer = Completer<String?>();
    await _phoneAuth.sendOtp(
      phone,
      forceResend: forceResend,
      onCodeSent: (_, __) => completer.complete(null),
      onError: (e) => completer.complete(e),
      onAutoVerify: signInOnAutoVerify
          ? (credential) async {
              await _auth.signInWithCredential(credential);
              completer.complete(null);
            }
          : null,
    );
    return completer.future;
  }

  Future<String?> verifyPhoneOtp(String code) async {
    try {
      final credential = await _phoneAuth.verifyOtp(code);
      final user = credential.user;
      if (user == null) return 'Verification failed';

      final accountCheck = await checkAccountStatus(user.uid);
      if (accountCheck.isDeleted) {
        await _auth.signOut();
        return accountCheck.message;
      }

      final userData = accountCheck.userData;
      if (userData == null) {
        await _auth.signOut();
        return 'No rider account exists for this number. Please create an account first.';
      }

      if (userData.userType != AppConfig.userType) {
        await _auth.signOut();
        return 'This app is for riders only.';
      }

      state = AuthState(
        user: user,
        userProfile: userData,
        userType: userData.userType,
        loading: false,
      );

      final notifications = NotificationService(_db);
      await notifications.initialize();
      await notifications.saveTokenToUser(user.uid);
      notifications.listenTokenRefresh(user.uid);
      return null;
    } on FirebaseAuthException catch (e) {
      return mapPhoneAuthError(e);
    }
  }

  Future<String?> signupWithPhone({
    required String name,
    required String phone,
    required String otp,
  }) async {
    _isSigningUp = true;
    try {
      final credential = await _phoneAuth.verifyOtp(otp);
      final user = credential.user;
      if (user == null) return 'Verification failed';

      final profileData = {
        'name': name,
        'mobile': phone,
        'phone': phone,
        'userType': AppConfig.userType,
        'accountStatus': 'active',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('users').doc(user.uid).set(profileData);

      final userProfile = UserProfile.fromFirestore({
        ...profileData,
        'createdAt': null,
        'updatedAt': null,
      });

      state = AuthState(
        user: user,
        userProfile: userProfile,
        userType: AppConfig.userType,
        loading: false,
      );

      final notifications = NotificationService(_db);
      await notifications.initialize();
      await notifications.saveTokenToUser(user.uid);
      notifications.listenTokenRefresh(user.uid);
      return null;
    } on FirebaseAuthException catch (e) {
      await _auth.signOut();
      return mapPhoneAuthError(e);
    } catch (e) {
      await _auth.signOut();
      return 'Signup failed. Please try again.';
    } finally {
      _isSigningUp = false;
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

final authUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

final authUserProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authProvider).userProfile;
});

final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).loading;
});
