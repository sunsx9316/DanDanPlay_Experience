
import 'package:dandanplay/Model/Message/Send/DanmakuAlphaMessage.dart';
import 'package:dandanplay/Model/Message/Send/DanmakuCountMessage.dart';
import 'package:dandanplay/Model/Message/Send/DanmakuFontSizeMessage.dart';
import 'package:dandanplay/Model/Message/Send/DanmakuSpeedMessage.dart';
import 'package:dandanplay/Model/Message/Send/SubtitleSafeAreaMessage.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:dandanplaystore/dandanplaystore.dart';

class Preferences {
  static final shared = Preferences();
  //弹幕快速匹配
  final _fastMatchKey = "fastMatch";
  //字幕保护区域
  final _subtitleSafeAreaKey = "subtitleSafeArea";
  //弹幕过期时间
  final _danmakuCacheDayKey = "danmakuCacheDay";
  //弹幕字体大小
  final _danmakuFontSizeyKey = "danmakuFontSize";
  //弹幕速度
  final _danmakuSpeedKey = "danmakuSpeed";
  //弹幕透明度
  final _danmakuAlphaKey = "danmakuAlpha";
  //同屏幕弹幕数量
  final _danmakuCountKey = "danmakuCount";

  Future<int> get danmakuCount async {
    return MMKVStore.getInt(_danmakuCountKey);
  }

  Future<bool> setDanmakuCount(int value) async {
    final result = await MMKVStore.setInt(_danmakuCountKey, value);
    final msg = DanmakuCountMessage(value);
    await MessageChannel.shared.sendMessage(msg);
    return result;
  }

  Future<double> get danmakuAlpha async {
    return MMKVStore.getDouble(_danmakuAlphaKey);
  }

  Future<bool> setDanmakuAlpha(double value) async {
    final result = await MMKVStore.setDouble(_danmakuAlphaKey, value);
    final msg = DanmakuAlphaMessage(value);
    await MessageChannel.shared.sendMessage(msg);
    return result;
  }

  Future<double> get danmakuSpeed async {
    return MMKVStore.getDouble(_danmakuSpeedKey);
  }

  Future<bool> setDanmakuSpeed(double value) async {
    final result = await MMKVStore.setDouble(_danmakuSpeedKey, value);
    final msg = DanmakuSpeedMessage(value);
    await MessageChannel.shared.sendMessage(msg);
    return result;
  }

  Future<double> get danmakuFontSize async {
    return MMKVStore.getDouble(_danmakuFontSizeyKey);
  }

  Future<bool> setDanmakuFontSize(double value) async {
    final result = await MMKVStore.setDouble(_danmakuFontSizeyKey, value);
    final msg = DanmakuFontSizeMessage(value);
    await MessageChannel.shared.sendMessage(msg);
    return result;
  }

  Future<bool> get fastMatch async {
    return MMKVStore.getBool(_fastMatchKey);
  }

  Future<bool> setFastMatch(bool on) async {
    return MMKVStore.setBool(_fastMatchKey, on);
  }

  Future<bool> get subtitleSafeArea async {
    return MMKVStore.getBool(_subtitleSafeAreaKey);
  }

  Future<bool> setSubtitleSafeArea(bool on) async {
    final result = await MMKVStore.setBool(_subtitleSafeAreaKey, on);
    final msg = SubtitleSafeAreaMessage(on);
    await MessageChannel.shared.sendMessage(msg);
    return result;
  }

  Future<int> get danmakuCacheDay async {
    return MMKVStore.getInt(_danmakuCacheDayKey);
  }

  Future<bool> setDanmakuCacheDay(int value) async {
    return MMKVStore.setInt(_danmakuCacheDayKey, value);
  }

}