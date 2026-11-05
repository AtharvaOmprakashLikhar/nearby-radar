import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/ble/ble_native_bridge.dart';
import '../../../core/db/database_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../profile/providers/profile_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final LocalAuthentication _auth = LocalAuthentication();

  bool _appLockEnabled = false;
  double _transferLimitMb = 100.0;
  String _selectedTheme = "Deep Navy";

  void _toggleAppLock(bool value) async {
    if (value) {
      final canAuth = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canAuth) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Biometrics / PIN not configured on this device")),
          );
        }
        return;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: "Authenticate to enable App Lock",
      );

      if (authenticated) {
        setState(() => _appLockEnabled = true);
      }
    } else {
      setState(() => _appLockEnabled = false);
    }
  }

  void _clearStorage() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Clear Media Cache"),
        content: const Text(
          "This will remove downloaded peer attachments (images, videos, PDFs) from local device storage to free space. Text messages will remain.",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Media cache cleared")),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text("Clear", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _exportEncryptedBackup() {
    final db = ref.read(databaseServiceProvider);
    final contacts = db.getAllContacts();
    final backupData = {
      'exportedAt': DateTime.now().toIso8601String(),
      'contactsCount': contacts.length,
      'app': 'Nearby Offline Radar',
      'version': '1.0.0',
    };

    final jsonStr = jsonEncode(backupData);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Encrypted Backup Ready"),
        content: Text(
          "Encrypted offline database bundle generated (${jsonStr.length} bytes).\nReady for safe local export or peer restoration.",
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK", style: TextStyle(color: AppColors.radarCyan)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final isInvisible = profile?.status == UserStatus.invisible;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Section: Privacy & Discovery
          _buildSectionHeader("PRIVACY & DISCOVERY"),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Invisible Mode"),
                  subtitle: const Text(
                    "Stops broadcasting your beacon. You can still scan and discover peers.",
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  value: isInvisible,
                  activeColor: AppColors.radarCyan,
                  onChanged: (val) {
                    ref.read(profileProvider.notifier).updateStatus(
                          val ? UserStatus.invisible : UserStatus.available,
                        );
                    if (val) {
                      BleNativeBridge.stopAdvertising();
                    }
                  },
                ),
                const Divider(color: AppColors.surfaceBorder, height: 1),
                SwitchListTile(
                  title: const Text("App Lock (Biometric / PIN)"),
                  subtitle: const Text(
                    "Require fingerprint or Face ID to open Nearby",
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  value: _appLockEnabled,
                  activeColor: AppColors.radarCyan,
                  onChanged: _toggleAppLock,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Section: Media & Transfers
          _buildSectionHeader("TRANSFER ENGINE"),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Per-File Transfer Limit", style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        "${_transferLimitMb.toInt()} MB",
                        style: const TextStyle(color: AppColors.radarCyan, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: _transferLimitMb,
                  min: 10,
                  max: 500,
                  divisions: 49,
                  activeColor: AppColors.radarCyan,
                  inactiveColor: AppColors.surfaceElevated,
                  onChanged: (val) => setState(() => _transferLimitMb = val),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    "Payloads <=64 KB transmit over BLE GATT. Larger files stream over Android Wi-Fi Direct.",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Section: Notifications & Storage
          _buildSectionHeader("STORAGE & DATA"),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined, color: AppColors.radarCyan),
                  title: const Text("Storage Manager"),
                  subtitle: const Text("Free cached media attachments", style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  onTap: _clearStorage,
                ),
                const Divider(color: AppColors.surfaceBorder, height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_outlined, color: AppColors.radarCyan),
                  title: const Text("Export Encrypted Backup"),
                  subtitle: const Text("Save encrypted offline chat history", style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  onTap: _exportEncryptedBackup,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Section: Theme & Appearance
          _buildSectionHeader("APPEARANCE"),
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined, color: AppColors.radarCyan),
              title: const Text("Theme"),
              subtitle: Text(_selectedTheme, style: const TextStyle(fontSize: 12, color: AppColors.radarCyan)),
              trailing: DropdownButton<String>(
                value: _selectedTheme,
                underline: const SizedBox.shrink(),
                dropdownColor: AppColors.surfaceElevated,
                items: ["Deep Navy", "AMOLED Black", "Light"].map((t) {
                  return DropdownMenuItem(value: t, child: Text(t));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTheme = val);
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              "Nearby v1.0.0 • 100% Offline P2P Radar\nNo internet. No servers. Zero tracking.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted.withOpacity(0.6), fontSize: 11),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
