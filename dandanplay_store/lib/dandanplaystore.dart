import 'dart:async';

import 'package:flutter/services.dart';

class MMKVStore {
  static const MethodChannel _channel =
      const MethodChannel('dandanplaystore');

  static Future<bool> setBool(String key, bool value) async {
    return _setValue("setBool", key, value);
  }

  static Future<bool> getBool(String key) async {

    final value = await _getValue<bool>("getBool", key);
    if (value is bool) {
      return value;
    }

    return false;
  }

  static Future<bool> setInt(String key, int value) async {
    return _setValue("setInt", key, value);
  }

  static Future<int> getInt(String key) async {
    final value = await _getValue<int>("getInt", key);
    if (value is int) {
      return value;
    }

    return 0;
  }

  static Future<bool> setDouble(String key, double value) async {
    return _setValue("setDouble", key, value);
  }

  static Future<double> getDouble(String key) async {
    final value = await _getValue<double>("getDouble", key);
    if (value is double) {
      return value;
    }

    return 0.0;
  }

  static Future<bool> setString(String key, String value) async {
    return _setValue("setString", key, value);
  }

  static Future<String> getString(String key) async {
    final value = await _getValue<String>("getString", key);
    if (value is String) {
      return value;
    }

    return "";
  }

  static Future<bool> contains(String key) async {
    final bool result = await _channel.invokeMethod("contains", {"key" : key});
    return result;
  }

  static Future<bool> _setValue<T>(String methodName, String key, T value) async {
    assert(key != null);
    final bool success = await _channel.invokeMethod(methodName, {"key" : key, "value" : value});
    return success;
  }

  static Future<T> _getValue<T>(String methodName, String key) async {
    assert(key != null);
    final T result = await _channel.invokeMethod(methodName, {"key" : key});
    return result;
  }
}
