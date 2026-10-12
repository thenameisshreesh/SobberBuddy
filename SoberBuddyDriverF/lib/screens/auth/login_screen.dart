import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/shared_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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

  Future<void> _sendOtp() async {
    if (_phoneController.text.length < 10) {
      _showError('Enter a valid 10-digit mobile number');
      return;
    }
    setState(() => _loading = true);
    final error = await context.read<AuthProvider>().sendPhoneOtp(
          _phoneController.text.trim(),
          forceResend: _otpSent,
        );
    setState(() {
      _loading = false;
      if (error == null) {
        _otpSent = true;
        _otpController.clear();
      }
    });
    if (!mounted) return;
    if (error != null) {
      _showError(error);
    } else {
      _showInfo(
        'SMS sent',
        'We sent an SMS OTP to +91${_phoneController.text.trim()}. Enter the code from the message.',
      );
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4 || otp.length > 6 || !RegExp(r'^\d+$').hasMatch(otp)) {
      _showError('Enter the 4–6 digit OTP from your SMS');
      return;
    }
    setState(() => _loading = true);
    final error = await context.read<AuthProvider>().verifyPhoneOtp(otp);
    setState(() => _loading = false);
    if (error != null && mounted) _showError(error);
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login Failed'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showInfo(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: const Icon(Ionicons.car_sport, size: 80, color: Color(0xFF00D4AA)),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Login with SMS OTP',
                    style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We will send a one-time code by SMS',
                    style: TextStyle(color: Color(0xFF808080), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  IconTextInput(
                    controller: _phoneController,
                    hint: 'Mobile Number (+91)',
                    icon: Ionicons.call_outline,
                    keyboardType: TextInputType.phone,
                    readOnly: _otpSent,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 16),
                    IconTextInput(
                      controller: _otpController,
                      hint: 'Enter SMS OTP (4–6 digits)',
                      icon: Ionicons.keypad_outline,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: _loading
                        ? 'Please wait...'
                        : (_otpSent ? 'Verify OTP' : 'Send SMS OTP'),
                    icon: Ionicons.car_sport,
                    loading: _loading,
                    onPressed: _otpSent ? _verifyOtp : _sendOtp,
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 12),
                    TextButton(onPressed: _loading ? null : _sendOtp, child: const Text('Resend SMS OTP')),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('New driver? ', style: TextStyle(color: Color(0xFFB3B3B3))),
                      TextButton(
                        onPressed: () => context.push('/signup'),
                        child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
