import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import '../../core/constants/theme.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/shared_widgets.dart';

class TripCompletionScreen extends StatefulWidget {
  const TripCompletionScreen({super.key, required this.tripData});

  final Map<String, dynamic> tripData;

  @override
  State<TripCompletionScreen> createState() => _TripCompletionScreenState();
}

class _TripCompletionScreenState extends State<TripCompletionScreen> {
  int _rating = 0;
  String _comment = '';
  bool _loading = false;
  bool _paymentConfirmed = false;

  Future<void> _confirmPayment() async {
    final user = context.read<AuthProvider>().user;
    try {
      await FirebaseService.db
          .collection('payments')
          .doc('${widget.tripData['id']}_payment')
          .update({
        'status': 'completed',
        'confirmedBy': user?.uid,
        'confirmedAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });
    } catch (_) {}

    setState(() => _paymentConfirmed = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment has been marked as received.')),
      );
    }
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      _showDialog('Rating Required', 'Please rate your passenger to complete the trip');
      return;
    }

    setState(() => _loading = true);
    final user = context.read<AuthProvider>().user;
    try {
      await FirebaseService.db.collection('ratings').add({
        'tripId': widget.tripData['id'],
        'ratedBy': user?.uid,
        'ratedUser': widget.tripData['consumerId'],
        'userType': 'consumer',
        'rating': _rating,
        'comment': _comment,
        'createdAt': DateTime.now(),
      });

      final earnings = widget.tripData['driverEarnings'] ??
          Helpers.calculateEarnings(
            widget.tripData['fareBreakdown']?['total'] ?? widget.tripData['fare'] ?? 0,
          ).driver;

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Trip Complete!'),
            content: Text('Thank you! You earned ${Helpers.formatCurrency(earnings)}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/drive');
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      _showDialog('Error', 'Failed to submit rating. Please try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _skipRating() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip Rating'),
        content: const Text('Are you sure you want to skip rating your passenger?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/drive');
            },
            child: const Text('Yes, Skip'),
          ),
        ],
      ),
    );
  }

  void _showDialog(String title, String message) {
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

  Future<void> _addComment() async {
    final controller = TextEditingController(text: _comment);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Share your experience...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) setState(() => _comment = result);
  }

  @override
  Widget build(BuildContext context) {
    final fare = widget.tripData['fareBreakdown']?['total'] ?? widget.tripData['fare'] ?? 0;
    final earnings = widget.tripData['driverEarnings'] ??
        Helpers.calculateEarnings(fare).driver;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trip Complete'),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    const Icon(Ionicons.checkmark_circle, size: 64, color: AppColors.success),
                    const SizedBox(height: 12),
                    const Text('Trip Completed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text('Great job! Another successful trip.', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 24),
                    _sectionTitle('Trip Summary'),
                    SurfaceCard(
                      child: Column(
                        children: [
                          _summaryRow(Ionicons.location, widget.tripData['pickup'] ?? ''),
                          Container(width: 2, height: 16, color: AppColors.border, margin: const EdgeInsets.only(left: 8)),
                          _summaryRow(Ionicons.pin_sharp, widget.tripData['dropoff'] ?? ''),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _meta('Distance', '${(widget.tripData['actualDistance'] ?? widget.tripData['distance'] ?? 0).toStringAsFixed(1)} km'),
                              _meta('Duration', Helpers.formatDuration(widget.tripData['actualDuration'] ?? widget.tripData['estimatedDuration'] ?? 30)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Payment & Earnings'),
                    SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Ionicons.cash, color: AppColors.success),
                              const SizedBox(width: 8),
                              const Expanded(child: Text('UPI / Cash Payment', style: TextStyle(fontWeight: FontWeight.w600))),
                              if (_paymentConfirmed)
                                const Icon(Ionicons.checkmark_circle, color: AppColors.success, size: 16),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _fareRow('Total Trip Fare:', Helpers.formatCurrency(fare)),
                          const Divider(),
                          _fareRow('Your Earnings (80%):', Helpers.formatCurrency(earnings), isEarnings: true),
                          _fareRow('Company Share (20%):', Helpers.formatCurrency(fare - earnings)),
                          if (!_paymentConfirmed)
                            ElevatedButton.icon(
                              onPressed: _confirmPayment,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                              icon: const Icon(Ionicons.checkmark_circle, color: AppColors.white),
                              label: const Text('Confirm Payment Received', style: TextStyle(color: AppColors.white)),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Ionicons.checkmark_circle, color: AppColors.success, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(child: Text('Payment confirmed! Earnings will be processed.')),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Rate Your Passenger'),
                    SurfaceCard(
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.background,
                            child: Icon(Ionicons.person, size: 32, color: AppColors.primary),
                          ),
                          const SizedBox(height: 8),
                          Text('ID: ${(widget.tripData['consumerId'] as String?)?.substring(0, 8) ?? ''}...'),
                          const SizedBox(height: 12),
                          const Text('How was your passenger?'),
                          StarRating(rating: _rating, onRatingChanged: (r) => setState(() => _rating = r)),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Add a comment (optional)', style: TextStyle(color: AppColors.textSecondary)),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _addComment,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text(
                                      _comment.isEmpty ? 'Share your experience...' : _comment,
                                      style: TextStyle(
                                        color: _comment.isEmpty ? AppColors.textSecondary : AppColors.text,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _skipRating,
                      child: const Text('Skip Rating'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submitRating,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: Text(
                        _loading ? 'Submitting...' : 'Complete Trip',
                        style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      );

  Widget _summaryRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 16, color: icon == Ionicons.location ? AppColors.primary : AppColors.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary))),
        ],
      );

  Widget _meta(String label, String value) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );

  Widget _fareRow(String label, String value, {bool isEarnings = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(
              color: isEarnings ? AppColors.success : AppColors.textSecondary,
              fontWeight: isEarnings ? FontWeight.bold : FontWeight.normal,
            )),
            Text(value, style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isEarnings ? AppColors.success : AppColors.text,
            )),
          ],
        ),
      );
}
