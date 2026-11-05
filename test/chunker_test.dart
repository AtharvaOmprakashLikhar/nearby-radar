import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_radar/core/transfer/ble_chunker.dart';

void main() {
  group('BleChunker Tests', () {
    test('BleChunkPacket serialization and deserialization roundtrip', () {
      final sampleData = Uint8List.fromList([10, 20, 30, 40, 50, 60, 70, 80]);
      final crc = BleChunkPacket.computeCrc32(sampleData);

      final packet = BleChunkPacket(
        transferId: 4201,
        sequenceNumber: 3,
        totalChunks: 10,
        data: sampleData,
        crc32: crc,
      );

      final bytes = packet.toBytes();
      expect(bytes.length, equals(12 + sampleData.length));

      final parsed = BleChunkPacket.fromBytes(bytes);
      expect(parsed, isNotNull);
      expect(parsed!.transferId, equals(4201));
      expect(parsed.sequenceNumber, equals(3));
      expect(parsed.totalChunks, equals(10));
      expect(parsed.data, equals(sampleData));
      expect(parsed.crc32, equals(crc));
    });

    test('BleChunkAssembly tracks received chunks and detects missing sequences', () {
      final assembly = BleChunkAssembly(
        transferId: 99,
        totalChunks: 5,
        targetFilePath: "dummy.tmp",
        expectedSha256: "dummy_hash",
      );

      final data0 = Uint8List.fromList([1, 2, 3]);
      final data1 = Uint8List.fromList([4, 5, 6]);
      final data3 = Uint8List.fromList([7, 8, 9]);

      assembly.addChunk(BleChunkPacket(
        transferId: 99,
        sequenceNumber: 0,
        totalChunks: 5,
        data: data0,
        crc32: BleChunkPacket.computeCrc32(data0),
      ));

      assembly.addChunk(BleChunkPacket(
        transferId: 99,
        sequenceNumber: 1,
        totalChunks: 5,
        data: data1,
        crc32: BleChunkPacket.computeCrc32(data1),
      ));

      assembly.addChunk(BleChunkPacket(
        transferId: 99,
        sequenceNumber: 3,
        totalChunks: 5,
        data: data3,
        crc32: BleChunkPacket.computeCrc32(data3),
      ));

      expect(assembly.isComplete, isFalse);
      expect(assembly.progress, equals(3 / 5));

      final missing = assembly.getMissingSequenceNumbers();
      expect(missing, equals([2, 4]));
    });

    test('Corrupted chunk fails CRC32 check and is rejected', () {
      final assembly = BleChunkAssembly(
        transferId: 101,
        totalChunks: 2,
        targetFilePath: "dummy.tmp",
        expectedSha256: "dummy_hash",
      );

      final data = Uint8List.fromList([100, 101, 102]);
      final corruptedPacket = BleChunkPacket(
        transferId: 101,
        sequenceNumber: 0,
        totalChunks: 2,
        data: data,
        crc32: 0x12345678, // Intentionally wrong CRC
      );

      final added = assembly.addChunk(corruptedPacket);
      expect(added, isFalse);
      expect(assembly.receivedChunks.containsKey(0), isFalse);
    });
  });
}
