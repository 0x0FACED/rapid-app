import 'dart:io';
import 'package:flutter/services.dart';

class MulticastLock {
  static const platform = MethodChannel('com.rapid.app/multicast');

  static Future<void> acquire() async {
    if (!Platform.isAndroid) {
      print('[MulticastLock] Not Android, skipping');
      return;
    }

    try {
      await platform.invokeMethod('acquireMulticastLock');
      print('[MulticastLock] Acquired');
    } catch (e) {
      print('[MulticastLock] Failed to acquire: $e');
    }
  }

  static Future<void> release() async {
    if (!Platform.isAndroid) return;

    try {
      await platform.invokeMethod('releaseMulticastLock');
      print('[MulticastLock] Released');
    } catch (e) {
      print('[MulticastLock] Failed to release: $e');
    }
  }
}
