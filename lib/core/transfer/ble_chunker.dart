import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class BleChunkPacket {
  final int transferId;
  final int sequenceNumber;
  final int totalChunks;
  final Uint8List data;
  final int crc32;

  const BleChunkPacket({
    required this.transferId,
    required this.sequenceNumber,
    required this.totalChunks,
    required this.data,
    required this.crc32,
  });

  /// Binary format:
  /// [TransferId(4B) | SeqNum(2B) | TotalChunks(2B) | CRC32(4B) | PayloadData(N)]
  Uint8List toBytes() {
    final builder = BytesBuilder();
    final byteData = ByteData(12);
    byteData.setUint32(0, transferId);
    byteData.setUint16(4, sequenceNumber);
    byteData.setUint16(6, totalChunks);
    byteData.setUint32(8, crc32);

    builder.add(byteData.buffer.asUint8List());
    builder.add(data);
    return builder.toBytes();
  }

  static BleChunkPacket? fromBytes(Uint8List bytes) {
    if (bytes.length < 12) return null;
    final byteData = ByteData.sublistView(bytes, 0, 12);
    final transferId = byteData.getUint32(0);
    final seqNum = byteData.getUint16(4);
    final totalChunks = byteData.getUint16(6);
    final crc32 = byteData.getUint32(8);
    final payload = bytes.sublist(12);

    return BleChunkPacket(
      transferId: transferId,
      sequenceNumber: seqNum,
      totalChunks: totalChunks,
      data: payload,
      crc32: crc32,
    );
  }

  /// Simple 32-bit CRC calculation
  static int computeCrc32(Uint8List data) {
    int crc = 0xFFFFFFFF;
    for (final b in data) {
      crc ^= b;
      for (int i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : (crc >> 1);
      }
    }
    return ~crc & 0xFFFFFFFF;
  }
}

class BleChunkAssembly {
  final int transferId;
  final int totalChunks;
  final String targetFilePath;
  final String expectedSha256;
  final Map<int, Uint8List> receivedChunks = {};

  BleChunkAssembly({
    required this.transferId,
    required this.totalChunks,
    required this.targetFilePath,
    required this.expectedSha256,
  });

  bool addChunk(BleChunkPacket packet) {
    final computedCrc = BleChunkPacket.computeCrc32(packet.data);
    if (computedCrc != packet.crc32) {
      return false; // Checksum corrupted, request retransmit
    }
    receivedChunks[packet.sequenceNumber] = packet.data;
    return true;
  }

  bool get isComplete => receivedChunks.length == totalChunks;

  double get progress => totalChunks > 0 ? (receivedChunks.length / totalChunks).clamp(0.0, 1.0) : 0.0;

  List<int> getMissingSequenceNumbers() {
    final missing = <int>[];
    for (int i = 0; i < totalChunks; i++) {
      if (!receivedChunks.containsKey(i)) {
        missing.add(i);
      }
    }
    return missing;
  }

  /// Assembles all chunks in order, writes to file, and validates SHA-256
  Future<bool> finalizeAndVerify() async {
    if (!isComplete) return false;

    final file = File(targetFilePath);
    final sink = file.openWrite();

    for (int i = 0; i < totalChunks; i++) {
      final chunkData = receivedChunks[i];
      if (chunkData == null) {
        await sink.close();
        return false;
      }
      sink.add(chunkData);
    }

    await sink.flush();
    await sink.close();

    // Verify final SHA-256
    final writtenBytes = await file.readAsBytes();
    final actualHash = sha256.convert(writtenBytes).toString();
    return actualHash.toLowerCase() == expectedSha256.toLowerCase();
  }
}
