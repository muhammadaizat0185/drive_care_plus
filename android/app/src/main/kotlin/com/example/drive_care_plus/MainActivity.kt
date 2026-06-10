package com.example.drive_care_plus

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.drivecare.plus/bluetooth"
    private var methodChannel: MethodChannel? = null
    
    // Store launch intent data
    private var autoStartTracking = false
    private var launchVehicleId: String? = null

    // Dynamic receiver for live events while app is running
    private val localReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val connected = intent.getBooleanExtra("connected", false)
            val vehicleId = intent.getStringExtra("vehicleId")
            val deviceName = intent.getStringExtra("deviceName")
            
            methodChannel?.invokeMethod(
                "onBluetoothVehicleEvent",
                mapOf(
                    "connected" to connected,
                    "vehicleId" to vehicleId,
                    "deviceName" to deviceName
                )
            )
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
        
        // If the app was already running, notify Dart directly of the trigger
        if (autoStartTracking && launchVehicleId != null) {
            methodChannel?.invokeMethod(
                "onBluetoothVehicleEvent",
                mapOf(
                    "connected" to true,
                    "vehicleId" to launchVehicleId,
                    "deviceName" to ""
                )
            )
            // Clear once read/delivered
            autoStartTracking = false
            launchVehicleId = null
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.getBooleanExtra("auto_start_tracking", false)) {
            autoStartTracking = true
            launchVehicleId = intent.getStringExtra("vehicle_id")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getConnectedDevices" -> {
                    result.success(getConnectedBluetoothDeviceNames())
                }
                "getBondedDevices" -> {
                    result.success(getBondedBluetoothDeviceNames())
                }
                "getStartIntentData" -> {
                    result.success(
                        mapOf(
                            "autoStartTracking" to autoStartTracking,
                            "vehicleId" to launchVehicleId
                        )
                    )
                    // Clear once read
                    autoStartTracking = false
                    launchVehicleId = null
                }
                "clearSecureFlags" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Register local receiver for bluetooth events
        val filter = IntentFilter("com.drivecare.plus.BLUETOOTH_EVENT")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(localReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(localReceiver, filter)
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(localReceiver)
        } catch (_: Exception) {}
        super.onDestroy()
    }

    // Returns names of currently-connected BT devices (A2DP + HFP profiles).
    private fun getConnectedBluetoothDeviceNames(): List<String> {
        return try {
            val bluetoothManager =
                getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            val adapter = bluetoothManager?.adapter ?: return emptyList()

            if (!adapter.isEnabled) return emptyList()

            val names = mutableSetOf<String>()

            // A2DP — audio streaming (music); HFP — hands-free phone (calls)
            val profiles = listOf(BluetoothProfile.A2DP, BluetoothProfile.HEADSET)
            for (profileId in profiles) {
                @Suppress("DEPRECATION")
                val devices = adapter.getProfileConnectionState(profileId)
                if (devices == BluetoothProfile.STATE_CONNECTED) {
                    // getConnectedDevices requires a proxy; use bonded devices
                    // filtered by connection state as a lightweight alternative.
                }
            }

            // Simpler: iterate bonded devices and check their connection state
            // using reflection-free API available on all SDK levels we support.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // On Android 12+ we need BLUETOOTH_CONNECT permission.
                val bondedDevices = adapter.bondedDevices ?: return emptyList()
                for (device in bondedDevices) {
                    try {
                        // isConnected is a hidden API — use reflection.
                        val isConnectedMethod =
                            device.javaClass.getMethod("isConnected")
                        val connected = isConnectedMethod.invoke(device) as? Boolean
                        if (connected == true) {
                            device.name?.let { names.add(it) }
                        }
                    } catch (_: Exception) {
                        // Reflection failed — add the device anyway so the
                        // user's car is not missed due to API restrictions.
                        device.name?.let { names.add(it) }
                    }
                }
            } else {
                @Suppress("DEPRECATION")
                val bondedDevices = adapter.bondedDevices ?: return emptyList()
                for (device in bondedDevices) {
                    try {
                        val isConnectedMethod =
                            device.javaClass.getMethod("isConnected")
                        val connected = isConnectedMethod.invoke(device) as? Boolean
                        if (connected == true) {
                            device.name?.let { names.add(it) }
                        }
                    } catch (_: Exception) {
                        device.name?.let { names.add(it) }
                    }
                }
            }

            names.toList()
        } catch (e: SecurityException) {
            emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    // Returns names of all bonded (paired) BT devices regardless of
    // connection state — used to populate the device picker in settings.
    private fun getBondedBluetoothDeviceNames(): List<String> {
        return try {
            val bluetoothManager =
                getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            val adapter = bluetoothManager?.adapter ?: return emptyList()
            if (!adapter.isEnabled) return emptyList()

            @Suppress("DEPRECATION")
            adapter.bondedDevices
                ?.mapNotNull { it.name }
                ?: emptyList()
        } catch (e: SecurityException) {
            emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }
}
