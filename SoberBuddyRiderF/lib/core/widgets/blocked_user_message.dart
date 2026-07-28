import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_config.dart';
import '../constants/app_theme.dart';
import '../constants/pricing.dart';

class BlockedUserMessage extends StatelessWidget {
  const BlockedUserMessage({
    super.key,
    required this.cancellationCount,
    required this.pendingFees,
    this.onContactSupport,
    this.supportPhone = AppConfig.supportPhone,
    this.supportEmail = AppConfig.supportEmail,
  });

  final int cancellationCount;
  final double pendingFees;
  final VoidCallback? onContactSupport;
  final String supportPhone;
  final String supportEmail;

  Future<void> _callSupport() async {
    onContactSupport?.call();
    final uri = Uri(scheme: 'tel', path: supportPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _emailSupport() async {
    onContactSupport?.call();
    const subject = 'Account Unblock Request';
    const body =
        'Hello, I would like to request that my account be unblocked. My account was blocked due to trip cancellations. Please review my case.';
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': subject, 'body': body},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ColoredBox(
        color: AppColors.background,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxl),
              const Icon(Icons.lock, size: 64, color: AppColors.error),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'Account Temporarily Locked',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Your account has been temporarily locked due to $cancellationCount trip cancellations. '
                'We understand that sometimes plans change, but multiple cancellations affect our drivers and other passengers.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              if (pendingFees > 0) ...[
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Pending Cancellation Fees:',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        formatCurrency(pendingFees),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'These fees will be added to your next trip fare once your account is restored.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'Contact Support to Restore Access',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SupportButton(
                icon: Icons.call,
                label: 'Call Support',
                detail: supportPhone,
                onTap: _callSupport,
              ),
              const SizedBox(height: AppSpacing.md),
              _SupportButton(
                icon: Icons.mail_outline,
                label: 'Email Support',
                detail: supportEmail,
                onTap: _emailSupport,
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'Our support team will review your account within 24-48 hours. '
                'Please explain any circumstances that led to the cancellations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportButton extends StatelessWidget {
  const _SupportButton({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.primary),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
