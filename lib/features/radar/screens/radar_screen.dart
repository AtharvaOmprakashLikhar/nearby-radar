import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/database_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../connections/providers/connection_provider.dart';
import '../models/radar_peer.dart';
import '../providers/radar_provider.dart';
import '../widgets/peer_blip_widget.dart';
import '../widgets/peer_profile_bottom_sheet.dart';
import '../widgets/radar_painter.dart';

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;
  bool _isListView = false;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Start scanning on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(radarProvider.notifier).startScan();
    });
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  void _showPeerDetails(RadarPeer peer) async {
    // Optionally pre-fetch profile over GATT
    ref.read(radarProvider.notifier).fetchProfileOverGatt(peer.deviceId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PeerProfileBottomSheet(
        peer: peer,
        onConnect: () {
          Navigator.of(ctx).pop();
          ref.read(connectionProvider.notifier).sendConnectionRequest(peer);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Connection request sent to ${peer.fullProfile?.displayName ?? 'peer'}"),
              backgroundColor: AppColors.surfaceElevated,
            ),
          );
        },
        onBlock: () {
          Navigator.of(ctx).pop();
          ref.read(databaseServiceProvider).blockContact(peer.deviceId, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("User blocked"),
              backgroundColor: AppColors.error,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radarState = ref.watch(radarProvider);
    final activePeers = radarState.activePeers;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: radarState.isScanning ? AppColors.radarGreen : AppColors.statusBusy,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (radarState.isScanning ? AppColors.radarGreen : AppColors.statusBusy).withOpacity(0.6),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Nearby Radar",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  // List / Radar View Toggle
                  IconButton(
                    onPressed: () => setState(() => _isListView = !_isListView),
                    icon: Icon(_isListView ? Icons.radar : Icons.format_list_bulleted),
                    tooltip: _isListView ? "Radar View" : "List View",
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: AppColors.radarCyan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Scan Toggle
                  IconButton(
                    onPressed: () {
                      if (radarState.isScanning) {
                        ref.read(radarProvider.notifier).stopScan();
                      } else {
                        ref.read(radarProvider.notifier).startScan();
                      }
                    },
                    icon: Icon(radarState.isScanning ? Icons.pause : Icons.play_arrow),
                    tooltip: radarState.isScanning ? "Pause Scan" : "Resume Scan",
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceElevated,
                      foregroundColor: AppColors.radarGreen,
                    ),
                  ),
                ],
              ),
            ),

            // Active Peers Count Badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.radarCyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.radarCyan.withOpacity(0.3)),
                    ),
                    child: Text(
                      "${activePeers.length} peer${activePeers.length == 1 ? '' : 's'} in range",
                      style: const TextStyle(
                        color: AppColors.radarCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (radarState.errorMessage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        radarState.errorMessage!,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Main Display: Radar Canvas or List View
            Expanded(
              child: _isListView ? _buildListView(activePeers) : _buildRadarView(activePeers),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarView(List<RadarPeer> activePeers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          children: [
            // Animated 60 FPS rotating radar background
            AnimatedBuilder(
              animation: _sweepController,
              builder: (context, _) {
                final sweepAngle = _sweepController.value * 2 * pi;
                return CustomPaint(
                  size: size,
                  painter: RadarPainter(sweepAngle: sweepAngle),
                );
              },
            ),

            // Peer blips overlaid
            ...activePeers.map(
              (peer) => PeerBlipWidget(
                peer: peer,
                radarSize: size,
                onTap: () => _showPeerDetails(peer),
              ),
            ),

            if (activePeers.isEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bluetooth_searching, color: AppColors.textMuted, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      "Scanning for nearby radar beacons...",
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Ensure Bluetooth is enabled on both phones",
                      style: TextStyle(color: AppColors.textMuted.withOpacity(0.6), fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildListView(List<RadarPeer> activePeers) {
    if (activePeers.isEmpty) {
      return const Center(
        child: Text(
          "No peers discovered nearby.",
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: activePeers.length,
      itemBuilder: (context, index) {
        final peer = activePeers[index];
        final name = peer.fullProfile?.displayName ?? "Nearby Device";
        final statusColor = peer.status == UserStatus.available
            ? AppColors.statusAvailable
            : (peer.status == UserStatus.busy ? AppColors.statusBusy : AppColors.statusInvisible);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.surfaceElevated,
                  child: peer.fullProfile?.avatarBytes != null
                      ? ClipOval(
                          child: Image.memory(peer.fullProfile!.avatarBytes!, fit: BoxFit.cover),
                        )
                      : Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'P',
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            subtitle: Text(
              "${peer.formattedDistance} • RSSI ${peer.rawRssi} dBm",
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: ElevatedButton(
              onPressed: () => _showPeerDetails(peer),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: const Text("View", style: TextStyle(fontSize: 12)),
            ),
          ),
        );
      },
    );
  }
}
