import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class Dandanplaystore {
  static const MethodChannel _channel =
  const MethodChannel('dandanplaystore');

  static Future<bool> setBool(
      {@required String key, @required bool value, String id}) async {
    return _setValue(methodName: "setBool", key: key, value: value, id: id);
  }

  static Future<bool> getBool({@required String key, String id}) async {
    final value = await _getValue<bool>(
        methodName: "getBool", key: key, id: id);
    if (value is bool) {
      return value;
    }

    return false;
  }

  static Future<bool> setInt(
      {@required String key, @required int value, String id}) async {
    return _setValue(methodName: "setInt", key: key, value: value, id: id);
  }

  static Future<int> getInt({@required String key, String id}) async {
    final value = await _getValue<int>(methodName: "getInt", key: key, id: id);
    if (value is int) {
      return value;
    }

    return 0;
  }

  static Future<bool> setDouble(
      {@required String key, double value, String id}) async {
    return _setValue(methodName: "setDouble", key: key, value: value, id: id);
  }

  static Future<double> getDouble({@required String key, String id}) async {
    final value = await _getValue<double>(
        methodName: "getDouble", key: key, id: id);
    if (value is double) {
      return value;
    }

    return 0.0;
  }

  static Future<bool> setString(
      {@required String key, String value, String id}) async {
    return _setValue(methodName: "setString", key: key, value: value, id: id);
  }

  static Future<String> getString({@required String key, String id}) async {
    final value = await _getValue<String>(
        methodName: "getString", key: key, id: id);
    if (value is String) {
      return value;
    }

    return "";
  }

  static Future<bool> contains({@required String key, String id}) async {
    if (key == null) {
      assert(false, "key不能为空！");
      return null;
    }

    final map = Map<String, dynamic>();
    map["key"] = key;
    map["id"] = id;

    final bool result = await _channel.invokeMethod(
        "contains", map);
    return result;
  }

  static Future<bool> _setValue<T>(
      {@required String methodName, @required String key, @required T value, String id}) async {
    if (key == null) {
      assert(false, "key不能为空！");
      return null;
    }

    final map = Map<String, dynamic>();
    map["key"] = key;
    map["value"] = value;
    map["id"] = id;

    final bool success = await _channel.invokeMethod(methodName, map);
    return success;
  }

  static Future<T> _getValue<T>(
      {@required String methodName, @required String key, String id}) async {
    if (key == null) {
      assert(false, "key不能为空！");
      return null;
    }

    final map = Map<String, dynamic>();
    map["key"] = key;
    map["id"] = id;

    final T result = await _channel.invokeMethod(methodName, map);
    return result;
  }
}
