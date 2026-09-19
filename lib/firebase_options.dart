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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAFFfvzYOsGzIUA8-hq39FF2S1YjhXLS08',
    appId: '1:1077189994618:android:3d58a4b055db5b85dd73c3',
    messagingSenderId: '1077189994618',
    projectId: 'xommm-5370c',
    storageBucket: 'xommm-5370c.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAFFfvzYOsGzIUA8-hq39FF2S1YjhXLS08',
    appId: '1:1077189994618:web:3d58a4b055db5b85dd73c3',
    messagingSenderId: '1077189994618',
    projectId: 'xommm-5370c',
    storageBucket: 'xommm-5370c.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAFFfvzYOsGzIUA8-hq39FF2S1YjhXLS08',
    appId: '1:1077189994618:android:3d58a4b055db5b85dd73c3',
    messagingSenderId: '1077189994618',
    projectId: 'xommm-5370c',
    storageBucket: 'xommm-5370c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAFFfvzYOsGzIUA8-hq39FF2S1YjhXLS08',
    appId: '1:1077189994618:ios:3d58a4b055db5b85dd73c3',
    messagingSenderId: '1077189994618',
    projectId: 'xommm-5370c',
    storageBucket: 'xommm-5370c.firebasestorage.app',
  );
}
