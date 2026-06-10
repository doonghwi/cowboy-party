// File generated for Cowboy Party (mirrors the FlutterFire CLI output shape).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for the Cowboy Party Firebase project.
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCIWUgdTI2IXecpEcppgD3h5fNnhY8_sko',
    appId: '1:162098390378:web:1f425e502f0ef268b27113',
    messagingSenderId: '162098390378',
    projectId: 'cowboy-party-doonghwi',
    authDomain: 'cowboy-party-doonghwi.firebaseapp.com',
    databaseURL:
        'https://cowboy-party-doonghwi-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'cowboy-party-doonghwi.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDObdDx6E4zeq8CO7yrw1i80A03eUa8OT4',
    appId: '1:162098390378:ios:b61dc2b6d9d4335db27113',
    messagingSenderId: '162098390378',
    projectId: 'cowboy-party-doonghwi',
    databaseURL:
        'https://cowboy-party-doonghwi-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'cowboy-party-doonghwi.firebasestorage.app',
    iosBundleId: 'com.doonghwi.cowboyParty',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBsoE4vi-bxVzMKp3Oy8gY6xafRhTx8qT0',
    appId: '1:162098390378:android:e7ef5e5807d05854b27113',
    messagingSenderId: '162098390378',
    projectId: 'cowboy-party-doonghwi',
    databaseURL:
        'https://cowboy-party-doonghwi-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'cowboy-party-doonghwi.firebasestorage.app',
  );
}
