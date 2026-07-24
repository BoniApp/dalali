// ═══════════════════════════════════════════════════════════════
// FIREBASE OPTIONS (FCM)
// ═══════════════════════════════════════════════════════════════
//
// Manual configuration for Firebase Cloud Messaging, taken from the
// project's google-services.json (Android) and GoogleService-Info.plist
// (iOS, checked in at ios/Runner/). Passing these to
// Firebase.initializeApp means FCM needs NO google-services Gradle
// plugin and NO Xcode project edit. Values are client config (safe
// to ship); the FCM *service account* for sending stays in Supabase
// secrets only.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

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
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCojaQ6wfIhaAp5IsRZ98gVhE5GE8587tk',
    appId: '1:723762100065:android:5a605479aef44c03dc7720',
    messagingSenderId: '723762100065',
    projectId: 'dalali-83f65',
    databaseURL: 'https://dalali-83f65-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'dalali-83f65.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB0dHpLNP05EhhmzolrNh3Fd1f_iabIBWU',
    appId: '1:723762100065:ios:9629b28f482d5cbddc7720',
    messagingSenderId: '723762100065',
    projectId: 'dalali-83f65',
    databaseURL: 'https://dalali-83f65-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'dalali-83f65.firebasestorage.app',
    iosBundleId: 'dalali',
  );

  // FCM on web needs a VAPID key pair — not configured yet; values are
  // placeholders so the switch is total. Messaging is skipped on web
  // (FcmService guards with kIsWeb).
  static const FirebaseOptions web = android;
}
