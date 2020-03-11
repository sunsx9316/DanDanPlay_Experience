

//import 'package:shared_preferences/shared_preferences.dart';

import 'package:dandanplaystore/dandanplaystore.dart';

class Preferences {
  static final shared = Preferences();
  //弹幕快速匹配
  final _fastMatchKey = "fastMatch";
  //字幕保护区域
  final _subtitleSafeAreaKey = "subtitleSafeArea";
  //弹幕过期时间
  final _danmakuCacheDayKey = "danmakuCacheDay";


  Future<bool> get fastMatch async {
    final contains = await MMKVStore.contains(_fastMatchKey);
    if (!contains) {
      this.setFastMatch(true);
      return true;
    }
    final v =  MMKVStore.getBool(_fastMatchKey);
    return v;
  }

  Future<bool> setFastMatch(bool on) async {
    return MMKVStore.setBool(_fastMatchKey, on);
  }

  Future<bool> get subtitleSafeArea async {
    final contains = await MMKVStore.contains(_subtitleSafeAreaKey);
    if (!contains) {
      this.setSubtitleSafeArea(true);
      return true;
    }
    return MMKVStore.getBool(_subtitleSafeAreaKey);
  }

  Future<bool> setSubtitleSafeArea(bool on) async {
    return MMKVStore.setBool(_subtitleSafeAreaKey, on);
  }

  Future<int> get danmakuCacheDay async {
    final contains = await MMKVStore.contains(_danmakuCacheDayKey);
    if (!contains) {
      this.setDanmakuCacheDay(7);
      return 7;
    }
    return MMKVStore.getInt(_danmakuCacheDayKey);
  }

  Future<bool> setDanmakuCacheDay(int value) async {
    return MMKVStore.setInt(_danmakuCacheDayKey, value);
  }

}