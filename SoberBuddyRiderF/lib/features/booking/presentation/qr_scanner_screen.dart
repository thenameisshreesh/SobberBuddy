import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  bool _handled = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _handled = true;

    String? partnerId;
    if (raw.startsWith('soberbuddy://partner/')) {
      partnerId = raw.replaceFirst('soberbuddy://partner/', '');
    } else if (raw.startsWith('partner:')) {
      partnerId = raw.replaceFirst('partner:', '');
    }

    if (partnerId != null) {
      final doc = await FirebaseFirestore.instance.collection('partners').doc(partnerId).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        context.pop({
          'partnerId': partnerId,
          'dropoff': data['name'] ?? 'Partner venue',
          'dropoffCoords': data['location'],
        });
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid partner QR code')),
      );
      _handled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Partner QR')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}
