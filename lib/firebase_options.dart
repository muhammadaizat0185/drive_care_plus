import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'DUMMY_API_KEY',
    appId: '1:000000000000:web:drivecareplusdummy',
    messagingSenderId: '000000000000',
    projectId: 'drivecareplus-dummy',
    authDomain: 'drivecareplus-dummy.firebaseapp.com',
    storageBucket: 'drivecareplus-dummy.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAQSuYzTUOE8jEYc6TEblgWYJbUbI89s7Y',
    appId: '1:637711215349:android:d7ddde83b37d2b6c51f3bc',
    messagingSenderId: '637711215349',
    projectId: 'drivecareplus',
    storageBucket: 'drivecareplus.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA_clKszUCaXGHBzQNLa3KlFuCRHUfD1Bg',
    appId: '1:637711215349:ios:f9e7d1b258f06fa451f3bc',
    messagingSenderId: '637711215349',
    projectId: 'drivecareplus',
    storageBucket: 'drivecareplus.firebasestorage.app',
    iosBundleId: 'com.example.driveCarePlus',
  );

}