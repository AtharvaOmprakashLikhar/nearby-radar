import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../shared/theme/app_theme.dart';

class PermissionStatusState {
  final bool hasBluetooth;
  final bool hasNearbyWifi;
  final bool hasLocation;
  final bool hasNotifications;
  final bool hasMedia;

  const PermissionStatusState({
    required this.hasBluetooth,
    required this.hasNearbyWifi,
    required this.hasLocation,
    required this.hasNotifications,
    required this.hasMedia,
  });

  bool get isReadyForBle => hasBluetooth && (Platform.isAndroid ? hasLocation : true);
  bool get isAllGranted => hasBluetooth && hasNearbyWifi && hasNotifications;
}

class AppPermissionManager {
  static Future<PermissionStatusState> checkAll() async {
    bool hasBle = false;
    bool hasWifi = false;
    bool hasLoc = false;
    bool hasNotif = false;
    bool hasMedia = false;

    if (Platform.isAndroid) {
      final bleScan = await Permission.bluetoothScan.status;
      final bleAdv = await Permission.bluetoothAdvertise.status;
      final bleConn = await Permission.bluetoothConnect.status;
      final bleLegacy = await Permission.bluetooth.status;

      hasBle = (bleScan.isGranted && bleAdv.isGranted && bleConn.isGranted) || bleLegacy.isGranted;
      hasWifi = await Permission.nearbyWifiDevices.status.isGranted;
      hasLoc = await Permission.locationWhenInUse.status.isGranted;
    } else if (Platform.isIOS) {
      hasBle = await Permission.bluetooth.status.isGranted;
      hasWifi = true; // iOS multipeer handles its own consent
      hasLoc = true;
    }

    hasNotif = await Permission.notification.status.isGranted;
    hasMedia = await Permission.photos.status.isGranted || await Permission.storage.status.isGranted;

    return PermissionStatusState(
      hasBluetooth: hasBle,
      hasNearbyWifi: hasWifi,
      hasLocation: hasLoc,
      hasNotifications: hasNotif,
      hasMedia: hasMedia,
    );
  }

  static Future<bool> requestCorePermissions(BuildContext context) async {
    // Show rationale sheet if needed
    final shouldProceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PermissionRationaleSheet(),
    );

    if (shouldProceed != true) return false;

    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.nearbyWifiDevices,
        Permission.locationWhenInUse,
        Permission.notification,
      ].request();

      final bleGranted = (statuses[Permission.bluetoothScan]?.isGranted ?? false) &&
          (statuses[Permission.bluetoothAdvertise]?.isGranted ?? false) &&
          (statuses[Permission.bluetoothConnect]?.isGranted ?? false);

      return bleGranted || (statuses[Permission.locationWhenInUse]?.isGranted ?? false);
    } else if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      await Permission.notification.request();
      return status.isGranted;
    }

    return true;
  }
}

class _PermissionRationaleSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.radarCyan.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.radar, color: AppColors.radarCyan, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Radar Permissions",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      "Nearby operates 100% offline via local radios",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildItem(
            icon: Icons.bluetooth_searching,
            title: "Bluetooth Scan & Advertise",
            desc: "Discovers peers on the radar and broadcasts your presence without servers.",
          ),
          _buildItem(
            icon: Icons.wifi_tethering,
            title: "Nearby Wi-Fi Devices",
            desc: "Powers ultra-fast P2P media transfer for videos and large documents.",
          ),
          _buildItem(
            icon: Icons.notifications_active_outlined,
            title: "Notifications",
            desc: "Alerts you when a nearby contact sends a connection request or chat message.",
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Grant & Continue"),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                "Not Now",
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem({required IconData icon, required String title, required String desc}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.radarCyan, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
