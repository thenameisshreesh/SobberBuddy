import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

String mapPhoneAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'too-many-requests':
      return 'Too many OTP attempts. Please wait 30–60 minutes before trying again, or use a test number during development.';
    case 'invalid-phone-number':
      return 'Invalid phone number. Enter a valid 10-digit Indian mobile number.';
    case 'quota-exceeded':
      return 'SMS quota exceeded. Please try again later.';
    case 'operation-not-allowed':
      return 'Phone sign-in is not enabled for this project. Contact support.';
    case 'invalid-verification-code':
      return 'Incorrect OTP. Please check the code and try again.';
    case 'session-expired':
      return 'OTP expired. Tap Resend OTP to get a new code.';
    case 'missing-verification-id':
      return 'Please request OTP first.';
    case 'credential-already-in-use':
      return 'This phone number is already linked to another account.';
    default:
      return e.message ?? 'Verification failed. Please try again.';
  }
}

class PhoneAuthService {
  PhoneAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  String? _verificationId;
  int? _resendToken;
  DateTime? _lastOtpSentAt;

  static const _resendCooldown = Duration(seconds: 30);

  bool get canResend {
    if (_lastOtpSentAt == null) return true;
    return DateTime.now().difference(_lastOtpSentAt!) >= _resendCooldown;
  }

  Duration get resendCooldownRemaining {
    if (_lastOtpSentAt == null) return Duration.zero;
    final elapsed = DateTime.now().difference(_lastOtpSentAt!);
    if (elapsed >= _resendCooldown) return Duration.zero;
    return _resendCooldown - elapsed;
  }

  Future<void> sendOtp(
    String phoneNumber, {
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
    void Function(PhoneAuthCredential credential)? onAutoVerify,
    bool forceResend = false,
  }) async {
    if (!forceResend && !canResend) {
      final secs = resendCooldownRemaining.inSeconds;
      onError('Please wait $secs seconds before requesting another OTP.');
      return;
    }

    final formatted = phoneNumber.startsWith('+') ? phoneNumber : '+91$phoneNumber';

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formatted,
        verificationCompleted: (credential) {
          onAutoVerify?.call(credential);
        },
        verificationFailed: (e) => onError(mapPhoneAuthError(e)),
        codeSent: (verificationId, forceResendingToken) {
          _verificationId = verificationId;
          _resendToken = forceResendingToken;
          _lastOtpSentAt = DateTime.now();
          onCodeSent(verificationId, forceResendingToken);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: forceResend ? _resendToken : null,
        timeout: const Duration(seconds: 60),
      );
    } on FirebaseAuthException catch (e) {
      onError(mapPhoneAuthError(e));
    }
  }

  Future<UserCredential> verifyOtp(String smsCode, {String? verificationId}) async {
    final vid = verificationId ?? _verificationId;
    if (vid == null) {
      throw FirebaseAuthException(
        code: 'missing-verification-id',
        message: 'Please request OTP first',
      );
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: vid,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  static Future<void> configureForPlatform() async {
    if (kDebugMode && !kIsWeb) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
    }
  }
}
