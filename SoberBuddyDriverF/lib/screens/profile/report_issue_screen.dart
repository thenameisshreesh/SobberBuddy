import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import '../../core/constants/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/shared_widgets.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _descriptionController = TextEditingController();
  String _category = 'general';
  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || _descriptionController.text.trim().isEmpty) return;

    setState(() => _submitting = true);
    await FirebaseService.db.collection('support_tickets').add({
      'userId': user.uid,
      'userType': 'driver',
      'category': _category,
      'description': _descriptionController.text.trim(),
      'status': 'open',
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });
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
      appBar: AppBar(title: const Text('Report Issue')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _category,
              dropdownColor: AppColors.surface,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'general', child: Text('General')),
                DropdownMenuItem(value: 'payment', child: Text('Payment')),
                DropdownMenuItem(value: 'safety', child: Text('Safety')),
                DropdownMenuItem(value: 'app', child: Text('App Issue')),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'general'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Describe your issue',
                alignLabelWithHint: true,
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: _submitting ? 'Submitting...' : 'Submit Ticket',
              icon: Ionicons.send,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
