# Nearby – Offline Bluetooth Radar Messenger

A production-grade, zero-internet, serverless peer-to-peer mobile messaging app. Users discover nearby peers on an animated 60 FPS radar screen, establish end-to-end encrypted connections via Bluetooth Low Energy (BLE), and exchange encrypted text, photos, files, and videos using BLE chunking and high-speed Android Wi-Fi Direct.

---

## 🌟 Architecture & Features

### 1. Radar Discovery Screen
- **60 FPS Animated Radar:** Concentric distance rings, crosshairs, phosphor glow sweep line, and local user beacon dot.
- **Distance Estimation:** RSSI smoothed via Exponential Moving Average (EMA) mapped to physical distance categories: *Very Close (<2 m)*, *Near (~5 m)*, and *Far (~10 m+)*.
- **Stable Radial Position:** Each peer is assigned a deterministic angle derived from their userId hash so blips do not jitter between scan intervals.
- **15-Second Decay:** Inactive peers fade out smoothly if no advertisement is received for 15 seconds.
- **List-View Toggle:** Instant switcher between 2D radial radar and clean card list view.

### 2. Connection & Security Flow
- **Serverless Handshake:** Tapping a blip sends a `ConnectionRequestPayload` over GATT. Receiver gets an in-app alert with profile preview and Accept/Decline options.
- **End-to-End Encryption:** Session keys derived using Diffie-Hellman key exchange; authenticated encryption using XChaCha20-Poly1305.
- **Safety Code Fingerprint:** Both users see an identical 6-digit verification code (`XXX XXX`) computed from sorted public keys to verify channel authenticity out-of-band.
- **Contact Storage:** Accepted peers are persisted as contacts in the local SQLite database.

### 3. Chat & Offline Queue
- **Delivery States:** Queued (🕒), Sent (✓), Delivered (✓✓).
- **Offline Queue:** Messages composed when a contact is out of range are persisted in the queue and automatically transmitted the moment the peer's beacon re-enters radar range.
- **Rich Message Types:** Plaintext with copy-paste, images, PDFs, generic files, voice notes, and emoji reactions.
- **In-Chat Search:** Live filter with matching text highlight.

### 4. Transfer Engine
- **Small Payloads (<=64 KB):** Chunked over BLE GATT characteristic with sequence numbers, CRC32 verification, and final SHA-256 hash checks.
- **Large Payloads (>64 KB, Videos, Documents):** BLE negotiates transfer offer; both devices connect via Android Wi-Fi Direct (`WifiP2pManager`) and stream at high speed (MB/s).
- **Progress Tracking:** Live transfer speed (MB/s or KB/s), percentage bar, and ETA countdown.

### 5. Background Operation
- **Android Foreground Service:** Service type `connectedDevice` keeps BLE scanning and advertising alive even when the app is minimized or the screen is locked.

---

## 📱 Two-Phone Testing Guide

### Prerequisites
1. Two physical Android devices (API 26+).
2. Enable Bluetooth and Location (required by Android OS for BLE discovery) on both phones.
3. Both devices must have the app installed.

### Step-by-Step Test Walkthrough
1. **Launch App on Phone A & Phone B:**
   - Both devices generate a unique persistent cryptographic keypair and random UUID.
   - Accept the Bluetooth and Nearby Devices permissions on the prompt.
2. **Observe Radar Screen:**
   - Phone A appears on Phone B's radar as an avatar blip with a glowing green ring.
   - Move Phone B closer/further away and observe the smoothed distance updating smoothly between rings (<2m, ~5m, ~10m).
3. **Initiate Connection:**
   - On Phone A, tap Phone B's blip and tap **Send Request**.
   - Phone B receives an in-app banner showing Phone A's avatar, name, and bio.
   - Tap **Accept** on Phone B.
4. **Compare Safety Code:**
   - Open the chat on either phone, tap the shield icon in the top right.
   - Verify that the 6-digit safety code on Phone A exactly matches Phone B.
5. **Exchange Messages:**
   - Send a text message. Observe delivery checkmarks (✓✓).
   - Long press a message to react with emojis (👍, ❤️, 🔥) or copy text.
6. **Test Offline Queue:**
   - Disable Bluetooth on Phone B (or move out of range).
   - Send a message from Phone A. Note the clock icon (🕒 Queued).
   - Re-enable Bluetooth on Phone B.
   - Phone A detects Phone B and automatically flushes and delivers the queued message!
7. **Test High-Speed Transfer:**
   - Attach a large image or PDF file.
   - Observe Wi-Fi Direct P2P negotiation and real-time MB/s progress transfer.

---

## 🛠️ Build & Development Commands

```bash
# Run unit tests (Crypto & Chunker)
flutter test

# Run app on connected device
flutter run -d <device_id>
```
