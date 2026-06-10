import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum ButtonSoundType {
  primary,      // General action buttons
  save,         // Save / confirm / submit
  toggle,       // Switches, checkboxes
  error,        // Validation failure, alert
  destructive,  // Delete / clear / cancel
  navigation,   // Tab bar navigation, back (silent by default)
}

class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  bool soundEnabled = true;

  // Dedicated players to prevent button sounds and notifications from clipping each other
  late final AudioPlayer _buttonPlayer;
  late final AudioPlayer _notificationPlayer;
  bool _initialized = false;

  // Central map: AssetSource assumes prefix 'assets/'.
  static const Map<ButtonSoundType, String> _buttonSoundAssets = {
    ButtonSoundType.primary: 'Audio/Button Pressed Sound.mp3',
    ButtonSoundType.save: 'Audio/Button Pressed Sound.mp3',
    ButtonSoundType.toggle: 'Audio/Button Pressed Sound.mp3',
    ButtonSoundType.error: 'Audio/Button Pressed Sound.mp3',
    ButtonSoundType.destructive: 'Audio/Button Pressed Sound.mp3',
    ButtonSoundType.navigation: '', // Empty means silent
  };

  static const String _notificationSoundAsset = 'Audio/Notification Sound.mp3';

  Future<void> init() async {
    if (_initialized) return;
    try {
      _buttonPlayer = AudioPlayer();
      _notificationPlayer = AudioPlayer();
      
      // Pre-cache/load the default sources to optimize latency
      await _buttonPlayer.setSource(AssetSource(_buttonSoundAssets[ButtonSoundType.primary]!));
      await _notificationPlayer.setSource(AssetSource(_notificationSoundAsset));
      
      _initialized = true;
      debugPrint('AudioService: initialized');
    } catch (e) {
      debugPrint('AudioService initialization error: $e');
    }
  }

  /// Plays sound for a specific button type
  Future<void> button(ButtonSoundType type) async {
    if (!soundEnabled || !_initialized) return;
    final path = _buttonSoundAssets[type];
    if (path == null || path.isEmpty) return;

    try {
      // Re-trigger sound immediately if clicked quickly
      await _buttonPlayer.stop();
      await _buttonPlayer.play(AssetSource(path));
    } catch (e) {
      debugPrint('AudioService.button play error ($type): $e');
    }
  }

  /// Plays the notification sound (for in-app alerts)
  Future<void> notification() async {
    if (!soundEnabled || !_initialized) return;
    try {
      await _notificationPlayer.stop();
      await _notificationPlayer.play(AssetSource(_notificationSoundAsset));
    } catch (e) {
      debugPrint('AudioService.notification play error: $e');
    }
  }
}
