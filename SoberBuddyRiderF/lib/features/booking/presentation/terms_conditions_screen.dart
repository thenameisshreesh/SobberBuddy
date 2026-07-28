import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_theme.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  static final _lastUpdated =
      DateFormat('d/M/yyyy', 'en_IN').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Last updated: $_lastUpdated',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _section(
                    '1. Fare Structure',
                    const [
                      '• Base fare: ₹350 for the first 5 kilometers or 30 minutes, whichever comes first',
                      '• Additional distance: ₹20 per kilometer after the base distance',
                      '• Additional time: ₹5 per minute after the base time',
                      '• Night charges: ₹200 extra for rides between 10:00 PM and 6:00 AM',
                    ],
                  ),
                  _section(
                    '2. Cancellation Policy',
                    const [
                      '• Cancellation fee: ₹100 will be charged for trip cancellations',
                      '• Cancellation fee applies regardless of the reason for cancellation',
                      '• Fee will be deducted from your account or added to your next trip',
                    ],
                  ),
                  _section(
                    '3. Payment Terms',
                    const [
                      '• Currently, only UPI or cash payments are accepted',
                      '• Payment must be made directly to the driver upon trip completion',
                      '• Final fare may vary based on actual distance and time taken',
                    ],
                  ),
                  _section(
                    '4. Driver Wait Time',
                    const [
                      '• Drivers will wait up to 5 minutes at the pickup location',
                      '• Additional wait time may incur extra charges',
                      '• If you\'re running late, please inform the driver',
                    ],
                  ),
                  _section(
                    '5. Trip Completion',
                    const [
                      '• Only drivers can mark trips as completed',
                      '• You can only cancel trips, not complete them',
                      '• You\'ll be asked to rate your driver after trip completion',
                    ],
                  ),
                  _section(
                    '6. User Responsibilities',
                    const [
                      '• Provide accurate pickup and drop-off locations',
                      '• Be present at the pickup location on time',
                      '• Treat drivers with respect and courtesy',
                      '• Follow all safety guidelines during the trip',
                    ],
                  ),
                  _section(
                    '7. Liability',
                    const [
                      '• The service provider is not liable for delays due to traffic or unforeseen circumstances',
                      '• Users are responsible for their personal belongings during the trip',
                      '• Any damage to the vehicle will be charged to the user',
                    ],
                  ),
                  _section(
                    '8. Ratings & Reviews',
                    const [
                      '• Both users and drivers can rate each other after trip completion',
                      '• Ratings help maintain service quality',
                      '• Consistently low ratings may result in account suspension',
                    ],
                  ),
                  _section(
                    '9. Changes to Terms',
                    const [
                      '• These terms may be updated from time to time',
                      '• Users will be notified of significant changes',
                      '• Continued use constitutes acceptance of updated terms',
                    ],
                  ),
                  _section(
                    '10. Contact Information',
                    const [
                      '• For support, contact us through the app',
                      '• Emergency contact: Available 24/7 through the app',
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(AppSpacing.md),
                ),
                child: const Text(
                  'I Understand',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> bullets) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...bullets.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
