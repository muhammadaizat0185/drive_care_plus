// Phase 4 — Bluetooth Vehicle Service.
//
// Uses a MethodChannel to query the Android BluetoothAdapter for currently
// connected A2DP / HFP profiles — exactly what a car audio head unit uses.
// No extra pub package is needed; the native side is wired in
// android/app/src/main/kotlin/.../MainActivity.kt.
//
// Key design decisions:
//   • Only reads *already-paired* Bluetooth devices — never scans/discovers,
//     so no BLUETOOTH_SCAN permission is required on Android 12+.
//   • Stores one "car audio device name" per vehicle in SharedPreferences
//     under the key 'bt_car_device_<vehicleId>'.
//   • [isCarBluetoothConnected(vehicleId)] checks whether the stored device
//     name appears in the list of currently-connected BT devices.
//   • Called by [ActivityRecognitionService] as a pre-check before starting
//     a new PENDING_CONFIRMATION journey, so that the attribution source can
//     be set to 'bluetooth_auto' and the status set to 'confirmed' without
//     user interaction.
//
// Android permissions required (already declared in AndroidManifest.xml for
// most apps using flutter_activity_recognition):
//   <uses-permission android:name="android.permission.BLUETOOTH" />
//   <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"
//       android:maxSdkVersion="30" />

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothVehicleService {
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get bluetoothEventStream => _eventController.stream;

  BluetoothVehicleService._() {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  Future<void> _methodCallHandler(MethodCall call) async {
    if (call.method == 'onBluetoothVehicleEvent') {
      final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
      if (args != null) {
        final Map<String, dynamic> event = args.map((key, value) => MapEntry(key.toString(), value));
        _eventController.add(event);
        debugPrint('BluetoothVehicleService: onBluetoothVehicleEvent received: $event');
      }
    }
  }

  static final BluetoothVehicleService instance = BluetoothVehicleService._();

  static const MethodChannel _channel =
      MethodChannel('com.drivecare.plus/bluetooth');

  static const String _prefPrefix = 'bt_car_device_';

  /// Retrieves the launch intent data if the app was started via the auto-start notification.
  Future<Map<String, dynamic>?> getStartIntentData() async {
    try {
      final Map<dynamic, dynamic>? data =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getStartIntentData');
      if (data == null) return null;
      return data.map((key, value) => MapEntry(key.toString(), value));
    } catch (e) {
      debugPrint('BluetoothVehicleService.getStartIntentData error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Preference helpers
  // ---------------------------------------------------------------------------

  /// Stores [deviceName] as the known car audio BT device for [vehicleId].
  /// Pass null to clear the stored device.
  Future<void> setCarBluetoothDevice({
    required String vehicleId,
    required String? deviceName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefPrefix$vehicleId';
    if (deviceName == null || deviceName.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, deviceName);
    }
    debugPrint(
        'BluetoothVehicleService: paired device for vehicle $vehicleId → $deviceName');
  }

  /// Returns the stored car audio BT device name for [vehicleId], or null.
  Future<String?> getCarBluetoothDevice(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefPrefix$vehicleId');
  }

  // ---------------------------------------------------------------------------
  // Connected device check
  // ---------------------------------------------------------------------------

  /// Returns true if the car's paired BT device is currently connected.
  ///
  /// [vehicleId] — looked up in SharedPreferences to find the stored device name.
  ///
  /// Returns false if:
  ///   - No device is paired for this vehicle.
  ///   - Bluetooth is off.
  ///   - The MethodChannel call fails (graceful degradation).
  Future<bool> isCarBluetoothConnected(String vehicleId) async {
    final String? pairedName = await getCarBluetoothDevice(vehicleId);
    if (pairedName == null || pairedName.isEmpty) return false;

    final List<String> connected = await getConnectedDeviceNames();
    final bool found = connected.any(
      (name) => name.toLowerCase().contains(pairedName.toLowerCase()),
    );

    debugPrint(
        'BluetoothVehicleService: isConnected($vehicleId) pairedName=$pairedName '
        'connected=$connected → $found');
    return found;
  }

  /// Returns the names of all currently-connected Bluetooth devices by
  /// querying the platform via MethodChannel.
  ///
  /// On error (BT off, permission denied, etc.) returns an empty list.
  Future<List<String>> getConnectedDeviceNames() async {
    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>('getConnectedDevices');
      if (result == null) return [];
      return result.map((e) => e.toString()).toList();
    } on PlatformException catch (e) {
      debugPrint('BluetoothVehicleService.getConnectedDeviceNames: $e');
      return [];
    } catch (e) {
      debugPrint('BluetoothVehicleService.getConnectedDeviceNames: $e');
      return [];
    }
  }

  /// Returns names of all *bonded* (paired) BT devices, whether connected
  /// or not. Used to populate the device picker in the vehicle setup screen.
  Future<List<String>> getBondedDeviceNames() async {
    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>('getBondedDevices');
      if (result == null) return [];
      return result.map((e) => e.toString()).toList();
    } on PlatformException catch (e) {
      debugPrint('BluetoothVehicleService.getBondedDeviceNames: $e');
      return [];
    } catch (e) {
      debugPrint('BluetoothVehicleService.getBondedDeviceNames: $e');
      return [];
    }
  }
}
