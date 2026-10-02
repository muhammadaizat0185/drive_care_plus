import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'api_tracker_service.dart';

class ToyyibPayService {
  // ToyyibPay Sandbox/Dev Server API URL
  static const String baseUrl = 'https://dev.toyyibpay.com/index.php/api';

  // ==========================================
  // TOYYIBPAY CONFIGURATION
  // ==========================================
  static String get secretKey {
    try {
      final value = FirebaseRemoteConfig.instance.getString('toyyibpay_secret_key');
      if (value.isNotEmpty) return value;
    } catch (_) {}
    // No secret is committed to source. The value must be supplied at runtime
    // via Firebase Remote Config (`toyyibpay_secret_key`); an empty string is
    // used as a safe placeholder so calls fail closed rather than leaking a key.
    return '';
  }

  static String get categoryCode {
    try {
      final value = FirebaseRemoteConfig.instance.getString('toyyibpay_category_code');
      if (value.isNotEmpty) return value;
    } catch (_) {}
    return 'cxtpjaz1'; // Fallback
  }

  static const String returnUrl = 'https://drivecareplus.com/payment-return';

  /// Creates a bill in ToyyibPay and returns the BillCode
  static Future<String?> createBill({
    required double amount,
    required String payerName,
    required String payerEmail,
    required String payerPhone,
  }) async {
    ApiTracker.instance.trackCall('ToyyibPay API');
    final url = Uri.parse('$baseUrl/createBill');
    
    // ToyyibPay standard API expects billAmount as decimal string (e.g. "50.00" for RM 50)
    final billAmountStr = amount.toStringAsFixed(2);
    
    // Fallback amount in cents (e.g. 5000 for RM 50)
    final priceInCents = (amount * 100).toInt().toString();

    // Standard phone formatting for Malaysian context (must be numeric digits only)
    String formattedPhone = payerPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (formattedPhone.isEmpty) {
      formattedPhone = '0123456789';
    }

    // Creating a robust body including both official ToyyibPay API parameters
    // and older/alternative parameter variations for absolute bulletproof compatibility.
    final requestBody = {
      'userSecretKey': secretKey,
      'categoryCode': categoryCode,
      'billName': 'DriveCare+ Wallet Top-up',
      'billDescription': 'Add RM $billAmountStr to DriveCare+ Wallet',
      'billPriceSetting': '0', // 0 = Fixed price bill
      'billPayorInfo': '1',    // 1 = Yes, payer info is supplied
      'billAmount': priceInCents, // ToyyibPay expects amount in cents (e.g. 5000 for RM 50)
      'billPrice': priceInCents,   // Cents format fallback (e.g., "5000")
      'billTo': payerName,         // Official parameter for name
      'billPayerName': payerName,  // Alternative parameter variation
      'billEmail': payerEmail,
      'billPhone': formattedPhone,
      'billReturnUrl': returnUrl,
      'billCallbackUrl': returnUrl,
    };

    debugPrint('--- TOYYIBPAY SENDING CREATE BILL REQUEST ---');
    debugPrint('URL: $url');
    debugPrint('Body Payload: $requestBody');

    try {
      final response = await http.post(url, body: requestBody);

      debugPrint('ToyyibPay Response Code: ${response.statusCode}');
      debugPrint('ToyyibPay Response Raw Body: ${response.body}');

      if (response.statusCode == 200) {
        // Parse response which can be JSON Array [ { "BillCode": "xxx" } ]
        final decoded = jsonDecode(response.body);
        
        if (decoded is List && decoded.isNotEmpty) {
          final billCode = decoded[0]['BillCode'];
          debugPrint('Successfully extracted BillCode (from List): $billCode');
          return billCode as String?;
        } else if (decoded is Map && decoded.containsKey('BillCode')) {
          final billCode = decoded['BillCode'];
          debugPrint('Successfully extracted BillCode (from Map): $billCode');
          return billCode as String?;
        } else {
          debugPrint('ToyyibPay Decoded JSON did not contain BillCode: $decoded');
        }
      }
    } catch (e) {
      debugPrint('ToyyibPay createBill API Exception: $e');
    }
    return null;
  }

  /// Creates a bill specifically for the Pro Subscription
  static Future<String?> createSubscriptionBill({
    required String payerName,
    required String payerEmail,
    required String payerPhone,
  }) async {
    ApiTracker.instance.trackCall('ToyyibPay API');
    final url = Uri.parse('$baseUrl/createBill');
    
    // Pro Subscription Price: RM 19.90 (Fixed for this project context)
    const subscriptionAmount = 19.90;
    final priceInCents = (subscriptionAmount * 100).toInt().toString();

    String formattedPhone = payerPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (formattedPhone.isEmpty) formattedPhone = '0123456789';

    final requestBody = {
      'userSecretKey': secretKey,
      'categoryCode': categoryCode,
      'billName': 'DriveCare+ Pro Subscription',
      'billDescription': 'Unlock premium AI analytics and background tracking',
      'billPriceSetting': '0',
      'billPayorInfo': '1',
      'billAmount': priceInCents,
      'billPrice': priceInCents,
      'billTo': payerName,
      'billEmail': payerEmail,
      'billPhone': formattedPhone,
      'billReturnUrl': returnUrl,
      'billCallbackUrl': returnUrl,
    };

    try {
      final response = await http.post(url, body: requestBody);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          return decoded[0]['BillCode'] as String?;
        }
      }
    } catch (e) {
      debugPrint('ToyyibPay createSubscriptionBill Exception: $e');
    }
    return null;
  }
}
