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
import '../../widgets/loading_spinner.dart';
import '../../widgets/shared_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _editMode = false;
  String? _profileImage;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _email = '';
  String _license = '';
  String _driverName = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      final doc = await FirebaseService.db.collection('drivers').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _email = data['email'] ?? '';
        _license = data['licenseNumber'] ?? '';
        _driverName = data['name'] ?? 'Driver';
        _profileImage = data['profilePicture'] as String?;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showDialog('Error', 'Name cannot be empty');
      return;
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_phoneController.text)) {
      _showDialog('Error', 'Please enter a valid 10-digit phone number');
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await FirebaseService.db.collection('drivers').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text,
        'profilePicture': _profileImage,
        'updatedAt': DateTime.now(),
      });
      await FirebaseService.db.collection('users').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text,
        'profilePicture': _profileImage,
        'updatedAt': DateTime.now(),
      });
      await user.updateDisplayName(_nameController.text.trim());

      setState(() {
        _editMode = false;
        _driverName = _nameController.text.trim();
      });
      _showDialog('Success', 'Profile updated successfully');
    } catch (_) {
      _showDialog('Error', 'Failed to update profile');
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, maxWidth: 400, maxHeight: 400);
    if (file == null) return;

    try {
      final compressed = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: 200,
        minHeight: 200,
        quality: 60,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) return;

      final base64Image = 'data:image/jpeg;base64,${base64Encode(compressed)}';
      setState(() => _profileImage = base64Image);

      if (!_editMode) {
        final user = context.read<AuthProvider>().user;
        if (user != null) {
          await FirebaseService.db.collection('drivers').doc(user.uid).update({
            'profilePicture': base64Image,
            'updatedAt': DateTime.now(),
          });
          await FirebaseService.db.collection('users').doc(user.uid).update({
            'profilePicture': base64Image,
            'updatedAt': DateTime.now(),
          });
          _showDialog('Success', 'Profile picture updated successfully');
        }
      }
    } catch (_) {
      _showDialog('Error', 'Failed to process image. Please try again.');
    }
  }

  void _showImagePicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Profile Picture'),
        content: const Text('Choose an option'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            },
            child: const Text('Take Photo'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            },
            child: const Text('Choose from Gallery'),
          ),
          if (_profileImage != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _profileImage = null);
              },
              child: const Text('Remove Photo', style: TextStyle(color: AppColors.error)),
            ),
        ],
      ),
    );
  }

  void _signOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().signOut();
            },
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDelete();
            },
            child: const Text('Delete Account', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: const Text('This is your last chance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _loading = true);
              final error = await context.read<AuthProvider>().deleteAccount();
              if (mounted) {
                setState(() => _loading = false);
                if (error != null) _showDialog('Error', error);
              }
            },
            child: const Text('I Understand, Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingSpinner(message: 'Loading profile...'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            SurfaceCard(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showImagePicker,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.background,
                          backgroundImage: _profileImage != null
                              ? MemoryImage(base64Decode(_profileImage!.split(',').last))
                              : null,
                          child: _profileImage == null
                              ? const Icon(Ionicons.person, size: 48, color: AppColors.textSecondary)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Ionicons.camera, size: 16, color: AppColors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_driverName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            if (_editMode) {
                              _saveProfile();
                            } else {
                              setState(() => _editMode = true);
                            }
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    icon: Icon(_editMode ? Ionicons.checkmark : Ionicons.pencil, color: AppColors.white),
                    label: Text(
                      _saving ? 'Saving...' : _editMode ? 'Save Changes' : 'Edit Profile',
                      style: const TextStyle(color: AppColors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Personal Information', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _field('Full Name', _nameController, editable: _editMode),
                  _readOnlyField('Email Address', _email),
                  _field('Phone Number', _phoneController, editable: _editMode, keyboard: TextInputType.phone),
                  _readOnlyField('License Number', _license),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                children: [
                  ActionRow(
                    icon: Ionicons.star_outline,
                    label: 'Rating History',
                    onTap: () => context.push('/rating-history'),
                  ),
                  ActionRow(
                    icon: Ionicons.help_circle_outline,
                    label: 'Help & Support',
                    onTap: () => context.push('/help'),
                  ),
                  ActionRow(
                    icon: Ionicons.time_outline,
                    label: 'Trip History',
                    onTap: () => context.push('/trip-history'),
                  ),
                  ActionRow(
                    icon: Ionicons.log_out_outline,
                    label: 'Sign Out',
                    color: AppColors.error,
                    showChevron: false,
                    onTap: _signOut,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _deleteAccount,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                icon: const Icon(Ionicons.trash_outline, color: AppColors.white),
                label: const Text('Delete Account', style: TextStyle(color: AppColors.white)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Warning: This will permanently delete all your data and cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {bool editable = false, TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          editable
              ? TextField(
                  controller: controller,
                  keyboardType: keyboard,
                  style: const TextStyle(color: AppColors.text),
                )
              : Text(controller.text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Row(
            children: [
              Expanded(child: Text(value, style: const TextStyle(color: AppColors.textSecondary))),
              const Icon(Ionicons.lock_closed, size: 12, color: AppColors.textSecondary),
            ],
          ),
          const Text('This field cannot be changed', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
