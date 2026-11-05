import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'wifi_direct_engine.dart';

class TransferProgressState {
  final String transferId;
  final String fileName;
  final int totalBytes;
  final int transferredBytes;
  final int speedBps;
  final bool isCompleted;
  final String? error;
  final bool isWifiDirect;

  const TransferProgressState({
    required this.transferId,
    required this.fileName,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.speedBps = 0,
    this.isCompleted = false,
    this.error,
    this.isWifiDirect = true,
  });

  double get progress => totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  String get formattedSpeed {
    if (speedBps <= 0) return "Calculating...";
    if (speedBps >= 1024 * 1024) {
      return "${(speedBps / (1024 * 1024)).toStringAsFixed(1)} MB/s";
    }
    return "${(speedBps / 1024).toStringAsFixed(0)} KB/s";
  }

  String get formattedEta {
    if (speedBps <= 0 || totalBytes <= transferredBytes) return "";
    final remainingBytes = totalBytes - transferredBytes;
    final seconds = remainingBytes ~/ speedBps;
    if (seconds < 60) return "${seconds}s left";
    return "${seconds ~/ 60}m ${seconds % 60}s left";
  }

  TransferProgressState copyWith({
    int? transferredBytes,
    int? speedBps,
    bool? isCompleted,
    String? error,
  }) {
    return TransferProgressState(
      transferId: transferId,
      fileName: fileName,
      totalBytes: totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      speedBps: speedBps ?? this.speedBps,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error ?? this.error,
      isWifiDirect: isWifiDirect,
    );
  }
}

class TransferNotifier extends StateNotifier<Map<String, TransferProgressState>> {
  TransferNotifier() : super({}) {
    _initEngineListeners();
  }

  void _initEngineListeners() {
    WifiDirectEngine.initialize();

    WifiDirectEngine.onTransferProgress = (transferId, transferred, total, speed) {
      final current = state[transferId];
      if (current != null) {
        final updated = current.copyWith(
          transferredBytes: transferred,
          speedBps: speed,
        );
        state = {...state, transferId: updated};
      }
    };

    WifiDirectEngine.onTransferCompleted = (transferId, filePath) {
      final current = state[transferId];
      if (current != null) {
        state = {...state, transferId: current.copyWith(isCompleted: true)};
      }
    };

    WifiDirectEngine.onTransferFailed = (transferId, error) {
      final current = state[transferId];
      if (current != null) {
        state = {...state, transferId: current.copyWith(error: error)};
      }
    };
  }

  void startTransfer({
    required String transferId,
    required String fileName,
    required int totalBytes,
    bool isWifiDirect = true,
  }) {
    final transfer = TransferProgressState(
      transferId: transferId,
      fileName: fileName,
      totalBytes: totalBytes,
      isWifiDirect: isWifiDirect,
    );
    state = {...state, transferId: transfer};
  }

  void cancelTransfer(String transferId) {
    final updated = Map<String, TransferProgressState>.from(state);
    updated.remove(transferId);
    state = updated;
  }
}

final transferProvider = StateNotifierProvider<TransferNotifier, Map<String, TransferProgressState>>((ref) {
  return TransferNotifier();
});
