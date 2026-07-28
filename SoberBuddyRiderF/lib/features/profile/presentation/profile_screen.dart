import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/loading_spinner.dart';
import '../../../services/firebase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_edit_provider.dart';
import '../widgets/profile_edit_button.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loading = false;
  bool _imageLoading = false;
  bool _isEditing = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _profilePicture;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _showAlert(String title, String message, {VoidCallback? onOk}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.text)),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onOk?.call();
            },
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserProfile() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final firebase = ref.read(firebaseServiceProvider);
      final userDoc = await firebase.db.collection('users').doc(user.uid).get();

      if (!mounted) return;

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _nameController.text = data['name'] as String? ?? user.displayName ?? '';
        _phoneController.text =
            data['mobile'] as String? ?? data['phone'] as String? ?? '';
        _emailController.text = data['email'] as String? ?? user.email ?? '';
        _profilePicture = data['profilePicture'] as String?;
      } else {
        _nameController.text = user.displayName ?? '';
        _emailController.text = user.email ?? '';
        _profilePicture = user.photoURL;
      }

      setState(() {});
    } catch (_) {
      if (mounted) {
        await _showAlert('Error', 'Failed to load profile data');
      }
    }
  }

  bool _validateForm() {
    if (_nameController.text.trim().isEmpty) {
      _showAlert('Error', 'Please enter your name');
      return false;
    }
    if (_phoneController.text.trim().isNotEmpty &&
        _phoneController.text.trim().length < 10) {
      _showAlert('Error', 'Please enter a valid phone number');
      return false;
    }
    return true;
  }

  Future<void> _pickImage() async {
    if (!mounted) return;

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Select Profile Picture', style: TextStyle(color: AppColors.text)),
        content: const Text(
          'Choose an option',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            child: const Text('Camera', style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            child: const Text('Gallery', style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );

    if (source == null) return;
    await _processImage(source);
  }

  Future<void> _processImage(ImageSource source) async {
    setState(() => _imageLoading = true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 400,
        imageQuality: 80,
      );

      if (picked == null) return;

      final compressed = await FlutterImageCompress.compressWithFile(
        picked.path,
        minWidth: 400,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      if (compressed == null) {
        await _showAlert('Error', 'Failed to process profile picture. Please try again.');
        return;
      }

      final base64String = base64Encode(compressed);
      final sizeInBytes = base64String.length * 0.75;

      if (sizeInBytes > 800000) {
        await _showAlert('Error', 'Image is still too large. Please try a different image.');
        return;
      }

      final dataUri = 'data:image/jpeg;base64,$base64String';
      final user = ref.read(authProvider).user;
      if (user == null) return;

      final firebase = ref.read(firebaseServiceProvider);
      await firebase.db.collection('users').doc(user.uid).update({
        'profilePicture': dataUri,
        'profilePictureUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _profilePicture = dataUri);
        await _showAlert('Success', 'Profile picture updated successfully!');
      }
    } catch (_) {
      if (mounted) {
        await _showAlert('Error', 'Failed to process profile picture. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _imageLoading = false);
    }
  }

  Future<void> _handleSaveProfile() async {
    if (!_validateForm()) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final firebase = ref.read(firebaseServiceProvider);
      await firebase.db.collection('users').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'mobile': _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await user.updateDisplayName(_nameController.text.trim());

      if (mounted) {
        setState(() => _isEditing = false);
        ref.read(profileEditModeProvider.notifier).state = false;
        await _showAlert('Success', 'Profile updated successfully!');
      }
    } catch (_) {
      if (mounted) {
        await _showAlert('Error', 'Failed to update profile');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sign Out', style: TextStyle(color: AppColors.text)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  ImageProvider _profileImageProvider(String source) {
    if (source.startsWith('data:image')) {
      final base64Data = source.split(',').last;
      return MemoryImage(base64Decode(base64Data));
    }
    return NetworkImage(source);
  }

  Future<void> _handleDeleteAccount() async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Account', style: TextStyle(color: AppColors.text)),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone. '
          'All your data will be permanently deleted.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete Account', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Final Confirmation', style: TextStyle(color: AppColors.text)),
        content: const Text(
          'This is your last chance.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('I Understand, Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (finalConfirm != true) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final firebase = ref.read(firebaseServiceProvider);
      await firebase.db.collection('users').doc(user.uid).update({
        'accountStatus': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'isActive': false,
      });

      await ref.read(authProvider.notifier).logout();

      if (mounted) {
        await _showAlert(
          'Account Deleted',
          'Your account has been deleted and you have been signed out.',
        );
      }
    } catch (_) {
      if (mounted) {
        await _showAlert(
          'Error',
          'Failed to delete account. Please try again or contact support.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(profileEditModeProvider, (previous, next) {
      if (next && !_isEditing) {
        setState(() => _isEditing = true);
        ref.read(profileEditModeProvider.notifier).state = false;
      }
    });

    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const SizedBox.shrink();
    }

    if (_loading && _nameController.text.isEmpty) {
      return const Scaffold(
        body: LoadingSpinner(message: 'Loading profile...'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: const [ProfileEditButton()],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xl),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_profilePicture != null)
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _profileImageProvider(_profilePicture!),
                      )
                    else
                      const CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.surface,
                        child: Icon(Icons.person, size: 50, color: AppColors.textSecondary),
                      ),
                    if (_imageLoading)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      ),
                  ],
                ),
                Positioned(
                  bottom: 0,
                  right: -4,
                  child: FloatingActionButton.small(
                    onPressed: _imageLoading ? null : _pickImage,
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.camera_alt, color: AppColors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  _ProfileField(
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    controller: _nameController,
                    enabled: _isEditing,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ProfileField(
                    label: 'Phone Number',
                    icon: Icons.phone_android_outlined,
                    controller: _phoneController,
                    enabled: _isEditing,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ProfileField(
                    label: 'Email Address',
                    icon: Icons.mail_outline,
                    controller: _emailController,
                    enabled: false,
                    helperText: 'Email cannot be changed',
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleSaveProfile,
                        child: Text(
                          _loading ? 'Saving...' : 'Save Changes',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _loading
                            ? null
                            : () {
                                setState(() => _isEditing = false);
                                _loadUserProfile();
                              },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Divider(color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: OutlinedButton.icon(
                onPressed: _handleSignOut,
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.error),
                  backgroundColor: AppColors.surface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _handleDeleteAccount,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.white,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text(
                      'Delete Account',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Warning: This will permanently delete all your data and cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
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

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.enabled,
    this.keyboardType,
    this.helperText,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: keyboardType,
                  style: TextStyle(
                    color: enabled ? AppColors.text : AppColors.textSecondary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            helperText!,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}
