class NearbyBleConstants {
  static const String serviceUuid = "0000fee0-0000-1000-8000-00805f9b34fb";
  static const String profileCharUuid = "0000fee1-0000-1000-8000-00805f9b34fb";
  static const String connRequestCharUuid = "0000fee2-0000-1000-8000-00805f9b34fb";
  static const String messageCharUuid = "0000fee3-0000-1000-8000-00805f9b34fb";
  static const String transferCharUuid = "0000fee4-0000-1000-8000-00805f9b34fb";

  // MTU negotiation target
  static const int targetMtu = 512;

  // Maximum BLE payload chunk
  static const int maxBleChunkSize = 480;

  // Blip expiry threshold (peers fade out if not seen for 15s)
  static const Duration peerExpiryDuration = Duration(seconds: 15);
}
