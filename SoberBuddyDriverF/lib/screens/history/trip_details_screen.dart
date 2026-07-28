import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/trip_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/map_component.dart';
import '../../widgets/shared_widgets.dart';

class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  TripModel? _trip;
  Map<String, dynamic>? _rating;
  Map<String, dynamic>? _payment;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final tripDoc = await FirebaseService.db.collection('trips').doc(widget.tripId).get();
      if (tripDoc.exists) {
        _trip = TripModel.fromDoc(tripDoc);

        final ratings = await FirebaseService.db
            .collection('ratings')
            .where('tripId', isEqualTo: widget.tripId)
            .get();
        if (ratings.docs.isNotEmpty) {
          _rating = ratings.docs.first.data();
        }

        final payments = await FirebaseService.db
            .collection('payments')
            .where('tripId', isEqualTo: widget.tripId)
            .get();
        if (payments.docs.isNotEmpty) {
          _payment = payments.docs.first.data();
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingSpinner(message: 'Loading trip details...'));
    }

    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip Details')),
        body: const EmptyState(
          icon: Ionicons.alert_circle,
          title: 'Trip not found',
          subtitle: 'This trip may have been removed or is unavailable.',
        ),
      );
    }

    final trip = _trip!;
    final pickup = latLngFromMap(trip.pickupCoords);
    final fare = Helpers.getTripAmount(trip.data);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(Helpers.formatDate(trip.completedAt ?? trip.createdAt),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                StatusBadge(
                  label: trip.status[0].toUpperCase() + trip.status.substring(1),
                  color: trip.status == 'completed'
                      ? AppColors.success
                      : trip.status == 'cancelled'
                          ? AppColors.error
                          : AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trip Route', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  LocationRow(pickup: trip.pickup, dropoff: trip.dropoff),
                  if (pickup != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 150,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: MapComponent(
                          initialPosition: pickup,
                          pickupLocation: pickup,
                          dropoffLocation: latLngFromMap(trip.dropoffCoords),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metric(Ionicons.speedometer, '${(trip.actualDistance ?? trip.distance ?? 0).toStringAsFixed(1)} km'),
                  _metric(Ionicons.time, Helpers.formatDuration(trip.actualDuration ?? trip.estimatedDuration ?? 0)),
                  _metric(Ionicons.cash, Helpers.formatCurrency(fare)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fare Details', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _row('Total Fare', Helpers.formatCurrency(fare)),
                  _row('Driver Earnings', Helpers.formatCurrency(trip.driverEarnings ?? Helpers.calculateEarnings(fare).driver)),
                  if (_payment != null)
                    _row('Payment Status', _payment!['status']?.toString() ?? 'pending'),
                ],
              ),
            ),
            if (_rating != null) ...[
              const SizedBox(height: 16),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rating', style: TextStyle(fontWeight: FontWeight.bold)),
                    StarRating(rating: (_rating!['rating'] as num?)?.toInt() ?? 0, size: 20),
                    if (_rating!['comment'] != null)
                      Text(_rating!['comment'].toString()),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Ionicons.help_circle, color: AppColors.primary),
              title: const Text('Contact Support'),
              trailing: const Icon(Ionicons.chevron_forward),
              onTap: () => _contactSupport(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(IconData icon, String value) => Column(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
            Text(value),
          ],
        ),
      );

  void _contactSupport() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Text('Choose a support option for this trip:'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              launchUrl(Uri.parse('tel:+911800123456'));
              Navigator.pop(ctx);
            },
            child: const Text('Call Support'),
          ),
        ],
      ),
    );
  }
}
