import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    super.dispose();
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  bool _validate() {
    if (_nameController.text.trim().isEmpty) {
      _showAlert('Error', 'Please enter your full name');
      return false;
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_mobileController.text.trim())) {
      _showAlert('Error', 'Please enter a valid 10-digit mobile number');
      return false;
    }
    return true;
  }

  Future<void> _sendOtp({bool forceResend = false}) async {
    if (!_validate()) return;
    setState(() => _loading = true);
    final error = await ref.read(authProvider.notifier).sendPhoneOtp(
          _mobileController.text.trim(),
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
          'We sent an SMS OTP to +91${_mobileController.text.trim()}. Enter the code from the message.',
        );
      }
    }
  }

  Future<void> _completeSignup() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4 || otp.length > 6 || !RegExp(r'^\d+$').hasMatch(otp)) {
      await _showAlert('Error', 'Enter the 4–6 digit OTP from your SMS');
      return;
    }
    setState(() => _loading = true);
    final error = await ref.read(authProvider.notifier).signupWithPhone(
          name: _nameController.text.trim(),
          phone: _mobileController.text.trim(),
          otp: _otpController.text.trim(),
        );
    if (mounted) {
      setState(() => _loading = false);
      if (error != null) {
        await _showAlert('Signup Failed', error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Rider Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Icon(Icons.person_add, size: 72, color: AppColors.primary),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Sign up with SMS OTP',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'We will send a one-time code by SMS',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _nameController,
                readOnly: _otpSent,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _mobileController,
                readOnly: _otpSent,
                keyboardType: TextInputType.phone,
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
                  onPressed: _loading ? null : (_otpSent ? _completeSignup : _sendOtp),
                  child: Text(
                    _loading
                        ? 'Please wait...'
                        : (_otpSent ? 'Verify & Create Account' : 'Send SMS OTP'),
                  ),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _loading ? null : () => _sendOtp(forceResend: true),
                  child: const Text('Resend SMS OTP'),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Already have an account? Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
