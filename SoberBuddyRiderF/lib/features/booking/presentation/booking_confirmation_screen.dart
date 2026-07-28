import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/constants/pricing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/helpers.dart';
import '../../../services/promo_service.dart';
import '../../../services/trip_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/vehicle_selector.dart';

class BookingConfirmationScreen extends ConsumerStatefulWidget {
  const BookingConfirmationScreen({super.key, required this.routeParams});

  final Map<String, dynamic> routeParams;

  @override
  ConsumerState<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends ConsumerState<BookingConfirmationScreen> {
  bool _termsAccepted = false;
  String _selectedPaymentMethod = 'cash';
  VehiclePreference? _vehicleSelection;
  late FareBreakdown _adjustedFareBreakdown;
  final _promoController = TextEditingController();
  Map<String, dynamic>? _appliedPromo;
  double _promoDiscount = 0;

  String get _pickup => widget.routeParams['pickup'] as String? ?? '';
  String get _dropoff => widget.routeParams['dropoff'] as String? ?? '';
  double get _distance => (widget.routeParams['distance'] as num?)?.toDouble() ?? 0;
  bool get _isNightTime => widget.routeParams['isNightTime'] as bool? ?? false;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _applyPromo() async {
    final user = ref.read(authProvider).user;
    if (user == null || _promoController.text.trim().isEmpty) return;
    try {
      final promo = await PromoService().validatePromo(_promoController.text.trim(), user.uid);
      final discounted = PromoService().applyDiscount(_adjustedFareBreakdown.total, promo);
      setState(() {
        _appliedPromo = promo;
        _promoDiscount = _adjustedFareBreakdown.total - discounted;
      });
    } catch (e) {
      _showAlert('Promo Error', e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    _adjustedFareBreakdown = FareBreakdown.fromMap(
      widget.routeParams['fareBreakdown'] as Map<String, dynamic>?,
    );
  }

  void _handleVehicleSelection(VehiclePreference selection) {
    final original = FareBreakdown.fromMap(
      widget.routeParams['fareBreakdown'] as Map<String, dynamic>?,
    );
    setState(() {
      _vehicleSelection = selection;
      _adjustedFareBreakdown = FareBreakdown(
        baseFare: (original.baseFare * selection.fareMultiplier).roundToDouble(),
        distanceCharge:
            (original.distanceCharge * selection.fareMultiplier).roundToDouble(),
        timeCharge: (original.timeCharge * selection.fareMultiplier).roundToDouble(),
        nightCharge: original.nightCharge,
        total: (original.total * selection.fareMultiplier).roundToDouble(),
      );
    });
  }

  Future<void> _handleConfirmBooking() async {
    if (_vehicleSelection == null) {
      _showAlert('Error', 'Please select vehicle type and transmission');
      return;
    }
    if (!_termsAccepted) {
      _showAlert('Terms Required', 'Please accept the terms and conditions to continue');
      return;
    }

    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final eligibility =
          await ref.read(tripServiceProvider).canUserBookTrip(user.uid);

      if (eligibility['canBook'] != true) {
        if (eligibility['reason'] == 'blocked') {
          _showAlert('Account Blocked', eligibility['message'] as String? ?? '');
        } else {
          _showAlert('Error', 'Unable to book trip at this time');
        }
        return;
      }

      if (!mounted) return;
      context.push(
        '/booking',
        extra: {
          'pickup': _pickup,
          'dropoff': _dropoff,
          'pickupCoords': widget.routeParams['pickupCoords'],
          'dropoffCoords': widget.routeParams['dropoffCoords'],
          'distance': _distance,
          'fareBreakdown': _adjustedFareBreakdown.toMap(),
          'isNightTime': _isNightTime,
          'paymentMethod': _selectedPaymentMethod,
          'termsAccepted': _termsAccepted,
          'vehiclePreference': _vehicleSelection!.toMap(),
          'bookingType': widget.routeParams['bookingType'] ?? 'instant',
          if (widget.routeParams['scheduledAt'] != null)
            'scheduledAt': widget.routeParams['scheduledAt'],
          if (widget.routeParams['partnerId'] != null)
            'partnerId': widget.routeParams['partnerId'],
          if (_appliedPromo != null) 'promoCode': _promoController.text.trim(),
          if (_promoDiscount > 0) 'promoDiscount': _promoDiscount,
        },
      );
    } catch (_) {
      _showAlert('Error', 'Something went wrong. Please try again.');
    }
  }

  void _showAlert(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _termsAccepted && _vehicleSelection != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Confirm Booking')),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    _TripSummaryCard(pickup: _pickup, dropoff: _dropoff),
                    const SizedBox(height: AppSpacing.md),
                    Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: VehicleSelector(onSelectionChange: _handleVehicleSelection),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FareCard(total: _adjustedFareBreakdown.total - _promoDiscount),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promoController,
                            decoration: const InputDecoration(
                              labelText: 'Promo code',
                              hintText: 'Enter code',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ElevatedButton(onPressed: _applyPromo, child: const Text('Apply')),
                      ],
                    ),
                    if (_promoDiscount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          'Promo applied: -${formatCurrency(_promoDiscount)}',
                          style: const TextStyle(color: AppColors.success),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    _PaymentCard(
                      selectedMethod: _selectedPaymentMethod,
                      onSelect: (method) =>
                          setState(() => _selectedPaymentMethod = method),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _TermsCard(
                      termsAccepted: _termsAccepted,
                      onToggle: () => setState(() => _termsAccepted = !_termsAccepted),
                      onViewTerms: () => context.push('/terms'),
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
                      onPressed: () => context.go('/home'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: canConfirm ? _handleConfirmBooking : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canConfirm
                            ? AppColors.primary
                            : AppColors.textSecondary.withValues(alpha: 0.6),
                        padding: const EdgeInsets.all(AppSpacing.md),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Confirm Booking',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Icon(Icons.arrow_forward, size: 18, color: AppColors.white),
                        ],
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
}

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({required this.pickup, required this.dropoff});

  final String pickup;
  final String dropoff;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
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
          _LocationRow(
            icon: Icons.location_on,
            iconColor: AppColors.primary,
            label: 'Pickup',
            text: pickup,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(height: 16),
          ),
          _LocationRow(
            icon: Icons.place,
            iconColor: AppColors.accent,
            label: 'Drop-off',
            text: dropoff,
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                text,
                style: const TextStyle(fontSize: 14, color: AppColors.text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FareCard extends StatelessWidget {
  const _FareCard({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Fare',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          Text(
            formatCurrency(total),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.selectedMethod,
    required this.onSelect,
  });

  final String selectedMethod;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = selectedMethod == 'cash';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Material(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () => onSelect('cash'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.payments, color: AppColors.success, size: 24),
                    const SizedBox(width: AppSpacing.md),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UPI / Cash',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            'Pay directly to driver',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsCard extends StatelessWidget {
  const _TermsCard({
    required this.termsAccepted,
    required this.onToggle,
    required this.onViewTerms,
  });

  final bool termsAccepted;
  final VoidCallback onToggle;
  final VoidCallback onViewTerms;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Terms & Conditions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            '• Cancellation fee: ₹100 will be charged',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          const Text(
            '• Wait time: Driver will wait up to 5 minutes',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          const Text(
            '• Payment: UPI / Cash payment to be made to driver',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          const Text(
            '• Night charges: ₹200 extra between 10PM-6AM',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: onToggle,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  termsAccepted ? Icons.check_box : Icons.check_box_outline_blank,
                  color: termsAccepted ? AppColors.primary : AppColors.border,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Wrap(
                    children: [
                      const Text(
                        'I agree to the ',
                        style: TextStyle(fontSize: 14, color: AppColors.text),
                      ),
                      GestureDetector(
                        onTap: onViewTerms,
                        child: const Text(
                          'Terms & Conditions',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
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
    );
  }
}

/// Factory helper for GoRouter.
Widget buildBookingConfirmationScreen(BuildContext context, GoRouterState state) {
  return BookingConfirmationScreen(routeParams: routeExtraMap(state));
}
