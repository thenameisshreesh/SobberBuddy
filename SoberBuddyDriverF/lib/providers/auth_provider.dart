import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/phone_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _userProfile;
  String? _userType;
  bool _loading = true;
  String? _error;
  bool _isSigningUp = false;

  User? get user => _user;
  Map<String, dynamic>? get userProfile => _userProfile;
  String? get userType => _userType;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    FirebaseService.auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (_isSigningUp) return;

    _loading = true;
    notifyListeners();

    if (firebaseUser == null) {
      _resetAuthState();
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      final userDoc =
          await FirebaseService.db.collection('users').doc(firebaseUser.uid).get();

      if (!userDoc.exists) {
        await FirebaseService.auth.signOut();
        _resetAuthState();
        _loading = false;
        notifyListeners();
        return;
      }

      final userData = userDoc.data()!;

      if (userData['accountStatus'] == 'deleted' ||
          userData['isActive'] == false) {
        await FirebaseService.auth.signOut();
        _resetAuthState();
        _error = 'Your account has been deleted. Please contact support.';
        _loading = false;
        notifyListeners();
        return;
      }

      if (userData['userType'] != AppConstants.userType) {
        await FirebaseService.auth.signOut();
        _resetAuthState();
        _loading = false;
        notifyListeners();
        return;
      }

      _user = firebaseUser;
      _userProfile = userData;
      _userType = userData['userType'] as String?;
      _error = null;
    } catch (e) {
      await FirebaseService.auth.signOut();
      _resetAuthState();
    }

    _loading = false;
    notifyListeners();
  }

  void _resetAuthState() {
    _user = null;
    _userProfile = null;
    _userType = null;
  }

  Future<void> signOut() async {
    await FirebaseService.auth.signOut();
    _resetAuthState();
    notifyListeners();
  }

  final _phoneAuth = PhoneAuthService();

  Future<String?> sendPhoneOtp(
    String phone, {
    bool forceResend = false,
  }) {
    return _phoneAuth.sendOtp(phone, forceResend: forceResend);
  }

  Future<String?> verifyPhoneOtp(String code) async {
    try {
      final credential = await _phoneAuth.verifyOtp(code);
      final uid = credential.user?.uid;
      if (uid == null) return 'Verification failed';

      final userDoc = await FirebaseService.db.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        await FirebaseService.auth.signOut();
        return 'No driver account found. Please sign up first.';
      }

      final userData = userDoc.data()!;
      if (userData['userType'] != AppConstants.userType) {
        await FirebaseService.auth.signOut();
        return 'This app is for drivers only.';
      }

      _user = credential.user;
      _userProfile = userData;
      _userType = userData['userType'] as String?;
      _error = null;
      _loading = false;
      notifyListeners();

      await NotificationService.instance.saveTokenToFirestore(uid, 'drivers');
      NotificationService.instance.listenTokenRefresh(uid, 'drivers');
      return null;
    } catch (e) {
      return mapPhoneAuthError(e);
    }
  }

  Future<String?> signupWithPhone({
    required String name,
    required String phone,
    required String licenseNumber,
    required String otp,
  }) async {
    _isSigningUp = true;
    try {
      final credential = await _phoneAuth.verifyOtp(otp);
      final uid = credential.user!.uid;

      final profileData = {
        'name': name,
        'phone': phone,
        'mobile': phone,
        'userType': AppConstants.userType,
        'licenseNumber': licenseNumber,
        'accountStatus': 'active',
        'isActive': true,
        'createdAt': DateTime.now(),
      };

      await FirebaseService.db.collection('users').doc(uid).set(profileData);

      await FirebaseService.db.collection('drivers').doc(uid).set({
        'userId': uid,
        'name': name,
        'phone': phone,
        'licenseNumber': licenseNumber,
        'isAvailable': false,
        'currentTrip': null,
        'documentStatus': 'pending',
        'documents': {},
        'rating': 5.0,
        'totalTrips': 0,
        'totalEarnings': 0,
        'profilePicture': null,
        'createdAt': DateTime.now(),
      });

      _user = credential.user;
      _userProfile = profileData;
      _userType = AppConstants.userType;
      _error = null;
      _loading = false;
      notifyListeners();

      await NotificationService.instance.saveTokenToFirestore(uid, 'drivers');
      NotificationService.instance.listenTokenRefresh(uid, 'drivers');
      return null;
    } catch (e) {
      return mapPhoneAuthError(e);
    } finally {
      _isSigningUp = false;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final credential = await FirebaseService.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userDoc = await FirebaseService.db
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseService.auth.signOut();
        return 'No driver record found with this email.';
      }

      final userData = userDoc.data()!;
      if (userData['accountStatus'] == 'deleted' ||
          userData['isActive'] == false) {
        await FirebaseService.auth.signOut();
        return null;
      }

      if (userData['userType'] != AppConstants.userType) {
        await FirebaseService.auth.signOut();
        return 'This app is for drivers only. You are registered as a ${userData['userType']}. Please download the ${userData['userType']} app.';
      }

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No driver account found with this email.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'invalid-email':
          return 'Invalid email address.';
        default:
          return 'Login failed. Please try again.';
      }
    }
  }

  Future<String?> signup({
    required String name,
    required String email,
    required String phone,
    required String licenseNumber,
    required String password,
  }) async {
    try {
      final credential =
          await FirebaseService.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user!.updateDisplayName(name);

      await FirebaseService.db.collection('users').doc(credential.user!.uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'userType': AppConstants.userType,
        'licenseNumber': licenseNumber,
        'accountStatus': 'active',
        'isActive': true,
        'createdAt': DateTime.now(),
      });

      await FirebaseService.db.collection('drivers').doc(credential.user!.uid).set({
        'userId': credential.user!.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'licenseNumber': licenseNumber,
        'isAvailable': false,
        'currentTrip': null,
        'rating': 5.0,
        'totalTrips': 0,
        'totalEarnings': 0,
        'profilePicture': null,
        'createdAt': DateTime.now(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'An account with this email already exists.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'weak-password':
          return 'Password is too weak.';
        default:
          return 'Account creation failed. Please try again.';
      }
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await FirebaseService.auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No driver account found with this email address.';
        case 'invalid-email':
          return 'Invalid email address.';
        default:
          return 'Failed to send reset email. Please try again.';
      }
    }
  }

  Future<String?> deleteAccount() async {
    if (_user == null) return 'Not signed in';
    try {
      await FirebaseService.db.collection('users').doc(_user!.uid).update({
        'accountStatus': 'deleted',
        'deletedAt': DateTime.now(),
        'isActive': false,
      });
      await signOut();
      return null;
    } catch (_) {
      return 'Failed to delete account. Please try again or contact support.';
    }
  }
}
