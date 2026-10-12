import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp({bool forceResend = false}) async {
    if (_phoneController.text.length < 10) {
      await _showAlert('Invalid number', 'Enter a valid 10-digit mobile number.');
      return;
    }
    setState(() => _loading = true);
    final error = await ref.read(authProvider.notifier).sendPhoneOtp(
          _phoneController.text.trim(),
          forceResend: forceResend,
        );
    if (mounted) {
      setState(() {
        _loading = false;
        if (error == null) {
          _otpSent = true;
          _otpController.clear();
        }
      });
      if (error != null) {
        await _showAlert('OTP Failed', error);
      } else {
        await _showAlert(
          'SMS sent',
          'We sent an SMS OTP to +91${_phoneController.text.trim()}. Enter the code from the message.',
        );
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4 || otp.length > 6 || !RegExp(r'^\d+$').hasMatch(otp)) {
      await _showAlert('Invalid OTP', 'Enter the 4–6 digit OTP from your SMS.');
      return;
    }
    setState(() => _loading = true);
    final error = await ref.read(authProvider.notifier).verifyPhoneOtp(
          _otpController.text.trim(),
        );
    if (mounted) {
      setState(() => _loading = false);
      if (error != null) {
        await _showAlert('Verification failed', error);
      }
    }
  }

  Future<void> _showAlert(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.text)),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated) return;
      final error = next.error;
      if (error == null || previous?.error == error) return;
      if (error == 'User profile not found') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showAlert(
            'Account not found',
            'No rider account exists for this number. Please create an account first.',
          );
        });
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_taxi, size: 72, color: AppColors.primary),
              const SizedBox(height: AppSpacing.lg),
              const Text('Login with SMS OTP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'We will send a one-time code by SMS',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                readOnly: _otpSent,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(labelText: 'Mobile Number (+91)'),
              ),
              if (_otpSent) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Enter SMS OTP',
                    hintText: '4–6 digit code from SMS',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                  child: Text(_loading ? 'Please wait...' : (_otpSent ? 'Verify OTP' : 'Send SMS OTP')),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _loading ? null : () => _sendOtp(forceResend: true),
                  child: const Text('Resend SMS OTP'),
                ),
              ],
              TextButton(onPressed: () => context.push('/signup'), child: const Text('Create account')),
            ],
          ),
        ),
      ),
    );
  }
}
