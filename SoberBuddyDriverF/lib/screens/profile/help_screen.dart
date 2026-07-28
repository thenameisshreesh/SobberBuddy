import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/theme.dart';
import '../../core/constants/app_urls.dart';
import '../../widgets/shared_widgets.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  int? _expandedFaq;

  final _faqs = [
    ('How do I start receiving trip requests?', 'Go to your dashboard and toggle the "Available" switch to go online. Make sure you have a good internet connection and location services enabled.'),
    ('How much do I earn per trip?', 'You earn 80% of the total trip fare. The base fare starts at ₹350 for the first 5km or 30 minutes, with additional charges for extra distance and time.'),
    ('When do I get paid?', 'For cash trips, you receive payment immediately from passengers. Digital payments are processed within 24-48 hours to your registered bank account.'),
    ('What if a passenger cancels the trip?', "If a passenger cancels after you've started driving to the pickup location, you may be eligible for a cancellation fee. Contact support for assistance."),
    ('How is the trip fare calculated?', 'Trip fare includes base fare (₹350), distance charges (₹20/km after 5km), time charges (₹5/min after 30min), and night charges (₹200 for 10pm-6am trips).'),
    ('What if I have an accident during a trip?', "Immediately ensure everyone's safety, call emergency services if needed, and contact our 24/7 support hotline. All trips are covered by insurance."),
    ('How can I improve my driver rating?', 'Be punctual, drive safely, keep your vehicle clean, be polite to passengers, and follow GPS directions accurately.'),
    ('What documents do I need to drive?', 'Valid driving license, vehicle registration, insurance papers, and any local permits required in your city.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Column(
                children: [
                  Icon(Ionicons.help_circle, size: 48, color: AppColors.primary),
                  SizedBox(height: 8),
                  Text('Help & Support', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text("We're here to help you succeed as a driver", style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Contact Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _contactCard('Emergency Support', '24/7 immediate assistance', Ionicons.call, () => launchUrl(Uri.parse('tel:+911800123456')), urgent: true),
            _contactCard('General Support', 'Questions and general help', Ionicons.chatbubble, () => launchUrl(Uri.parse('tel:+911800654321'))),
            _contactCard('Email Support', 'Non-urgent queries', Ionicons.mail, () => launchUrl(Uri.parse('mailto:driver-support@rideshare.com'))),
            _contactCard('WhatsApp Support', 'Chat with our team', Ionicons.logo_whatsapp, () => launchUrl(Uri.parse('https://wa.me/911800123456'))),
            const SizedBox(height: 24),
            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ActionRow(icon: Ionicons.warning, label: 'Report an Issue', onTap: () => context.push('/help')),
            ActionRow(
              icon: Ionicons.school,
              label: 'Driver Training',
              onTap: () => _showComingSoon('Driver training materials will be available soon.'),
            ),
            ActionRow(icon: Ionicons.shield_checkmark, label: 'Safety Guidelines', onTap: () => context.push('/help')),
            ActionRow(
              icon: Ionicons.play_circle,
              label: 'App Tutorial',
              onTap: () => _showComingSoon('Interactive tutorial will start on your next login.'),
            ),
            const SizedBox(height: 24),
            const Text('Frequently Asked Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...List.generate(_faqs.length, (i) => _faqItem(i, _faqs[i].$1, _faqs[i].$2)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Row(
                children: [
                  Icon(Ionicons.warning, color: AppColors.error),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'In case of emergency, call Emergency Support immediately. Your safety is our priority.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                children: [
                  _infoRow('App Version', '1.0.2'),
                  _infoRow('Platform', 'Flutter'),
                  _infoRow('User Type', 'Driver'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Ionicons.open_outline, size: 16),
                    onTap: () => launchUrl(Uri.parse(privacyPolicyUrl)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(String title, String desc, IconData icon, VoidCallback onTap, {bool urgent = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: urgent ? AppColors.error : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(icon, color: urgent ? AppColors.white : AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: urgent ? AppColors.white : AppColors.text)),
                      Text(desc, style: TextStyle(fontSize: 12, color: urgent ? AppColors.white : AppColors.textSecondary)),
                    ],
                  ),
                ),
                Icon(Ionicons.chevron_forward, color: urgent ? AppColors.white : AppColors.textSecondary, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _faqItem(int id, String question, String answer) {
    final expanded = _expandedFaq == id;
    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            title: Text(question, style: const TextStyle(fontWeight: FontWeight.w500)),
            trailing: Icon(expanded ? Ionicons.chevron_up : Ionicons.chevron_down, size: 16),
            onTap: () => setState(() => _expandedFaq = expanded ? null : id),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(answer, style: const TextStyle(color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
            Text(value),
          ],
        ),
      );

  void _showComingSoon(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Coming Soon'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
}
