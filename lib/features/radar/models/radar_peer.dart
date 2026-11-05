import 'dart:math';
import 'dart:typed_data';
import '../../../core/db/database_service.dart';
import '../../profile/models/user_profile.dart';

class RadarPeer {
  final String deviceId;
  final Uint8List userIdHash;
  final UserStatus status;
  final int rawRssi;
  final double smoothedRssi;
  final double estimatedDistanceMeters;
  final double stableAngle; // Radians 0 .. 2*pi
  final DateTime lastSeen;
  final UserProfile? fullProfile;
  final bool isConnecting;
  final bool isConnected;

  const RadarPeer({
    required this.deviceId,
    required this.userIdHash,
    required this.status,
    required this.rawRssi,
    required this.smoothedRssi,
    required this.estimatedDistanceMeters,
    required this.stableAngle,
    required this.lastSeen,
    this.fullProfile,
    this.isConnecting = false,
    this.isConnected = false,
  });

  RadarPeer copyWith({
    int? rawRssi,
    double? smoothedRssi,
    double? estimatedDistanceMeters,
    DateTime? lastSeen,
    UserProfile? fullProfile,
    bool? isConnecting,
    bool? isConnected,
  }) {
    return RadarPeer(
      deviceId: deviceId,
      userIdHash: userIdHash,
      status: status,
      rawRssi: rawRssi ?? this.rawRssi,
      smoothedRssi: smoothedRssi ?? this.smoothedRssi,
      estimatedDistanceMeters: estimatedDistanceMeters ?? this.estimatedDistanceMeters,
      stableAngle: stableAngle,
      lastSeen: lastSeen ?? this.lastSeen,
      fullProfile: fullProfile ?? this.fullProfile,
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  /// Calculates stable radial angle from hash of deviceId + userIdHash
  static double computeStableAngle(String deviceId, Uint8List userIdHash) {
    int hash = deviceId.hashCode;
    for (final b in userIdHash) {
      hash = (hash * 31 + b) & 0x7FFFFFFF;
    }
    final normalized = (hash % 10000) / 10000.0;
    return normalized * 2 * pi;
  }

  /// Smooths RSSI using Exponential Moving Average
  static double smoothRssi(double previousSmoothed, int newRaw, {double alpha = 0.25}) {
    if (previousSmoothed == 0) return newRaw.toDouble();
    return (alpha * newRaw) + ((1.0 - alpha) * previousSmoothed);
  }

  /// Estimates approximate distance from smoothed RSSI
  /// Measured Power at 1m: -59 dBm, Path Loss Exponent: 2.2
  static double calculateDistance(double rssi, {double txPower = -59.0, double pathLossExp = 2.2}) {
    if (rssi >= 0) return 1.0;
    final ratio = (txPower - rssi) / (10 * pathLossExp);
    final distance = pow(10, ratio).toDouble();
    return distance.clamp(0.5, 30.0);
  }

  String get formattedDistance {
    if (estimatedDistanceMeters < 2.0) {
      return "Very close (<2 m)";
    } else if (estimatedDistanceMeters < 6.0) {
      return "~${estimatedDistanceMeters.toStringAsFixed(0)} m";
    } else {
      return "Far (~${estimatedDistanceMeters.toStringAsFixed(0)} m)";
    }
  }

  /// Opacity for radar blip based on 15s decay
  double get decayOpacity {
    final diff = DateTime.now().difference(lastSeen).inMilliseconds;
    if (diff >= 15000) return 0.0;
    if (diff < 10000) return 1.0;
    // Fade between 10s and 15s
    return (1.0 - ((diff - 10000) / 5000.0)).clamp(0.0, 1.0);
  }
}
