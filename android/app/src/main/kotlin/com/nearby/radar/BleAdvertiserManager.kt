package com.nearby.radar

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import java.util.UUID

class BleAdvertiserManager(private val context: Context) {
    private val tag = "BleAdvertiserManager"

    companion object {
        val SERVICE_UUID: UUID = UUID.fromString("0000fee0-0000-1000-8000-00805f9b34fb")
    }

    private var advertiser: BluetoothLeAdvertiser? = null
    private var isAdvertising = false
    private var currentCallback: AdvertiseCallback? = null

    fun startAdvertising(
        userIdHash: ByteArray,
        statusFlag: Byte,
        onSuccess: () -> Unit,
        onError: (String) -> Unit
    ) {
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = bluetoothManager?.adapter

        if (adapter == null || !adapter.isEnabled) {
            onError("Bluetooth is not enabled")
            return
        }

        advertiser = adapter.bluetoothLeAdvertiser
        if (advertiser == null) {
            onError("BLE Advertising is not supported on this device")
            return
        }

        if (isAdvertising) {
            stopAdvertising()
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setConnectable(true)
            .setTimeout(0)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .build()

        // Payload: 4 bytes user hash + 1 byte status flag
        val serviceData = ByteArray(5)
        System.arraycopy(userIdHash, 0, serviceData, 0, minOf(userIdHash.size, 4))
        serviceData[4] = statusFlag

        val pUuid = ParcelUuid(SERVICE_UUID)
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .setIncludeTxPowerLevel(true)
            .addServiceUuid(pUuid)
            .addServiceData(pUuid, serviceData)
            .build()

        val callback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                super.onStartSuccess(settingsInEffect)
                isAdvertising = true
                Log.d(tag, "BLE Advertising started successfully")
                onSuccess()
            }

            override fun onStartFailure(errorCode: Int) {
                super.onStartFailure(errorCode)
                isAdvertising = false
                val msg = when (errorCode) {
                    ADVERTISE_FAILED_ALREADY_STARTED -> "Already started"
                    ADVERTISE_FAILED_DATA_TOO_LARGE -> "Data too large"
                    ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "Feature unsupported"
                    ADVERTISE_FAILED_INTERNAL_ERROR -> "Internal error"
                    ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "Too many advertisers"
                    else -> "Unknown error: $errorCode"
                }
                Log.e(tag, "BLE Advertising failed: $msg")
                onError(msg)
            }
        }

        currentCallback = callback
        try {
            advertiser?.startAdvertising(settings, data, callback)
        } catch (e: SecurityException) {
            onError("Missing Bluetooth advertise permission: ${e.message}")
        } catch (e: Exception) {
            onError("Failed to start advertising: ${e.message}")
        }
    }

    fun stopAdvertising() {
        if (isAdvertising && currentCallback != null) {
            try {
                advertiser?.stopAdvertising(currentCallback)
            } catch (e: Exception) {
                Log.e(tag, "Error stopping advertising: ${e.message}")
            }
            isAdvertising = false
            currentCallback = null
        }
    }

    fun isCurrentlyAdvertising(): Boolean = isAdvertising
}
