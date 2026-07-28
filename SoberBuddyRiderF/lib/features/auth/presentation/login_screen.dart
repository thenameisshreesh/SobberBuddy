import 'package:flutter/material.dart';
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
        if (error == null) _otpSent = true;
      });
      if (error != null) await _showAlert('OTP Failed', error);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) {
      await _showAlert('Invalid OTP', 'Enter the 6-digit OTP.');
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
              const Text('Login with OTP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                readOnly: _otpSent,
                decoration: const InputDecoration(labelText: 'Mobile Number (+91)'),
              ),
              if (_otpSent) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Enter OTP'),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                  child: Text(_loading ? 'Please wait...' : (_otpSent ? 'Verify OTP' : 'Send OTP')),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _loading ? null : () => _sendOtp(forceResend: true),
                  child: const Text('Resend OTP'),
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
