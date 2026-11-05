package com.nearby.radar

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.UUID

class BleGattServerManager(private val context: Context) {
    private val tag = "BleGattServerManager"

    companion object {
        val SERVICE_UUID: UUID = UUID.fromString("0000fee0-0000-1000-8000-00805f9b34fb")
        val PROFILE_CHAR_UUID: UUID = UUID.fromString("0000fee1-0000-1000-8000-00805f9b34fb")
        val CONN_REQUEST_CHAR_UUID: UUID = UUID.fromString("0000fee2-0000-1000-8000-00805f9b34fb")
        val MESSAGE_CHAR_UUID: UUID = UUID.fromString("0000fee3-0000-1000-8000-00805f9b34fb")
        val TRANSFER_CHAR_UUID: UUID = UUID.fromString("0000fee4-0000-1000-8000-00805f9b34fb")
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    interface GattServerListener {
        fun onProfileReadRequested(deviceAddress: String, offset: Int): ByteArray?
        fun onConnectionRequestReceived(deviceAddress: String, payload: ByteArray)
        fun onMessageChunkReceived(deviceAddress: String, payload: ByteArray)
        fun onTransferNegotiationReceived(deviceAddress: String, payload: ByteArray)
        fun onDeviceConnected(deviceAddress: String)
        fun onDeviceDisconnected(deviceAddress: String)
    }

    private var gattServer: BluetoothGattServer? = null
    private var listener: GattServerListener? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val connectedDevices = mutableSetOf<BluetoothDevice>()

    fun setListener(listener: GattServerListener) {
        this.listener = listener
    }

    fun startServer(onSuccess: () -> Unit, onError: (String) -> Unit) {
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        if (bluetoothManager == null) {
            onError("BluetoothManager not available")
            return
        }

        val gattCallback = object : BluetoothGattServerCallback() {
            override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
                super.onConnectionStateChange(device, status, newState)
                mainHandler.post {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        Log.d(tag, "Central connected: ${device.address}")
                        connectedDevices.add(device)
                        listener?.onDeviceConnected(device.address)
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        Log.d(tag, "Central disconnected: ${device.address}")
                        connectedDevices.remove(device)
                        listener?.onDeviceDisconnected(device.address)
                    }
                }
            }

            override fun onCharacteristicReadRequest(
                device: BluetoothDevice,
                requestId: Int,
                offset: Int,
                characteristic: BluetoothGattCharacteristic
            ) {
                super.onCharacteristicReadRequest(device, requestId, offset, characteristic)
                if (characteristic.uuid == PROFILE_CHAR_UUID) {
                    val profileData = listener?.onProfileReadRequested(device.address, offset) ?: ByteArray(0)
                    val slice = if (offset < profileData.size) {
                        profileData.copyOfRange(offset, profileData.size)
                    } else {
                        ByteArray(0)
                    }
                    try {
                        gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, slice)
                    } catch (e: Exception) {
                        Log.e(tag, "Error sending profile read response: ${e.message}")
                    }
                } else {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, characteristic.value)
                }
            }

            override fun onCharacteristicWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                characteristic: BluetoothGattCharacteristic,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray
            ) {
                super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value)
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                }

                mainHandler.post {
                    when (characteristic.uuid) {
                        CONN_REQUEST_CHAR_UUID -> listener?.onConnectionRequestReceived(device.address, value)
                        MESSAGE_CHAR_UUID -> listener?.onMessageChunkReceived(device.address, value)
                        TRANSFER_CHAR_UUID -> listener?.onTransferNegotiationReceived(device.address, value)
                    }
                }
            }

            override fun onDescriptorWriteRequest(
                device: BluetoothDevice,
                requestId: Int,
                descriptor: BluetoothGattDescriptor,
                preparedWrite: Boolean,
                responseNeeded: Boolean,
                offset: Int,
                value: ByteArray
            ) {
                super.onDescriptorWriteRequest(device, requestId, descriptor, preparedWrite, responseNeeded, offset, value)
                if (responseNeeded) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
                }
                Log.d(tag, "Descriptor write for: ${descriptor.uuid}")
            }

            override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {
                super.onMtuChanged(device, mtu)
                Log.d(tag, "MTU changed for ${device.address}: $mtu")
            }
        }

        try {
            gattServer = bluetoothManager.openGattServer(context, gattCallback)
            if (gattServer == null) {
                onError("Failed to open GATT Server")
                return
            }

            val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

            // Profile Characteristic (Read & Write)
            val profileChar = BluetoothGattCharacteristic(
                PROFILE_CHAR_UUID,
                BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_WRITE,
                BluetoothGattCharacteristic.PERMISSION_READ or BluetoothGattCharacteristic.PERMISSION_WRITE
            )

            // Connection Request Characteristic (Write & Notify)
            val connChar = BluetoothGattCharacteristic(
                CONN_REQUEST_CHAR_UUID,
                BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                BluetoothGattCharacteristic.PERMISSION_WRITE or BluetoothGattCharacteristic.PERMISSION_READ
            )
            connChar.addDescriptor(BluetoothGattDescriptor(CCCD_UUID, BluetoothGattDescriptor.PERMISSION_WRITE or BluetoothGattDescriptor.PERMISSION_READ))

            // Message Characteristic (Write Without Response, Write & Notify)
            val msgChar = BluetoothGattCharacteristic(
                MESSAGE_CHAR_UUID,
                BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                BluetoothGattCharacteristic.PERMISSION_WRITE or BluetoothGattCharacteristic.PERMISSION_READ
            )
            msgChar.addDescriptor(BluetoothGattDescriptor(CCCD_UUID, BluetoothGattDescriptor.PERMISSION_WRITE or BluetoothGattDescriptor.PERMISSION_READ))

            // Transfer Negotiation Characteristic (Write & Notify)
            val transferChar = BluetoothGattCharacteristic(
                TRANSFER_CHAR_UUID,
                BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                BluetoothGattCharacteristic.PERMISSION_WRITE or BluetoothGattCharacteristic.PERMISSION_READ
            )
            transferChar.addDescriptor(BluetoothGattDescriptor(CCCD_UUID, BluetoothGattDescriptor.PERMISSION_WRITE or BluetoothGattDescriptor.PERMISSION_READ))

            service.addCharacteristic(profileChar)
            service.addCharacteristic(connChar)
            service.addCharacteristic(msgChar)
            service.addCharacteristic(transferChar)

            gattServer?.addService(service)
            Log.d(tag, "GATT Server started and service registered")
            onSuccess()
        } catch (e: Exception) {
            onError("Error starting GATT Server: ${e.message}")
        }
    }

    fun notifyCharacteristic(deviceAddress: String, characteristicUuid: UUID, payload: ByteArray) {
        val device = connectedDevices.find { it.address.equals(deviceAddress, ignoreCase = true) }
        if (device == null || gattServer == null) return

        val service = gattServer?.getService(SERVICE_UUID)
        val char = service?.getCharacteristic(characteristicUuid)
        if (char != null) {
            char.value = payload
            try {
                gattServer?.notifyCharacteristicChanged(device, char, false)
            } catch (e: Exception) {
                Log.e(tag, "Error notifying characteristic: ${e.message}")
            }
        }
    }

    fun stopServer() {
        try {
            gattServer?.clearServices()
            gattServer?.close()
            gattServer = null
            connectedDevices.clear()
        } catch (e: Exception) {
            Log.e(tag, "Error stopping GATT Server: ${e.message}")
        }
    }
}
