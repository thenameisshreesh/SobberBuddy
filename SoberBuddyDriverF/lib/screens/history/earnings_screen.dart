import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import '../../core/constants/theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/trip_service.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/shared_widgets.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final _tripService = TripService();
  List<TripModel> _trips = [];
  List<Map<String, dynamic>> _payouts = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _refreshing = false;
  String _period = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      final trips = await _tripService.getDriverTripHistory(user.uid);
      final stats = await _tripService.getDriverEarningsStats(user.uid);
      final payouts = await _tripService.getDriverPayouts(user.uid);
      if (mounted) {
        setState(() {
          _trips = trips;
          _stats = stats;
          _payouts = payouts;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await _loadData();
  }

  Map<String, dynamic> get _currentPeriodStats {
    if (_stats == null) return {};
    return switch (_period) {
      'today' => _stats!['today'] as Map<String, dynamic>? ?? {},
      'week' => _stats!['week'] as Map<String, dynamic>? ?? {},
      'month' => _stats!['month'] as Map<String, dynamic>? ?? {},
      _ => _stats!['total'] as Map<String, dynamic>? ?? {},
    };
  }

  List<TripModel> get _filteredTrips {
    if (_period == 'all') return _trips;
    final now = DateTime.now();
    return _trips.where((t) {
      final completed = t.completedAt?.toDate();
      if (completed == null) return false;
      return switch (_period) {
        'today' => completed.year == now.year && completed.month == now.month && completed.day == now.day,
        'week' => completed.isAfter(now.subtract(const Duration(days: 7))),
        'month' => completed.isAfter(DateTime(now.year, now.month - 1, now.day)),
        _ => true,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: null,
        body: LoadingSpinner(message: 'Loading earnings...'),
      );
    }

    final currentStats = _currentPeriodStats;
    final totalTrips = currentStats['trips'] ?? 0;
    final totalEarnings = currentStats['earnings'] ?? 0;
    final avgEarnings = totalTrips > 0 ? (totalEarnings / totalTrips).round() : 0;
    final filteredTrips = _filteredTrips;
    final pendingPayoutAmount = _payouts
        .where((p) => p['status'] == 'pending')
        .fold<int>(0, (sum, p) => sum + ((p['amount'] as num?)?.round() ?? 0));
    final completedPayoutAmount = _payouts
        .where((p) => p['status'] == 'completed')
        .fold<int>(0, (sum, p) => sum + ((p['amount'] as num?)?.round() ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: _trips.isEmpty
            ? ListView(
                children: const [
                  EmptyState(
                    icon: Ionicons.wallet_outline,
                    title: 'No earnings yet',
                    subtitle: 'Complete trips to start earning money',
                    note: 'You earn 80% of every trip fare in cash payments',
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  FilterPills(
                    selected: _period,
                    onSelected: (v) => setState(() => _period = v),
                    options: const [
                      MapEntry('today', 'Today'),
                      MapEntry('week', 'Week'),
                      MapEntry('month', 'Month'),
                      MapEntry('all', 'All Time'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SurfaceCard(
                    child: Column(
                      children: [
                        Text(
                          _period == 'all'
                              ? 'Total Earnings'
                              : '${_period[0].toUpperCase()}${_period.substring(1)} Earnings',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat('$totalTrips', 'Trips'),
                            _stat(Helpers.formatCurrency(totalEarnings), 'Earned'),
                            _stat(Helpers.formatCurrency(avgEarnings), 'Avg/Trip'),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat(Helpers.formatCurrency(pendingPayoutAmount), 'Pending Payout'),
                            _stat(Helpers.formatCurrency(completedPayoutAmount), 'Paid Out'),
                            _stat('80%', 'Your Share'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_payouts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Payout Records',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ..._payouts.map(_buildPayoutCard),
                  ],
                  const SizedBox(height: 16),
                  ...filteredTrips.map(_buildTripCard),
                ],
              ),
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      );

  Widget _buildPayoutCard(Map<String, dynamic> payout) {
    final status = payout['status'] as String? ?? 'pending';
    final amount = (payout['amount'] as num?)?.round() ?? 0;
    final period = payout['period'] as String? ?? '';
    final isPaid = status == 'completed';

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(period.isNotEmpty ? period : 'Payout', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                isPaid ? 'Paid' : 'Pending settlement',
                style: TextStyle(
                  fontSize: 12,
                  color: isPaid ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
          Text(
            Helpers.formatCurrency(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isPaid ? AppColors.success : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(TripModel trip) {
    final earnings = trip.driverEarnings ??
        Helpers.calculateEarnings(Helpers.getTripAmount(trip.data)).driver;

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(Helpers.formatDate(trip.completedAt), style: const TextStyle(color: AppColors.textSecondary)),
              Text('+${Helpers.formatCurrency(earnings)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 8),
          LocationRow(pickup: trip.pickup, dropoff: trip.dropoff),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (trip.actualDistance != null)
                    Text('${trip.actualDistance!.toStringAsFixed(1)} km  ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (trip.actualDuration != null)
                    Text(Helpers.formatDuration(trip.actualDuration!), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              Text('Total: ${Helpers.formatCurrency(Helpers.getTripAmount(trip.data))}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
