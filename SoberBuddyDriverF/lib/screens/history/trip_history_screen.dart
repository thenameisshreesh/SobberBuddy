import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import '../../core/constants/theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/trip_service.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/shared_widgets.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final _tripService = TripService();
  List<TripModel> _trips = [];
  bool _loading = true;
  bool _refreshing = false;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      final trips = await _tripService.getAllDriverTrips(user.uid, limit: 50);
      if (mounted) setState(() => _trips = trips);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  List<TripModel> get _filteredTrips {
    if (_selectedFilter == 'all') return _trips;
    return _trips.where((t) => t.status == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingSpinner(message: 'Loading trip history...'));
    }

    final filtered = _filteredTrips;
    final completed = filtered.where((t) => t.status == 'completed').toList();
    final totalEarnings = completed.fold<num>(0, (sum, trip) {
      return sum +
          (trip.driverEarnings ??
              Helpers.calculateEarnings(Helpers.getTripAmount(trip.data)).driver);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Trip History')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          setState(() => _refreshing = true);
          await _loadTrips();
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            FilterPills(
              selected: _selectedFilter,
              onSelected: (v) => setState(() => _selectedFilter = v),
              options: const [
                MapEntry('all', 'All Trips'),
                MapEntry('completed', 'Completed'),
                MapEntry('cancelled', 'Cancelled'),
              ],
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                children: [
                  const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('${filtered.length}', 'Trips'),
                      _stat('${completed.length}', 'Completed'),
                      _stat(Helpers.formatCurrency(totalEarnings), 'Earned'),
                      _stat('${completed.fold<double>(0, (s, t) => s + (t.actualDistance ?? t.distance ?? 0)).toStringAsFixed(1)} km', 'Distance'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              EmptyState(
                icon: Ionicons.car_outline,
                title: 'No trips found',
                subtitle: _selectedFilter == 'all'
                    ? "You haven't completed any trips yet. Start driving to see your trip history here."
                    : 'No $_selectedFilter trips found. Try changing the filter above.',
              )
            else
              ...filtered.map(_buildTripCard),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      );

  Widget _buildTripCard(TripModel trip) {
    final earnings = trip.driverEarnings ??
        Helpers.calculateEarnings(Helpers.getTripAmount(trip.data)).driver;
    final statusColor = trip.status == 'completed'
        ? AppColors.success
        : trip.status == 'cancelled'
            ? AppColors.error
            : AppColors.textSecondary;

    return InkWell(
      onTap: () => context.push('/trip-details/${trip.id}'),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Helpers.formatDate(trip.completedAt ?? trip.createdAt),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              Row(
                children: [
                  Icon(
                    trip.status == 'completed'
                        ? Ionicons.checkmark_circle
                        : trip.status == 'cancelled'
                            ? Ionicons.close_circle
                            : Ionicons.time,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trip.status[0].toUpperCase() + trip.status.substring(1),
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ],
              ),
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
                  if (trip.actualDistance != null) ...[
                    const Icon(Ionicons.speedometer, size: 14, color: AppColors.textSecondary),
                    Text(' ${trip.actualDistance!.toStringAsFixed(1)} km  '),
                  ],
                  if (trip.actualDuration != null) ...[
                    const Icon(Ionicons.time, size: 14, color: AppColors.textSecondary),
                    Text(Helpers.formatDuration(trip.actualDuration!)),
                  ],
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Helpers.formatCurrency(Helpers.getTripAmount(trip.data))),
                  if (trip.status == 'completed')
                    Text('+${Helpers.formatCurrency(earnings)}', style: const TextStyle(color: AppColors.success)),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}
