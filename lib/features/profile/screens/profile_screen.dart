import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/db/database_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _tagController;
  final ImagePicker _picker = ImagePicker();

  UserStatus _selectedStatus = UserStatus.available;
  List<String> _interests = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _tagController = TextEditingController();

    final profile = ref.read(profileProvider).value;
    if (profile != null) {
      _nameController.text = profile.displayName;
      _bioController.text = profile.bio;
      _selectedStatus = profile.status;
      _interests = List.from(profile.interests);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _pickAvatar() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 320,
      maxHeight: 320,
      imageQuality: 60,
    );
    if (picked != null) {
      final rawBytes = await picked.readAsBytes();
      final clamped = UserProfile.clampAvatarSize(rawBytes);
      ref.read(profileProvider.notifier).updateAvatar(clamped);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Avatar updated (${(clamped.length / 1024).toStringAsFixed(1)} KB - fits BLE limit)"),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
    }
  }

  void _saveChanges() async {
    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    if (name.isEmpty) return;

    final notifier = ref.read(profileProvider.notifier);
    await notifier.updateNameAndBio(name, bio);
    await notifier.updateStatus(_selectedStatus);
    await notifier.updateInterests(_interests);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile saved and updated for nearby peers!"),
          backgroundColor: AppColors.surfaceElevated,
        ),
      );
    }
  }

  void _addInterestTag() {
    final tag = _tagController.text.trim().replaceAll('#', '');
    if (tag.isNotEmpty && !_interests.contains(tag)) {
      setState(() {
        _interests.add(tag);
        _tagController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Profile"),
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: const Text(
              "Save",
              style: TextStyle(color: AppColors.radarCyan, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text("Error: $err")),
        data: (profile) {
          final statusColor = _selectedStatus == UserStatus.available
              ? AppColors.statusAvailable
              : (_selectedStatus == UserStatus.busy ? AppColors.statusBusy : AppColors.statusInvisible);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with camera overlay
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceElevated,
                          border: Border.all(color: statusColor, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.35),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: profile.avatarBytes != null
                              ? Image.memory(profile.avatarBytes!, fit: BoxFit.cover)
                              : Center(
                                  child: Text(
                                    profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : 'U',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 36,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: InkWell(
                          onTap: _pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.radarCyan,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.black, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  "Avatar size capped to <= 30 KB for instant BLE exchange",
                  style: TextStyle(color: AppColors.textMuted.withOpacity(0.7), fontSize: 11),
                ),

                const SizedBox(height: 24),

                // Status Selector
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Presence Status",
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildStatusChip(UserStatus.available, "Available", AppColors.statusAvailable),
                            const SizedBox(width: 8),
                            _buildStatusChip(UserStatus.busy, "Busy", AppColors.statusBusy),
                            const SizedBox(width: 8),
                            _buildStatusChip(UserStatus.invisible, "Invisible", AppColors.statusInvisible),
                          ],
                        ),
                        if (_selectedStatus == UserStatus.invisible) ...[
                          const SizedBox(height: 8),
                          const Text(
                            "Invisible mode stops BLE advertising while scan remains active.",
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Name & Bio Inputs
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Display Name",
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(hintText: "Enter your nickname"),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Short Bio",
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _bioController,
                          maxLines: 2,
                          maxLength: 80,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(hintText: "Visible to nearby peers on the radar"),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Interests Tags
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Interest Tags",
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _interests.map((tag) {
                            return Chip(
                              label: Text("#$tag"),
                              backgroundColor: AppColors.surfaceElevated,
                              side: const BorderSide(color: AppColors.surfaceBorder),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () => setState(() => _interests.remove(tag)),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _tagController,
                                style: const TextStyle(color: AppColors.textPrimary),
                                decoration: const InputDecoration(hintText: "Add interest tag..."),
                                onSubmitted: (_) => _addInterestTag(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _addInterestTag,
                              icon: const Icon(Icons.add, color: AppColors.radarCyan),
                              style: IconButton.styleFrom(backgroundColor: AppColors.surfaceElevated),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Device Identity Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: AppColors.radarCyan, size: 20),
                            SizedBox(width: 8),
                            Text("Device Cryptographic Identity", style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "User ID: ${profile.id}",
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Public Key: ${profile.publicKey.length > 20 ? '${profile.publicKey.substring(0, 20)}...' : profile.publicKey}",
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(UserStatus status, String label, Color color) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withOpacity(0.2),
      backgroundColor: AppColors.surfaceElevated,
      side: BorderSide(color: isSelected ? color : AppColors.surfaceBorder),
      labelStyle: TextStyle(
        color: isSelected ? color : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _selectedStatus = status),
    );
  }
}
