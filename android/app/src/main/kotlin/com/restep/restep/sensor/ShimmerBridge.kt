package com.restep.restep.sensor

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.util.Log
import com.shimmerresearch.android.manager.ShimmerBluetoothManagerAndroid
import com.shimmerresearch.bluetooth.ShimmerBluetooth
import com.shimmerresearch.driver.CallbackObject
import com.shimmerresearch.driver.FormatCluster
import com.shimmerresearch.driver.ObjectCluster
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class ShimmerBridge(context: Context, messenger: BinaryMessenger) {

    companion object {
        private const val TAG = "ShimmerBridge"
        const val METHOD_CHANNEL = "com.restep/shimmer"
        const val EVENT_CHANNEL = "com.restep/shimmer_stream"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var btManager: ShimmerBluetoothManagerAndroid? = null

    // Receives all messages from the Shimmer library on the main thread
    private val handler = object : Handler(Looper.getMainLooper()) {
        override fun handleMessage(msg: Message) {
            when (msg.what) {
                ShimmerBluetooth.MSG_IDENTIFIER_DATA_PACKET -> handleData(msg.obj)
                ShimmerBluetooth.MSG_IDENTIFIER_STATE_CHANGE -> handleState(msg.obj)
            }
        }
    }

    init {
        try {
            btManager = ShimmerBluetoothManagerAndroid(context, handler)
            Log.d(TAG, "Shimmer manager created")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create Shimmer manager", e)
        }

        // Commands from Flutter
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            val mac = call.argument<String>("mac")
            Log.d(TAG, "Call ${call.method} mac=$mac")
            try {
                when (call.method) {
                    "getPairedDevices" -> {
                        result.success(getPairedShimmers())
                        return@setMethodCallHandler
                    }
                    "connect" -> btManager?.connectShimmerThroughBTAddress(mac)
                    "startStreaming" -> btManager?.startStreaming(mac)
                    "stopStreaming" -> btManager?.stopStreaming(mac)
                    "disconnect" -> btManager?.disconnectShimmer(mac)
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Call ${call.method} failed", e)
                result.error("SHIMMER_ERROR", e.message, null)
            }
        }

        // Live data and state updates to Flutter
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    // Shimmer sensors already paired in the phone's Bluetooth settings
    @SuppressLint("MissingPermission")
    private fun getPairedShimmers(): List<Map<String, String>> {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return emptyList()
        return adapter.bondedDevices
            .filter {
                val name = it.name ?: ""
                name.contains("Shimmer", ignoreCase = true) || name.contains("RN42", ignoreCase = true)
            }
            .map { mapOf("mac" to it.address, "name" to (it.name ?: it.address)) }
    }

    private fun handleState(obj: Any?) {
        val state: Any?
        val mac: String?
        when (obj) {
            is ObjectCluster -> { state = obj.mState; mac = obj.macAddress }
            is CallbackObject -> { state = obj.mState; mac = obj.mBluetoothAddress }
            else -> return
        }
        Log.d(TAG, "State: $mac -> $state")
        eventSink?.success(mapOf("type" to "state", "mac" to mac, "state" to state.toString()))
    }

    private fun handleData(obj: Any?) {
        val oc = obj as? ObjectCluster ?: return

        // Returns the calibrated value of a sensor channel, or null if not enabled
        fun cal(name: String): Double? {
            val formats = oc.getCollectionOfFormatClusters(name) ?: return null
            if (formats.isEmpty()) return null
            return (ObjectCluster.returnFormatCluster(formats, "CAL") as? FormatCluster)?.mData
        }

        // Low-noise accelerometer first, wide-range as fallback (m/s^2)
        val ax = cal("Accel_LN_X") ?: cal("Accel_WR_X")
        val ay = cal("Accel_LN_Y") ?: cal("Accel_WR_Y")
        val az = cal("Accel_LN_Z") ?: cal("Accel_WR_Z")

        // Gyroscope (deg/s)
        val gx = cal("Gyro_X")
        val gy = cal("Gyro_Y")
        val gz = cal("Gyro_Z")

        val t = cal("Timestamp")

        // Battery level (%)
        val battery = cal("Batt_Percentage")

        eventSink?.success(
            mapOf(
                "type" to "data",
                "mac" to oc.macAddress,
                "t" to t,
                "ax" to ax, "ay" to ay, "az" to az,
                "gx" to gx, "gy" to gy, "gz" to gz,
                "battery" to battery
            )
        )
    }

    fun dispose() {
        try {
            btManager?.disconnectAllDevices()
        } catch (e: Exception) {
            Log.e(TAG, "Dispose failed", e)
        }
    }
}
