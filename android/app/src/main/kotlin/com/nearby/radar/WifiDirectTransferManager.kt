package com.nearby.radar

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.NetworkInfo
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pInfo
import android.net.wifi.p2p.WifiP2pManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.Executors

class WifiDirectTransferManager(private val context: Context) {
    private val tag = "WifiDirectTransfer"

    interface TransferListener {
        fun onWifiP2pStateChanged(enabled: Boolean)
        fun onConnectionChanged(connected: Boolean, isGroupOwner: Boolean, groupOwnerAddress: String?)
        fun onTransferProgress(transferId: String, bytesTransferred: Long, totalBytes: Long, speedBps: Long)
        fun onTransferCompleted(transferId: String, filePath: String)
        fun onTransferFailed(transferId: String, error: String)
    }

    private var manager: WifiP2pManager? = null
    private var channel: WifiP2pManager.Channel? = null
    private var receiver: BroadcastReceiver? = null
    private var listener: TransferListener? = null
    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var serverSocket: ServerSocket? = null
    private var isServerRunning = false

    fun setListener(listener: TransferListener) {
        this.listener = listener
    }

    fun initialize(): Boolean {
        manager = context.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
        if (manager == null) return false

        channel = manager?.initialize(context, context.mainLooper, null)

        val intentFilter = IntentFilter().apply {
            addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION)
        }

        receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, intent: Intent?) {
                when (intent?.action) {
                    WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION -> {
                        val state = intent.getIntExtra(WifiP2pManager.EXTRA_WIFI_STATE, -1)
                        val enabled = state == WifiP2pManager.WIFI_P2P_STATE_ENABLED
                        mainHandler.post { listener?.onWifiP2pStateChanged(enabled) }
                    }
                    WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                        val networkInfo = intent.getParcelableExtra<NetworkInfo>(WifiP2pManager.EXTRA_NETWORK_INFO)
                        if (networkInfo?.isConnected == true) {
                            manager?.requestConnectionInfo(channel) { info: WifiP2pInfo? ->
                                if (info != null) {
                                    val isGroupOwner = info.isGroupOwner
                                    val hostAddress = info.groupOwnerAddress?.hostAddress
                                    mainHandler.post {
                                        listener?.onConnectionChanged(true, isGroupOwner, hostAddress)
                                    }
                                }
                            }
                        } else {
                            mainHandler.post {
                                listener?.onConnectionChanged(false, false, null)
                            }
                        }
                    }
                }
            }
        }

        context.registerReceiver(receiver, intentFilter)
        return true
    }

    fun createGroup(onSuccess: () -> Unit, onError: (String) -> Unit) {
        manager?.createGroup(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                Log.d(tag, "Wi-Fi Direct group created")
                onSuccess()
            }
            override fun onFailure(reason: Int) {
                onError("Failed to create group: reason $reason")
            }
        })
    }

    fun removeGroup() {
        manager?.removeGroup(channel, null)
    }

    fun connect(deviceAddress: String, onSuccess: () -> Unit, onError: (String) -> Unit) {
        val config = WifiP2pConfig().apply {
            this.deviceAddress = deviceAddress
        }
        manager?.connect(channel, config, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                onSuccess()
            }
            override fun onFailure(reason: Int) {
                onError("Wi-Fi Direct connect failed: reason $reason")
            }
        })
    }

    fun startServer(port: Int, destDirectory: String, transferId: String) {
        if (isServerRunning) return
        isServerRunning = true

        executor.execute {
            try {
                serverSocket = ServerSocket(port)
                Log.d(tag, "Wi-Fi Direct Server listening on port $port")
                val clientSocket = serverSocket?.accept() ?: return@execute

                val input: InputStream = clientSocket.getInputStream()
                val targetDir = File(destDirectory)
                if (!targetDir.exists()) targetDir.mkdirs()

                val outFile = File(targetDir, "received_$transferId.tmp")
                val output = FileOutputStream(outFile)

                val buffer = ByteArray(64 * 1024)
                var bytesRead: Int
                var totalBytesReceived: Long = 0
                var lastTime = System.currentTimeMillis()
                var bytesSinceLast = 0L

                while (input.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                    totalBytesReceived += bytesRead
                    bytesSinceLast += bytesRead

                    val now = System.currentTimeMillis()
                    if (now - lastTime >= 500) {
                        val speed = (bytesSinceLast * 1000) / (now - lastTime)
                        lastTime = now
                        bytesSinceLast = 0L
                        mainHandler.post {
                            listener?.onTransferProgress(transferId, totalBytesReceived, totalBytesReceived, speed)
                        }
                    }
                }

                output.flush()
                output.close()
                input.close()
                clientSocket.close()

                mainHandler.post {
                    listener?.onTransferCompleted(transferId, outFile.absolutePath)
                }
            } catch (e: Exception) {
                Log.e(tag, "Server transfer error: ${e.message}")
                mainHandler.post {
                    listener?.onTransferFailed(transferId, e.message ?: "Unknown error")
                }
            } finally {
                stopServer()
            }
        }
    }

    fun sendFile(host: String, port: Int, filePath: String, transferId: String) {
        executor.execute {
            try {
                val file = File(filePath)
                val totalBytes = file.length()
                val socket = Socket()
                socket.connect(InetSocketAddress(host, port), 10000)

                val output: OutputStream = socket.getOutputStream()
                val input = FileInputStream(file)

                val buffer = ByteArray(64 * 1024)
                var bytesRead: Int
                var totalBytesSent: Long = 0
                var lastTime = System.currentTimeMillis()
                var bytesSinceLast = 0L

                while (input.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                    totalBytesSent += bytesRead
                    bytesSinceLast += bytesRead

                    val now = System.currentTimeMillis()
                    if (now - lastTime >= 500) {
                        val speed = (bytesSinceLast * 1000) / (now - lastTime)
                        lastTime = now
                        bytesSinceLast = 0L
                        mainHandler.post {
                            listener?.onTransferProgress(transferId, totalBytesSent, totalBytes, speed)
                        }
                    }
                }

                output.flush()
                output.close()
                input.close()
                socket.close()

                mainHandler.post {
                    listener?.onTransferCompleted(transferId, filePath)
                }
            } catch (e: Exception) {
                Log.e(tag, "Client transfer error: ${e.message}")
                mainHandler.post {
                    listener?.onTransferFailed(transferId, e.message ?: "Send failed")
                }
            }
        }
    }

    fun stopServer() {
        isServerRunning = false
        try {
            serverSocket?.close()
            serverSocket = null
        } catch (e: Exception) {
            Log.e(tag, "Error closing server: ${e.message}")
        }
    }

    fun destroy() {
        stopServer()
        if (receiver != null) {
            try {
                context.unregisterReceiver(receiver)
            } catch (e: Exception) {}
            receiver = null
        }
    }
}
