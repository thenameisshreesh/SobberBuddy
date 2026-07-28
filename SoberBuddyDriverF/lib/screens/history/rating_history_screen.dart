import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import '../../core/constants/theme.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/shared_widgets.dart';

class RatingHistoryScreen extends StatefulWidget {
  const RatingHistoryScreen({super.key});

  @override
  State<RatingHistoryScreen> createState() => _RatingHistoryScreenState();
}

class _RatingHistoryScreenState extends State<RatingHistoryScreen> {
  List<Map<String, dynamic>> _ratings = [];
  bool _loading = true;
  double _averageRating = 0;
  int _totalRatings = 0;
  final Map<int, int> _breakdown = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      final snapshot = await FirebaseService.db
          .collection('ratings')
          .where('ratedUser', isEqualTo: user.uid)
          .where('userType', isEqualTo: 'driver')
          .orderBy('createdAt', descending: true)
          .get();

      var total = 0.0;
      final ratings = <Map<String, dynamic>>[];
      final breakdown = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        ratings.add({...data, 'id': doc.id});
        final r = (data['rating'] as num?)?.toInt() ?? 0;
        breakdown[r] = (breakdown[r] ?? 0) + 1;
        total += r;
      }

      if (mounted) {
        setState(() {
          _ratings = ratings;
          _totalRatings = ratings.length;
          _averageRating = ratings.isEmpty ? 0 : total / ratings.length;
          _breakdown
            ..clear()
            ..addAll(breakdown);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingSpinner(message: 'Loading ratings...'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rating History')),
      body: RefreshIndicator(
        onRefresh: _loadRatings,
        child: _ratings.isEmpty
            ? ListView(
                children: const [
                  EmptyState(
                    icon: Ionicons.star_outline,
                    title: 'No ratings yet',
                    subtitle: 'Complete trips to start receiving passenger ratings',
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  SurfaceCard(
                    child: Column(
                      children: [
                        Text(
                          _averageRating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        StarRating(rating: _averageRating.round(), size: 24),
                        Text('Based on $_totalRatings rating${_totalRatings != 1 ? 's' : ''}'),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat('$_totalRatings', 'Total Reviews'),
                            _stat(
                              _totalRatings > 0
                                  ? '${((_breakdown[5]! + _breakdown[4]!) / _totalRatings * 100).round()}%'
                                  : '0%',
                              'Positive',
                            ),
                            _stat(
                              _averageRating >= 4.5
                                  ? 'Excellent'
                                  : _averageRating >= 4.0
                                      ? 'Good'
                                      : _averageRating >= 3.0
                                          ? 'Average'
                                          : 'Needs Improvement',
                              'Rating',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rating Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...[5, 4, 3, 2, 1].map(_buildBreakdownRow),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._ratings.map(_buildReviewCard),
                ],
              ),
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      );

  Widget _buildBreakdownRow(int star) {
    final count = _breakdown[star] ?? 0;
    final percentage = _totalRatings > 0 ? (count / _totalRatings) * 100 : 0.0;
    final maxCount = _breakdown.values.reduce((a, b) => a > b ? a : b);
    final barWidth = maxCount > 0 ? (count / maxCount) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$star', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Ionicons.star, size: 12, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: barWidth,
                backgroundColor: AppColors.border,
                color: AppColors.primary,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count (${percentage.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> rating) {
    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StarRating(rating: (rating['rating'] as num?)?.toInt() ?? 0, size: 16),
              Text(
                Helpers.formatDate(rating['createdAt']),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (rating['comment'] != null && (rating['comment'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(rating['comment'].toString()),
          ],
        ],
      ),
    );
  }
}
