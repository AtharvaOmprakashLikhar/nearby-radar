package com.nearby.radar

import android.content.Intent
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val ADVERTISER_CHANNEL = "com.nearby.radar/ble_advertiser"
    private val GATT_SERVER_CHANNEL = "com.nearby.radar/ble_gatt_server"
    private val WIFI_DIRECT_CHANNEL = "com.nearby.radar/wifi_direct"
    private val FOREGROUND_CHANNEL = "com.nearby.radar/foreground_service"

    private lateinit var bleAdvertiser: BleAdvertiserManager
    private lateinit var bleGattServer: BleGattServerManager
    private lateinit var wifiDirect: WifiDirectTransferManager

    private var localProfileBytes: ByteArray = ByteArray(0)

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        bleAdvertiser = BleAdvertiserManager(this)
        bleGattServer = BleGattServerManager(this)
        wifiDirect = WifiDirectTransferManager(this)
        wifiDirect.initialize()

        // 1. Foreground Service Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val intent = Intent(this, NearbyForegroundService::class.java).apply {
                        action = NearbyForegroundService.ACTION_START
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopService" -> {
                    val intent = Intent(this, NearbyForegroundService::class.java).apply {
                        action = NearbyForegroundService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 2. BLE Advertiser Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADVERTISER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAdvertising" -> {
                    val hash = call.argument<ByteArray>("userIdHash") ?: ByteArray(4)
                    val status = (call.argument<Int>("status") ?: 0).toByte()
                    bleAdvertiser.startAdvertising(hash, status,
                        onSuccess = { result.success(true) },
                        onError = { error -> result.error("ADVERTISE_ERROR", error, null) }
                    )
                }
                "stopAdvertising" -> {
                    bleAdvertiser.stopAdvertising()
                    result.success(true)
                }
                "isAdvertising" -> {
                    result.success(bleAdvertiser.isCurrentlyAdvertising())
                }
                else -> result.notImplemented()
            }
        }

        // 3. BLE GATT Server Channel
        val gattChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GATT_SERVER_CHANNEL)
        bleGattServer.setListener(object : BleGattServerManager.GattServerListener {
            override fun onProfileReadRequested(deviceAddress: String, offset: Int): ByteArray? {
                return localProfileBytes
            }

            override fun onConnectionRequestReceived(deviceAddress: String, payload: ByteArray) {
                gattChannel.invokeMethod("onConnectionRequest", mapOf(
                    "deviceAddress" to deviceAddress,
                    "payload" to payload
                ))
            }

            override fun onMessageChunkReceived(deviceAddress: String, payload: ByteArray) {
                gattChannel.invokeMethod("onMessageChunk", mapOf(
                    "deviceAddress" to deviceAddress,
                    "payload" to payload
                ))
            }

            override fun onTransferNegotiationReceived(deviceAddress: String, payload: ByteArray) {
                gattChannel.invokeMethod("onTransferNegotiation", mapOf(
                    "deviceAddress" to deviceAddress,
                    "payload" to payload
                ))
            }

            override fun onDeviceConnected(deviceAddress: String) {
                gattChannel.invokeMethod("onCentralConnected", mapOf("deviceAddress" to deviceAddress))
            }

            override fun onDeviceDisconnected(deviceAddress: String) {
                gattChannel.invokeMethod("onCentralDisconnected", mapOf("deviceAddress" to deviceAddress))
            }
        })

        gattChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startServer" -> {
                    bleGattServer.startServer(
                        onSuccess = { result.success(true) },
                        onError = { err -> result.error("GATT_SERVER_ERROR", err, null) }
                    )
                }
                "stopServer" -> {
                    bleGattServer.stopServer()
                    result.success(true)
                }
                "setProfilePayload" -> {
                    val bytes = call.argument<ByteArray>("payload") ?: ByteArray(0)
                    localProfileBytes = bytes
                    result.success(true)
                }
                "notifyClient" -> {
                    val address = call.argument<String>("deviceAddress") ?: ""
                    val charUuidStr = call.argument<String>("characteristicUuid") ?: ""
                    val payload = call.argument<ByteArray>("payload") ?: ByteArray(0)
                    bleGattServer.notifyCharacteristic(address, UUID.fromString(charUuidStr), payload)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 4. Wi-Fi Direct Channel
        val wifiChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIFI_DIRECT_CHANNEL)
        wifiDirect.setListener(object : WifiDirectTransferManager.TransferListener {
            override fun onWifiP2pStateChanged(enabled: Boolean) {
                wifiChannel.invokeMethod("onWifiStateChanged", mapOf("enabled" to enabled))
            }

            override fun onConnectionChanged(connected: Boolean, isGroupOwner: Boolean, groupOwnerAddress: String?) {
                wifiChannel.invokeMethod("onConnectionChanged", mapOf(
                    "connected" to connected,
                    "isGroupOwner" to isGroupOwner,
                    "groupOwnerAddress" to groupOwnerAddress
                ))
            }

            override fun onTransferProgress(transferId: String, bytesTransferred: Long, totalBytes: Long, speedBps: Long) {
                wifiChannel.invokeMethod("onTransferProgress", mapOf(
                    "transferId" to transferId,
                    "bytesTransferred" to bytesTransferred,
                    "totalBytes" to totalBytes,
                    "speedBps" to speedBps
                ))
            }

            override fun onTransferCompleted(transferId: String, filePath: String) {
                wifiChannel.invokeMethod("onTransferCompleted", mapOf(
                    "transferId" to transferId,
                    "filePath" to filePath
                ))
            }

            override fun onTransferFailed(transferId: String, error: String) {
                wifiChannel.invokeMethod("onTransferFailed", mapOf(
                    "transferId" to transferId,
                    "error" to error
                ))
            }
        })

        wifiChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "createGroup" -> {
                    wifiDirect.createGroup(
                        onSuccess = { result.success(true) },
                        onError = { err -> result.error("WIFI_GROUP_ERROR", err, null) }
                    )
                }
                "removeGroup" -> {
                    wifiDirect.removeGroup()
                    result.success(true)
                }
                "connect" -> {
                    val address = call.argument<String>("deviceAddress") ?: ""
                    wifiDirect.connect(address,
                        onSuccess = { result.success(true) },
                        onError = { err -> result.error("WIFI_CONNECT_ERROR", err, null) }
                    )
                }
                "startServer" -> {
                    val port = call.argument<Int>("port") ?: 8988
                    val destDir = call.argument<String>("destDirectory") ?: ""
                    val transferId = call.argument<String>("transferId") ?: ""
                    wifiDirect.startServer(port, destDir, transferId)
                    result.success(true)
                }
                "sendFile" -> {
                    val host = call.argument<String>("host") ?: ""
                    val port = call.argument<Int>("port") ?: 8988
                    val filePath = call.argument<String>("filePath") ?: ""
                    val transferId = call.argument<String>("transferId") ?: ""
                    wifiDirect.sendFile(host, port, filePath, transferId)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        bleAdvertiser.stopAdvertising()
        bleGattServer.stopServer()
        wifiDirect.destroy()
    }
}
