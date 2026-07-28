import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PromoService {
  PromoService({FirebaseFunctions? functions, FirebaseFirestore? db})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1'),
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;

  Future<Map<String, dynamic>> validatePromo(String code, String userId) async {
    try {
      final callable = _functions.httpsCallable('validatePromoCode');
      final result = await callable.call({'code': code, 'userId': userId});
      return Map<String, dynamic>.from(result.data as Map);
    } catch (_) {
      return _validatePromoLocal(code, userId);
    }
  }

  Future<Map<String, dynamic>> _validatePromoLocal(String code, String userId) async {
    final snap = await _db
        .collection('promo_codes')
        .where('code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) throw Exception('Invalid promo code');
    final promo = snap.docs.first.data();
    if (promo['isActive'] != true) throw Exception('Promo inactive');
    return {
      'type': promo['type'],
      'value': promo['value'],
    };
  }

  double applyDiscount(double total, Map<String, dynamic> promo) {
    final type = promo['type'] as String? ?? 'flat';
    final value = (promo['value'] as num?)?.toDouble() ?? 0;
    if (type == 'percentage') {
      return (total * (1 - value / 100)).clamp(0, double.infinity);
    }
    return (total - value).clamp(0, double.infinity);
  }
}
