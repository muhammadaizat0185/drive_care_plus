package com.example.drive_care_plus

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import android.util.Log

class BluetoothReceiver : BroadcastReceiver() {
    private val TAG = "BluetoothReceiver"
    private val CHANNEL_ID = "drive_care_plus_auto_start"
    private val NOTIFICATION_ID = 1002

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != BluetoothDevice.ACTION_ACL_CONNECTED && action != BluetoothDevice.ACTION_ACL_DISCONNECTED) {
            return
        }

        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE) ?: return
        val deviceName = try {
            device.name
        } catch (e: SecurityException) {
            Log.w(TAG, "Missing BLUETOOTH_CONNECT permission for device name: ${e.message}")
            null
        }

        if (deviceName == null || deviceName.isEmpty()) {
            Log.d(TAG, "Device name is empty, ignoring.")
            return
        }

        Log.d(TAG, "Bluetooth event: $action device=$deviceName")

        // 1. Read SharedPreferences to find a matching registered car device
        val sharedPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val allPrefs = sharedPrefs.all
        var matchedVehicleId: String? = null

        for ((key, value) in allPrefs) {
            if (key.startsWith("flutter.bt_car_device_")) {
                val registeredName = value as? String
                if (registeredName != null && registeredName.isNotEmpty() &&
                    deviceName.equals(registeredName, ignoreCase = true)) {
                    matchedVehicleId = key.removePrefix("flutter.bt_car_device_")
                    break
                }
            }
        }

        if (matchedVehicleId == null) {
            Log.d(TAG, "No matching registered Bluetooth vehicle device found for: $deviceName")
            return
        }

        Log.d(TAG, "Found matched vehicle: $matchedVehicleId for device: $deviceName")

        // 2. Send local broadcast for running/background app instance
        val isConnected = action == BluetoothDevice.ACTION_ACL_CONNECTED
        val localIntent = Intent("com.drivecare.plus.BLUETOOTH_EVENT").apply {
            putExtra("connected", isConnected)
            putExtra("vehicleId", matchedVehicleId)
            putExtra("deviceName", deviceName)
            setPackage(context.packageName)
        }

        context.sendBroadcast(localIntent)

        // If it is a connection event, show a notification to let the user open the app if closed.
        if (isConnected) {
            showNotification(context, deviceName, matchedVehicleId)
        }
    }

    private fun showNotification(context: Context, deviceName: String, vehicleId: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Auto-Start Trips",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifies when your car's Bluetooth connects to start tracking your trip."
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Intent to launch MainActivity and trigger tracking
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("auto_start_tracking", true)
            putExtra("vehicle_id", vehicleId)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            1003,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("DriveCare+ Auto-Start")
            .setContentText("Connected to $deviceName. Tap to start recording your trip.")
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
