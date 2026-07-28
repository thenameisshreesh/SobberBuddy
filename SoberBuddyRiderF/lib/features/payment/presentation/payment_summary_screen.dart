import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/constants/pricing.dart';
import '../../../core/utils/helpers.dart';
import '../../../services/payment_service.dart';
import '../../../services/rating_service.dart';
import '../../auth/providers/auth_provider.dart';

class PaymentSummaryScreen extends ConsumerStatefulWidget {
  const PaymentSummaryScreen({
    super.key,
    required this.tripData,
    required this.driver,
  });

  final Map<String, dynamic> tripData;
  final Map<String, dynamic> driver;

  @override
  ConsumerState<PaymentSummaryScreen> createState() => _PaymentSummaryScreenState();
}

class _PaymentSummaryScreenState extends ConsumerState<PaymentSummaryScreen> {
  int _rating = 0;
  String _comment = '';
  bool _loading = false;
  bool _paymentSaved = false;

  Map<String, dynamic> get _fareBreakdown {
    final finalBreakdown = widget.tripData['finalFareBreakdown'];
    if (finalBreakdown is Map<String, dynamic>) return finalBreakdown;
    final breakdown = widget.tripData['fareBreakdown'];
    if (breakdown is Map<String, dynamic>) return breakdown;
    return {'baseFare': Pricing.baseFare, 'total': AppHelpers.getTripAmount(widget.tripData)};
  }

  double get _totalAmount {
    final total = _fareBreakdown['total'];
    if (total is num) return total.toDouble();
    return AppHelpers.getTripAmount(widget.tripData);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _savePaymentRecord());
  }

  Future<void> _savePaymentRecord() async {
    try {
      final paymentService = ref.read(paymentServiceProvider);
      await paymentService.createPayment(widget.tripData);
      if (mounted) setState(() => _paymentSaved = true);
    } catch (_) {}
  }

  Future<void> _showAlert(String title, String message, {VoidCallback? onOk}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.text)),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onOk?.call();
            },
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmitRating() async {
    if (_rating == 0) {
      await _showAlert('Rating Required', 'Please select a rating to continue');
      return;
    }

    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final ratingService = ref.read(ratingServiceProvider);
      final driverId = widget.tripData['driverId'] as String? ?? widget.driver['id'] as String?;

      if (driverId == null) throw Exception('Driver not found');

      await ratingService.rateDriver(
        widget.tripData['id'] as String,
        user.uid,
        driverId,
        _rating,
        comment: _comment,
      );

      if (!mounted) return;
      await _showAlert(
        'Thank You!',
        'Your rating has been submitted successfully.',
        onOk: () => context.go('/home'),
      );
    } catch (_) {
      if (mounted) {
        await _showAlert('Error', 'Failed to submit rating. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSkipRating() async {
    if (!mounted) return;
    final skip = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Skip Rating', style: TextStyle(color: AppColors.text)),
        content: const Text(
          'Are you sure you want to skip rating your driver?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Skip', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (skip == true && mounted) {
      context.go('/home');
    }
  }

  Future<void> _editComment() async {
    final controller = TextEditingController(text: _comment);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add Comment', style: TextStyle(color: AppColors.text)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: AppColors.text),
          decoration: const InputDecoration(
            hintText: 'Share your experience:',
            hintStyle: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _comment = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripId = widget.tripData['id'] as String? ?? '';
    final distance = (widget.tripData['distance'] as num?)?.toDouble();
    final breakdown = _fareBreakdown;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Summary')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, size: 64, color: AppColors.success),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Trip Completed!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Thank you for riding with us',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _TripSummarySection(
                    pickup: widget.tripData['pickup'] as String? ?? '',
                    dropoff: widget.tripData['dropoff'] as String? ?? '',
                    distance: distance,
                    tripId: tripId,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PaymentSection(
                    breakdown: breakdown,
                    totalAmount: _totalAmount,
                    paymentSaved: _paymentSaved,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RatingSection(
                    driverName: widget.driver['name'] as String? ?? 'Driver',
                    rating: _rating,
                    comment: _comment,
                    onRatingChanged: (value) => setState(() => _rating = value),
                    onEditComment: _editComment,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: OutlinedButton(
                      onPressed: _loading ? null : _handleSkipRating,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text(
                        'Skip Rating',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 6,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleSubmitRating,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(
                        _loading ? 'Submitting...' : 'Submit Rating',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripSummarySection extends StatelessWidget {
  const _TripSummarySection({
    required this.pickup,
    required this.dropoff,
    required this.tripId,
    this.distance,
  });

  final String pickup;
  final String dropoff;
  final String tripId;
  final double? distance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trip Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(pickup, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
              Container(
                width: 2,
                height: 16,
                margin: const EdgeInsets.only(left: 8, top: AppSpacing.xs, bottom: AppSpacing.xs),
                color: AppColors.border,
              ),
              Row(
                children: [
                  const Icon(Icons.place, size: 16, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(dropoff, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xl, color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MetaItem(
                    label: 'Distance',
                    value: distance != null ? '${distance!.toStringAsFixed(1)} km' : 'N/A',
                  ),
                  _MetaItem(
                    label: 'Trip ID',
                    value: '#${tripId.length >= 8 ? tripId.substring(0, 8) : tripId}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.breakdown,
    required this.totalAmount,
    required this.paymentSaved,
  });

  final Map<String, dynamic> breakdown;
  final double totalAmount;
  final bool paymentSaved;

  @override
  Widget build(BuildContext context) {
    double charge(String key) => (breakdown[key] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.payments, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Cash Payment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  if (paymentSaved)
                    const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _FareRow(
                label: 'Base Fare:',
                value: formatCurrency(charge('baseFare') > 0 ? charge('baseFare') : Pricing.baseFare),
              ),
              if (charge('distanceCharge') > 0)
                _FareRow(
                  label: 'Distance Charge:',
                  value: formatCurrency(charge('distanceCharge')),
                ),
              if (charge('timeCharge') > 0)
                _FareRow(
                  label: 'Time Charge:',
                  value: formatCurrency(charge('timeCharge')),
                ),
              if (charge('nightCharge') > 0)
                _FareRow(
                  label: 'Night Charge:',
                  value: formatCurrency(charge('nightCharge')),
                ),
              const Divider(height: AppSpacing.lg, color: AppColors.border),
              _FareRow(
                label: 'Total Amount:',
                value: formatCurrency(totalAmount),
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
                valueStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Please pay ${formatCurrency(totalAmount)} in cash to your driver',
                        style: const TextStyle(color: AppColors.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FareRow extends StatelessWidget {
  const _FareRow({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: labelStyle ?? const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _RatingSection extends StatelessWidget {
  const _RatingSection({
    required this.driverName,
    required this.rating,
    required this.comment,
    required this.onRatingChanged,
    required this.onEditComment,
  });

  final String driverName;
  final int rating;
  final String comment;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onEditComment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rate Your Driver',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                driverName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'How was your ride?',
                style: TextStyle(color: AppColors.text, fontSize: 16),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return IconButton(
                    onPressed: () => onRatingChanged(star),
                    icon: Icon(
                      star <= rating ? Icons.star : Icons.star_border,
                      size: 40,
                      color: star <= rating ? AppColors.warning : AppColors.border,
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add a comment (optional)',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    InkWell(
                      onTap: onEditComment,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 80),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          comment.isEmpty ? 'Share your experience...' : comment,
                          style: TextStyle(
                            color: comment.isEmpty ? AppColors.textSecondary : AppColors.text,
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
    );
  }
}
