import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService extends ChangeNotifier {
  static final ProfileService instance = ProfileService._internal();
  ProfileService._internal();

  String _displayName = 'Driver';
  String _photoUrl = 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80';
  String _phone = '+60 12-345 6789';
  String _bio = 'Daily Commuter 🚗';

  String get displayName => _displayName;
  String get photoUrl => _photoUrl;
  String get phone => _phone;
  String get bio => _bio;

  static const List<String> presetAvatars = [
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80', // Default Casual
    'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=150&q=80', // Active Racer
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80', // Eco Driver
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80', // Offroad Explorer
    'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=150&q=80', // Tech Cruiser
    'https://images.unsplash.com/photo-1628157582853-a796fa650a6a?auto=format&fit=crop&w=150&q=80', // Retro Pilot
  ];

  Future<void> init() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _displayName = user.displayName ?? 'Driver';
        _photoUrl = user.photoURL ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80';
      }

      final prefs = await SharedPreferences.getInstance();
      _displayName = prefs.getString('user_display_name') ?? _displayName;
      _photoUrl = prefs.getString('user_photo_url') ?? _photoUrl;
      _phone = prefs.getString('user_phone') ?? _phone;
      _bio = prefs.getString('user_bio') ?? _bio;
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String avatarUrl,
    required String phoneNo,
    required String userBio,
  }) async {
    _displayName = name;
    _photoUrl = avatarUrl;
    _phone = phoneNo;
    _bio = userBio;
    notifyListeners();

    // Persist to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_display_name', name);
      await prefs.setString('user_photo_url', avatarUrl);
      await prefs.setString('user_phone', phoneNo);
      await prefs.setString('user_bio', userBio);
    } catch (e) {
      debugPrint('SharedPreferences save error: $e');
    }

    // Persist to Firebase Auth if logged in
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(name);
        await user.updatePhotoURL(avatarUrl);
      }
    } catch (e) {
      debugPrint('Firebase profile sync error: $e');
    }
  }
}
