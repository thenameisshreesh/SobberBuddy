import 'package:cloud_firestore/cloud_firestore.dart';

class TripModel {
  TripModel({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get status => data['status'] as String? ?? '';
  String get pickup => data['pickup'] as String? ?? '';
  String get dropoff => data['dropoff'] as String? ?? '';
  String? get consumerId => data['consumerId'] as String?;
  String? get driverId => data['driverId'] as String?;
  String get paymentMethod => data['paymentMethod'] as String? ?? 'cash';
  double? get distance => (data['distance'] as num?)?.toDouble();
  double? get actualDistance => (data['actualDistance'] as num?)?.toDouble();
  double? get estimatedDuration =>
      (data['estimatedDuration'] as num?)?.toDouble();
  double? get actualDuration => (data['actualDuration'] as num?)?.toDouble();
  num? get driverEarnings => data['driverEarnings'] as num?;
  bool get isNightTime => data['isNightTime'] as bool? ?? false;

  Map<String, dynamic>? get pickupCoords =>
      data['pickupCoords'] as Map<String, dynamic>?;
  Map<String, dynamic>? get dropoffCoords =>
      data['dropoffCoords'] as Map<String, dynamic>?;
  Map<String, dynamic>? get consumerInfo =>
      data['consumerInfo'] as Map<String, dynamic>?;
  Map<String, dynamic>? get fareBreakdown =>
      data['fareBreakdown'] as Map<String, dynamic>?;
  Map<String, dynamic>? get finalFareBreakdown =>
      data['finalFareBreakdown'] as Map<String, dynamic>?;
  Map<String, dynamic>? get vehiclePreference =>
      data['vehiclePreference'] as Map<String, dynamic>?;

  Timestamp? get createdAt => data['createdAt'] as Timestamp?;
  Timestamp? get completedAt => data['completedAt'] as Timestamp?;
  Timestamp? get startedAt => data['startedAt'] as Timestamp?;
  Timestamp? get acceptedAt => data['acceptedAt'] as Timestamp?;

  Map<String, dynamic> toMap() => {...data, 'id': id};

  static TripModel fromDoc(DocumentSnapshot doc) {
    return TripModel(
      id: doc.id,
      data: Map<String, dynamic>.from(doc.data() as Map),
    );
  }
}
