import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/shared_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter your email address');
      return;
    }

    setState(() => _loading = true);
    final error = await context.read<AuthProvider>().resetPassword(
          _emailController.text.trim(),
        );
    setState(() => _loading = false);

    if (!mounted) return;
    if (error != null) {
      _showError(error);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Success'),
          content: const Text(
            'Password reset email sent! Check your inbox and follow the instructions.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Ionicons.mail, size: 48, color: Color(0xFF00D4AA)),
              ),
              const SizedBox(height: 16),
              const Text('Reset Password', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                "Enter your email and we'll send you instructions to reset your password",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB3B3B3)),
              ),
              const SizedBox(height: 32),
              IconTextInput(
                controller: _emailController,
                hint: 'Email',
                icon: Ionicons.mail_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _loading ? 'Sending...' : 'Send Reset Email',
                loading: _loading,
                textColor: Colors.white,
                onPressed: _handleReset,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back to Login', style: TextStyle(color: Color(0xFFB3B3B3))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
