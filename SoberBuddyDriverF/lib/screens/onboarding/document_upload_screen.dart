import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import '../../core/constants/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/shared_widgets.dart';

const _acceptedFormats = 'JPG, JPEG, PNG';
const _maxSizeMb = 5;

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final _picker = ImagePicker();
  final _paths = <String, String>{};
  String? _uploadingDocType;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingDocuments();
  }

  Future<void> _loadExistingDocuments() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      final doc = await FirebaseService.db.collection('drivers').doc(user.uid).get();
      final existing = doc.data()?['documents'];
      if (existing is Map) {
        setState(() {
          for (final entry in existing.entries) {
            final url = entry.value?.toString();
            if (url != null && url.isNotEmpty) {
              _paths[entry.key.toString()] = url;
            }
          }
        });
      }
    } catch (_) {}
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showSourcePicker(String docType, String label) async {
    if (_uploadingDocType != null || _submitting) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Ionicons.camera_outline),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Ionicons.images_outline),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    await _pickAndUpload(docType, label, source);
  }

  Future<void> _pickAndUpload(
    String docType,
    String label,
    ImageSource source,
  ) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null) return;

      final originalBytes = await picked.readAsBytes();
      if (originalBytes.length > _maxSizeMb * 1024 * 1024) {
        _showError('Image is too large. Please use a file under $_maxSizeMb MB.');
        return;
      }

      setState(() => _uploadingDocType = docType);

      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        quality: 60,
        minWidth: 1000,
        format: CompressFormat.jpeg,
      );
      final uploadBytes = compressed ?? originalBytes;
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(uploadBytes)}';

      if (!mounted) return;
      setState(() => _paths[docType] = dataUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label uploaded successfully')),
      );
    } catch (e) {
      _showError('Failed to upload $label. Please try again.');
    } finally {
      if (mounted) setState(() => _uploadingDocType = null);
    }
  }

  Future<void> _submit() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    if (_paths.length < 4) {
      _showError('Please upload all 4 required documents');
      return;
    }

    setState(() => _submitting = true);
    try {
      await FirebaseService.db.collection('drivers').doc(user.uid).update({
        'documents': _paths,
        'documentStatus': 'pending',
        'updatedAt': DateTime.now(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documents submitted for admin approval')),
        );
        context.go('/drive');
      }
    } catch (e) {
      _showError('Failed to submit documents. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _busy => _uploadingDocType != null || _submitting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Documents')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Upload your documents for admin verification before going online.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accepted formats: $_acceptedFormats',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Max size: $_maxSizeMb MB per file (auto-compressed after upload)',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Use a clear, well-lit photo with all corners visible.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView(
                  children: [
                    _DocTile(
                      label: 'Driving License',
                      uploaded: _paths.containsKey('license'),
                      uploading: _uploadingDocType == 'license',
                      onTap: _busy ? null : () => _showSourcePicker('license', 'Driving License'),
                    ),
                    _DocTile(
                      label: 'Aadhaar Card',
                      uploaded: _paths.containsKey('aadhaar'),
                      uploading: _uploadingDocType == 'aadhaar',
                      onTap: _busy ? null : () => _showSourcePicker('aadhaar', 'Aadhaar Card'),
                    ),
                    _DocTile(
                      label: 'PAN Card',
                      uploaded: _paths.containsKey('pan'),
                      uploading: _uploadingDocType == 'pan',
                      onTap: _busy ? null : () => _showSourcePicker('pan', 'PAN Card'),
                    ),
                    _DocTile(
                      label: 'Profile Photo',
                      uploaded: _paths.containsKey('profilePhoto'),
                      uploading: _uploadingDocType == 'profilePhoto',
                      onTap: _busy ? null : () => _showSourcePicker('profilePhoto', 'Profile Photo'),
                    ),
                  ],
                ),
              ),
              PrimaryButton(
                label: _submitting ? 'Submitting...' : 'Submit for Approval',
                onPressed: _busy ? null : _submit,
                loading: _submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.label,
    required this.uploaded,
    required this.uploading,
    this.onTap,
  });

  final String label;
  final bool uploaded;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        onTap: onTap,
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        leading: uploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                uploaded ? Ionicons.checkmark_circle : Ionicons.document_outline,
                color: uploaded ? AppColors.success : AppColors.primary,
              ),
        title: Text(label),
        subtitle: Text(
          uploaded ? 'Uploaded — tap to replace' : 'Tap to upload ($_acceptedFormats)',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Text(
          uploading ? 'Uploading...' : (uploaded ? 'Done' : 'Upload'),
          style: TextStyle(
            color: uploaded ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
