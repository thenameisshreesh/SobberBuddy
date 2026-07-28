import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';

class SafetyGuidelinesScreen extends StatelessWidget {
  const SafetyGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Guidelines')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          Text('Driver Safety Guidelines', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: AppSpacing.md),
          Text('• Always verify passenger identity before starting the trip.'),
          SizedBox(height: AppSpacing.sm),
          Text('• Do not drive under the influence of alcohol or drugs.'),
          SizedBox(height: AppSpacing.sm),
          Text('• Use the in-app SOS button during emergencies.'),
          SizedBox(height: AppSpacing.sm),
          Text('• Keep your vehicle documents and insurance up to date.'),
          SizedBox(height: AppSpacing.sm),
          Text('• Report unsafe behavior through Help & Support immediately.'),
        ],
      ),
    );
  }
}
