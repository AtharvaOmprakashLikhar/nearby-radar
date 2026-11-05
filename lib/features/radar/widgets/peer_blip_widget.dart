import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/db/database_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../models/radar_peer.dart';

class PeerBlipWidget extends StatelessWidget {
  final RadarPeer peer;
  final Size radarSize;
  final VoidCallback onTap;

  const PeerBlipWidget({
    super.key,
    required this.peer,
    required this.radarSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final center = Offset(radarSize.width / 2, radarSize.height / 2);
    final maxRadius = min(radarSize.width, radarSize.height) / 2 - 24;

    // Calculate normalized radial distance
    double radialFraction;
    if (peer.estimatedDistanceMeters <= 2.0) {
      radialFraction = 0.08 + (peer.estimatedDistanceMeters / 2.0) * 0.14; // 0.08 .. 0.22
    } else if (peer.estimatedDistanceMeters <= 6.0) {
      radialFraction = 0.22 + ((peer.estimatedDistanceMeters - 2.0) / 4.0) * 0.26; // 0.22 .. 0.48
    } else {
      radialFraction = 0.48 + ((peer.estimatedDistanceMeters - 6.0) / 10.0).clamp(0.0, 1.0) * 0.44; // 0.48 .. 0.92
    }

    final distanceRadius = radialFraction * maxRadius;
    final blipX = center.dx + cos(peer.stableAngle) * distanceRadius;
    final blipY = center.dy + sin(peer.stableAngle) * distanceRadius;

    final statusColor = peer.status == UserStatus.available
        ? AppColors.statusAvailable
        : (peer.status == UserStatus.busy ? AppColors.statusBusy : AppColors.statusInvisible);

    final opacity = peer.decayOpacity;

    if (opacity <= 0.0) return const SizedBox.shrink();

    final name = peer.fullProfile?.displayName ?? "Peer ${peer.deviceId.substring(peer.deviceId.length - 4)}";

    return Positioned(
      left: blipX - 22,
      top: blipY - 22,
      child: Opacity(
        opacity: opacity,
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar circle with glowing ring
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceElevated,
                  border: Border.all(
                    color: statusColor,
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: peer.fullProfile?.avatarBytes != null
                      ? Image.memory(
                          peer.fullProfile!.avatarBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildFallbackAvatar(name, statusColor),
                        )
                      : _buildFallbackAvatar(name, statusColor),
                ),
              ),
              const SizedBox(height: 4),
              // Compact name pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.surfaceBorder, width: 0.5),
                ),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String name, Color statusColor) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    return Container(
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
