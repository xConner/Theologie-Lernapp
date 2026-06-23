import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError('This platform is not supported');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyDn7C_xH_VRrF2FUnGHLHMmPYiRdhU9Byo",
    authDomain: "bibelkunde-app.firebaseapp.com",
    projectId: "bibelkunde-app",
    storageBucket: "bibelkunde-app.firebasestorage.app",
    messagingSenderId: "675509931007",
    appId: "1:675509931007:web:21f7f288654e89866675ca",
    measurementId: "G-JYTKZCE3JT",
  );
}
