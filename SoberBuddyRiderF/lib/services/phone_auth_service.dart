import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

String mapPhoneAuthError(Object error) {
  assert(() {
    debugPrint('PhoneAuth error: $error');
    return true;
  }());

  if (error is FirebaseFunctionsException) {
    final message = (error.message ?? '').trim();
    switch (error.code) {
      case 'invalid-argument':
        return message.isNotEmpty
            ? message
            : 'Invalid phone number or OTP. Please try again.';
      case 'resource-exhausted':
        return message.isNotEmpty
            ? message
            : 'Too many OTP attempts. Please wait before trying again.';
      case 'failed-precondition':
        return message.isNotEmpty ? message : 'Please request OTP first.';
      case 'deadline-exceeded':
        return message.isNotEmpty
            ? message
            : 'OTP expired. Tap Resend OTP to get a new code.';
      case 'permission-denied':
        return message.isNotEmpty
            ? message
            : 'Incorrect OTP. Please check the code and try again.';
      case 'unavailable':
        return 'Network error. Check your internet connection and try again.';
      case 'unauthenticated':
        return 'Verification failed. Please try again.';
      case 'internal':
        return message.isNotEmpty && message.toUpperCase() != 'INTERNAL'
            ? message
            : 'Verification failed due to a temporary error. Please try again.';
      default:
        if (message.toUpperCase() == 'INTERNAL' || message.isEmpty) {
          return 'Verification failed due to a temporary error. Please try again.';
        }
        return message;
    }
  }

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-custom-token':
      case 'custom-token-mismatch':
      case 'internal':
        return 'Verification failed due to a temporary error. Please try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many OTP attempts. Please wait 30–60 minutes before trying again.';
      case 'missing-verification-id':
        return 'Please request OTP first.';
      case 'invalid-verification-code':
      case 'invalid-argument':
      case 'permission-denied':
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Incorrect OTP. Please check the code and try again.';
      case 'session-expired':
      case 'deadline-exceeded':
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'OTP expired. Tap Resend OTP to get a new code.';
      case 'failed-precondition':
      case 'resource-exhausted':
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Verification failed. Please try again.';
      default:
        final raw = (error.message ?? '').trim();
        if (raw.toUpperCase() == 'INTERNAL') {
          return 'Verification failed due to a temporary error. Please try again.';
        }
        final message = raw.toLowerCase();
        if (message.contains('network') || message.contains('unable to resolve')) {
          return 'Network error. Check your internet connection and try again.';
        }
        if (raw.isNotEmpty) return raw;
        return 'Verification failed. Please try again.';
    }
  }

  return 'Verification failed. Please try again.';
}

String? validateIndianMobile(String phoneNumber) {
  final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
  final local = digits.length == 12 && digits.startsWith('91')
      ? digits.substring(2)
      : digits.length == 11 && digits.startsWith('0')
          ? digits.substring(1)
          : digits;
  if (local.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(local)) {
    return 'Enter a valid 10-digit Indian mobile number.';
  }
  return null;
}

String formatIndianE164(String phoneNumber) {
  final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    return '+$digits';
  }
  if (digits.length == 11 && digits.startsWith('0')) {
    return '+91${digits.substring(1)}';
  }
  if (digits.length == 10) {
    return '+91$digits';
  }
  return phoneNumber.startsWith('+') ? phoneNumber : '+91$digits';
}

class PhoneAuthService {
  PhoneAuthService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  String? _sessionId;
  String? _pendingPhone;
  DateTime? _lastOtpSentAt;

  static const _resendCooldown = Duration(seconds: 30);
  static const sendTimeout = Duration(seconds: 60);

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

  /// Sends SMS OTP via 2Factor Cloud Function (template SoberBuddy / SBRBDY).
  /// Returns null on success, else a user-facing error.
  Future<String?> sendOtp(
    String phoneNumber, {
    bool forceResend = false,
  }) async {
    if (!forceResend && !canResend) {
      final secs = resendCooldownRemaining.inSeconds;
      return 'Please wait $secs seconds before requesting another OTP.';
    }

    final validationError = validateIndianMobile(phoneNumber);
    if (validationError != null) return validationError;

    try {
      final callable = _functions.httpsCallable(
        'sendPhoneOtp',
        options: HttpsCallableOptions(timeout: sendTimeout),
      );
      final result = await callable.call(<String, dynamic>{
        'phone': phoneNumber,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final sessionId = data['sessionId']?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        return 'Failed to send OTP. Please try again.';
      }
      _sessionId = sessionId;
      _pendingPhone = phoneNumber;
      _lastOtpSentAt = DateTime.now();
      return null;
    } catch (e) {
      return mapPhoneAuthError(e);
    }
  }

  Future<UserCredential> verifyOtp(String smsCode, {String? sessionId}) async {
    final sid = sessionId ?? _sessionId;
    final phone = _pendingPhone;
    if (sid == null || phone == null) {
      throw FirebaseAuthException(
        code: 'missing-verification-id',
        message: 'Please request OTP first',
      );
    }

    try {
      final callable = _functions.httpsCallable(
        'verifyPhoneOtp',
        options: HttpsCallableOptions(timeout: sendTimeout),
      );
      final result = await callable.call(<String, dynamic>{
        'phone': phone,
        'sessionId': sid,
        'otp': smsCode.trim(),
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final customToken = data['customToken']?.toString();
      if (customToken == null || customToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-custom-token',
          message: 'Verification failed',
        );
      }
      return _auth.signInWithCustomToken(customToken);
    } on FirebaseAuthException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: e.message,
      );
    }
  }
}
