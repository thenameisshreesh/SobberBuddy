import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/shell_tab_notifier.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/pricing.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/loading_spinner.dart';
import '../../../services/trip_service.dart';
import '../../auth/providers/auth_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<Map<String, dynamic>> _trips = [];
  Map<String, dynamic>? _statistics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final tripService = ref.read(tripServiceProvider);
      final results = await Future.wait([
        tripService.getAllTrips(user.uid),
        tripService.getTripStatistics(user.uid),
      ]);

      if (mounted) {
        setState(() {
          _trips = results[0] as List<Map<String, dynamic>>;
          _statistics = results[1] as Map<String, dynamic>;
        });
      }
    } catch (_) {
      // Keep existing data on error.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  double _getTripDistance(Map<String, dynamic> trip) {
    final actual = trip['actualDistance'];
    if (actual is num) return actual.toDouble();
    final distance = trip['distance'];
    if (distance is num) return distance.toDouble();
    return 0;
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'in_progress':
        return AppColors.primary;
      case 'accepted':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'in_progress':
        return Icons.directions_car;
      case 'accepted':
        return Icons.access_time;
      default:
        return Icons.help_outline;
    }
  }

  void _handleTripPress(Map<String, dynamic> trip) {
    final status = trip['status'] as String?;
    if (status == 'in_progress' || status == 'accepted') {
      context.push(
        '/trip-details',
        extra: {
          'tripId': trip['id'],
          'driver': {
            'id': trip['driverId'],
            'name': 'Driver',
          },
          'tripData': trip,
        },
      );
      return;
    }

    _showTripSummary(trip);
  }

  void _showTripSummary(Map<String, dynamic> trip) {
    final status = trip['status'] as String?;
    final amount = AppHelpers.getTripAmount(trip);
    final distance = _getTripDistance(trip);
    final cancellationFee = trip['cancellationFee'];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _statusIcon(status),
                      color: _statusColor(status),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppHelpers.formatStatus(status),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(status),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SummaryRow(
                  icon: Icons.location_on,
                  iconColor: AppColors.primary,
                  label: 'Pickup',
                  value: trip['pickup'] as String? ?? 'Unknown pickup',
                ),
                const SizedBox(height: AppSpacing.sm),
                _SummaryRow(
                  icon: Icons.place,
                  iconColor: AppColors.accent,
                  label: 'Dropoff',
                  value: trip['dropoff'] as String? ?? 'Unknown destination',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppHelpers.formatDate(trip['createdAt']),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      distance > 0 ? '${distance.toStringAsFixed(1)} km' : 'N/A',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      formatCurrency(amount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                if (status == 'cancelled' && cancellationFee != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Cancellation fee: ${formatCurrency(cancellationFee)}',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shellTabNotifierProvider, (previous, next) {
      if (next.activeTab == '/history' &&
          previous?.generation != next.generation) {
        unawaited(_loadData());
      }
    });

    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const SizedBox.shrink();
    }

    if (_loading) {
      return const Scaffold(
        body: LoadingSpinner(message: 'Loading your trips...'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Trips')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: _trips.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_statistics != null) _StatisticsCard(statistics: _statistics!),
                  const _EmptyState(),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: _trips.length + (_statistics != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_statistics != null && index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: _StatisticsCard(statistics: _statistics!),
                    );
                  }

                  final tripIndex = _statistics != null ? index - 1 : index;
                  final trip = _trips[tripIndex];
                  return _TripListItem(
                    trip: trip,
                    amount: AppHelpers.getTripAmount(trip),
                    distance: _getTripDistance(trip),
                    statusColor: _statusColor(trip['status'] as String?),
                    statusIcon: _statusIcon(trip['status'] as String?),
                    onTap: () => _handleTripPress(trip),
                  );
                },
              ),
      ),
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({required this.statistics});

  final Map<String, dynamic> statistics;

  @override
  Widget build(BuildContext context) {
    final totalSpent = (statistics['totalSpent'] as num?) ?? 0;
    final userRating = statistics['userRating'];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Trip Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                value: '${statistics['totalTrips'] ?? 0}',
                label: 'Total Trips',
              ),
              _StatItem(
                value: formatCurrency(totalSpent),
                label: 'Total Spent',
              ),
              _StatItem(
                value: '$userRating',
                label: 'Your Rating',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _TripListItem extends StatelessWidget {
  const _TripListItem({
    required this.trip,
    required this.amount,
    required this.distance,
    required this.statusColor,
    required this.statusIcon,
    required this.onTap,
  });

  final Map<String, dynamic> trip;
  final double amount;
  final double distance;
  final Color statusColor;
  final IconData statusIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = trip['status'] as String?;
    final cancellationFee = trip['cancellationFee'];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          AppHelpers.formatStatus(status),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      formatCurrency(amount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        trip['pickup'] as String? ?? 'Unknown pickup',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(Icons.place, size: 14, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        trip['dropoff'] as String? ?? 'Unknown destination',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          AppHelpers.formatDate(trip['createdAt']),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.map, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          distance > 0 ? '${distance.toStringAsFixed(1)} km' : 'N/A',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (status == 'cancelled' && cancellationFee != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      'Cancellation fee: ${formatCurrency(cancellationFee)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

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
                value,
                style: const TextStyle(color: AppColors.text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const Icon(Icons.directions_car_outlined, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No trips yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Your trip history will appear here once you book your first ride',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text(
              'Book Your First Ride',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
