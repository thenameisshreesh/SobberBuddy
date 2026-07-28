import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_urls.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/shared_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _otpController = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;

  @override
  void dispose() {
    for (final c in [_nameController, _phoneController, _licenseController, _otpController]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validate() {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter your full name');
      return false;
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_phoneController.text)) {
      _showError('Please enter a valid 10-digit phone number');
      return false;
    }
    if (_licenseController.text.trim().isEmpty) {
      _showError('Please enter your license number');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _sendOtp() async {
    if (!_validate()) return;
    setState(() => _loading = true);
    final error = await context.read<AuthProvider>().sendPhoneOtp(
          _phoneController.text,
          forceResend: _otpSent,
          signInOnAutoVerify: false,
        );
    setState(() {
      _loading = false;
      if (error == null) _otpSent = true;
    });
    if (error != null && mounted) _showError(error);
  }

  Future<void> _completeSignup() async {
    if (_otpController.text.length < 6) {
      _showError('Enter the 6-digit OTP');
      return;
    }
    setState(() => _loading = true);
    final error = await context.read<AuthProvider>().signupWithPhone(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          licenseNumber: _licenseController.text.trim(),
          otp: _otpController.text.trim(),
        );
    setState(() => _loading = false);
    if (!mounted) return;
    if (error != null) {
      _showError(error);
    } else {
      context.go('/onboarding/documents');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Driver Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Ionicons.car_sport, size: 64, color: Color(0xFF00D4AA)),
              const SizedBox(height: 16),
              const Text('Sign up with mobile OTP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              IconTextInput(controller: _nameController, hint: 'Full Name', icon: Ionicons.person_outline),
              const SizedBox(height: 12),
              IconTextInput(
                controller: _phoneController,
                hint: 'Phone Number',
                icon: Ionicons.call_outline,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                readOnly: _otpSent,
              ),
              const SizedBox(height: 12),
              IconTextInput(controller: _licenseController, hint: 'Driver License Number', icon: Ionicons.card_outline, readOnly: _otpSent),
              if (_otpSent) ...[
                const SizedBox(height: 12),
                IconTextInput(controller: _otpController, hint: 'Enter OTP', icon: Ionicons.keypad_outline, keyboardType: TextInputType.number),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: _loading ? 'Please wait...' : (_otpSent ? 'Verify & Create Account' : 'Send OTP'),
                icon: Ionicons.car_sport,
                loading: _loading,
                onPressed: _otpSent ? _completeSignup : _sendOtp,
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: () => context.go('/login'), child: const Text('Already have an account? Sign In')),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  children: [
                    const TextSpan(text: 'By signing up, you agree to our '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(color: Color(0xFF00D4AA)),
                      recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(privacyPolicyUrl)),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
