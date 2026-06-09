import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_tracker_service.dart';

class ProfileService extends ChangeNotifier {
  static final ProfileService instance = ProfileService._internal();
  ProfileService._internal();

  String _displayName = 'Driver';
  String _photoUrl = 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80';
  String _phone = '+60 12-345 6789';
  String _bio = 'Daily Commuter 🚗';

  double _walletBalance = 0.0;
  List<Map<String, dynamic>> _transactions = [];
  bool _isPro = false;
  DateTime? _subscriptionExpiry;
  bool _isTotpEnabled = false;

  String get displayName => _displayName;
  String get photoUrl => _photoUrl;
  String get phone => _phone;
  String get bio => _bio;
  String get email {
    try {
      return FirebaseAuth.instance.currentUser?.email ?? 'driver@drivecareplus.com';
    } catch (_) {
      return 'driver@drivecareplus.com';
    }
  }
  double get walletBalance => _walletBalance;
  List<Map<String, dynamic>> get transactions => _transactions;
  bool get isPro => _isPro;
  set isPro(bool value) {
    _isPro = value;
    notifyListeners();
  }
  bool get isTotpEnabled => _isTotpEnabled;
  set isTotpEnabled(bool value) {
    _isTotpEnabled = value;
    notifyListeners();
  }
  DateTime? get subscriptionExpiry => _subscriptionExpiry;

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
        
        // Fetch extended profile and wallet from Firestore
        ApiTracker.instance.trackCall('Cloud Firestore');
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          _walletBalance = (data['wallet_balance'] as num?)?.toDouble() ?? 0.0;
          _isPro = data['is_pro'] ?? false;
          _isTotpEnabled = data['totp_enabled'] ?? false;
          if (data['subscription_expiry'] != null) {
            _subscriptionExpiry = (data['subscription_expiry'] as Timestamp).toDate();
          }
          
          // Check for expiry
          if (_isPro && _subscriptionExpiry != null && DateTime.now().isAfter(_subscriptionExpiry!)) {
            _isPro = false;
            ApiTracker.instance.trackCall('Cloud Firestore');
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'is_pro': false});
          }
        }

        // Fetch transactions from sub-collection
        ApiTracker.instance.trackCall('Cloud Firestore');
        final txnsSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('wallet_transactions')
            .orderBy('date', descending: true)
            .limit(50)
            .get();
        
        _transactions = txnsSnap.docs.map((doc) => doc.data()).toList();
      }

      final prefs = await SharedPreferences.getInstance();
      _displayName = prefs.getString('user_display_name') ?? _displayName;
      _photoUrl = prefs.getString('user_photo_url') ?? _photoUrl;
      _phone = prefs.getString('user_phone') ?? _phone;
      _bio = prefs.getString('user_bio') ?? _bio;
      
      // Fallback to prefs if Firestore is unavailable or not logged in
      if (user == null) {
        _walletBalance = prefs.getDouble('wallet_balance') ?? 0.0;
        final txnsJsonList = prefs.getStringList('wallet_transactions');
        if (txnsJsonList != null) {
          _transactions = txnsJsonList.map((str) => Map<String, dynamic>.from(jsonDecode(str))).toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
    notifyListeners();
  }

  Future<void> addWalletTransaction(double amount, String type, String description, {String status = 'completed'}) async {
    if (status == 'completed') {
      _walletBalance += amount;
    }
    final transaction = {
      'amount': amount,
      'type': type, // 'top_up', 'deduction', 'subscription'
      'description': description,
      'status': status,
      'date': DateTime.now().toIso8601String(),
    };
    _transactions.insert(0, transaction);
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update Firestore
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        ApiTracker.instance.trackCall('Cloud Firestore');
        await userRef.set({
          'wallet_balance': _walletBalance,
        }, SetOptions(merge: true));
        
        ApiTracker.instance.trackCall('Cloud Firestore');
        await userRef.collection('wallet_transactions').add(transaction);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('wallet_balance', _walletBalance);
      final jsonList = _transactions.map((t) => jsonEncode(t)).toList();
      await prefs.setStringList('wallet_transactions', jsonList);
    } catch (e) {
      debugPrint('Error saving transaction: $e');
    }
  }

  Future<void> initializeProSubscription() async {
    _isPro = true;
    _subscriptionExpiry = DateTime.now().add(const Duration(days: 30));
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        ApiTracker.instance.trackCall('Cloud Firestore');
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'is_pro': true,
          'subscription_expiry': Timestamp.fromDate(_subscriptionExpiry!),
        }, SetOptions(merge: true));

        await addWalletTransaction(0, 'subscription', 'Pro Subscription Initialized');
      }
    } catch (e) {
      debugPrint('Error initializing subscription: $e');
    }
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

  Future<void> clearProfile() async {
    _displayName = 'Driver';
    _photoUrl = 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80';
    _phone = '+60 12-345 6789';
    _bio = 'Daily Commuter 🚗';
    _walletBalance = 0.0;
    _transactions = [];
    _isPro = false;
    _subscriptionExpiry = null;
    _isTotpEnabled = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_display_name');
      await prefs.remove('user_photo_url');
      await prefs.remove('user_phone');
      await prefs.remove('user_bio');
    } catch (e) {
      debugPrint('SharedPreferences clear error: $e');
    }
  }
}
