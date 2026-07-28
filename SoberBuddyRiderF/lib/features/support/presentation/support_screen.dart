import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../services/support_service.dart';
import '../../auth/providers/auth_provider.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _descriptionController = TextEditingController();
  String _category = 'general';
  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null || _descriptionController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    await ref.read(supportServiceProvider).createTicket(
          userId: user.uid,
          userType: 'consumer',
          category: _category,
          description: _descriptionController.text.trim(),
        );
    if (mounted) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support ticket submitted')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Support')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _category,
              items: const [
                DropdownMenuItem(value: 'general', child: Text('General')),
                DropdownMenuItem(value: 'payment', child: Text('Payment')),
                DropdownMenuItem(value: 'safety', child: Text('Safety')),
                DropdownMenuItem(value: 'complaint', child: Text('Complaint')),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'general'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Describe your issue'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? 'Submitting...' : 'Submit Ticket'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
