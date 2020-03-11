import 'dart:async';

import 'package:flutter/services.dart';

class DandanplayNative {
  static const MethodChannel _channel =
      const MethodChannel('dandanplay_native');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
