import 'dart:convert';
import 'dart:io';

import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/Login/User.dart';
import 'package:dandanplay/Model/Message/Send/SyncSettingMessage.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:dandanplaystore/dandanplaystore.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

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

  //首页背景图
  final _homePageBgImageKey = "homePageBgImage";

  //显示主屏幕tips
  final _showHomePageTipsKey = "showHomePageTips";

  //播放速度
  final _playerSpeedKey = "playerSpeed";

  //播放模式
  final _playerModeKey = "playerMode";

  //是否自动检查更新
  final _checkUpdateKey = "checkUpdate";

  //登录的用户
  final _userKey = "userKey";

  Future<void> setupDefaultValue({bool force = false}) async {
    var isContains = await MMKVStore.contains(key: _fastMatchKey);
    if (!isContains || force) {
      await MMKVStore.setBool(key: _fastMatchKey, value: true);
    }

    isContains = await MMKVStore.contains(key: _subtitleSafeAreaKey);
    if (!isContains || force) {
      await MMKVStore.setBool(key: _subtitleSafeAreaKey, value: true);
    }

    isContains = await MMKVStore.contains(key: _danmakuCacheDayKey);
    if (!isContains || force) {
      await MMKVStore.setInt(key: _danmakuCacheDayKey, value: 7);
    }

    isContains = await MMKVStore.contains(key: _danmakuFontSizeyKey);
    if (!isContains || force) {
      await MMKVStore.setDouble(key: _danmakuFontSizeyKey, value: 20);
    }

    isContains = await MMKVStore.contains(key: _danmakuSpeedKey);
    if (!isContains || force) {
      await MMKVStore.setDouble(key: _danmakuSpeedKey, value: 1);
    }

    isContains = await MMKVStore.contains(key: _danmakuAlphaKey);
    if (!isContains || force) {
      await MMKVStore.setDouble(key: _danmakuAlphaKey, value: 1);
    }

    isContains = await MMKVStore.contains(key: _danmakuCountKey);
    if (!isContains || force) {
      await MMKVStore.setInt(key: _danmakuCountKey, value: 100);
    }

    isContains = await MMKVStore.contains(key: _showHomePageTipsKey);
    if (!isContains || force) {
      await MMKVStore.setBool(key: _showHomePageTipsKey, value: true);
    }

    isContains = await MMKVStore.contains(key: _playerSpeedKey);
    if (!isContains || force) {
      await MMKVStore.setDouble(key: _playerSpeedKey, value: 1);
    }

    isContains = await MMKVStore.contains(key: _playerModeKey);
    if (!isContains || force) {
      await MMKVStore.setInt(
          key: _playerModeKey,
          value: playerModeRawValueWithEnum(PlayerMode.notRepeat));
    }

    isContains = await MMKVStore.contains(key: _checkUpdateKey);
    if (!isContains || force) {
      await MMKVStore.setBool(key: _checkUpdateKey, value: true);
    }
  }

  Future<User> get user async {
    final value = await MMKVStore.getString(key: _userKey);

    try {
      final map = json.decode(value);
      if (map is Map) {
        return User.fromJsonMap(map);
      }
    } catch (e) {}

    return null;
  }

  Future<bool> setUser(User value) async {
    var result = false;
    if (value != null) {
      final jsonValue = value.toJson();
      final str = json.encode(jsonValue);
      result = await MMKVStore.setString(key: _userKey, value: str);
    } else {
      result = await MMKVStore.setString(key: _userKey, value: null);
    }
    return result;
  }

  Future<bool> get checkUpdate async {
    final value = await MMKVStore.getBool(key: _checkUpdateKey);
    return value;
  }

  Future<bool> setCheckUpdate(bool value) async {
    final result = await MMKVStore.setBool(key: _checkUpdateKey, value: value);
    final msg = SyncSettingMessage(key: _checkUpdateKey, value: value);
    await MessageChannel.shared.sendMessage(msg);
    return result;
  }

  Future<PlayerMode> get playerMode async {
    final value = await MMKVStore.getInt(key: _playerModeKey);
    return playerModeTypeWithRawValue(value);
  }

  Future<bool> setPlayerMode(PlayerMode value) async {
    final rawValue = playerModeRawValueWithEnum(value);
    final result = await MMKVStore.setInt(key: _playerModeKey, value: rawValue);
    final msg = SyncSettingMessage(key: _playerModeKey, value: rawValue);
    await MessageChannel.shared.sendMessage(msg);
    return result;
  }

  Future<double> get playerSpeed async {
    return MMKVStore.getDouble(key: _playerSpeedKey);
  }

  Future<bool> setPlayerSpeed(double value) async {
    final result =
        await MMKVStore.setDouble(key: _playerSpeedKey, value: value);
    final msg = SyncSettingMessage(key: _playerSpeedKey, value: value);
    await MessageChannel.shared.sendMessage(msg);
    return result;
  }

  Future<bool> get showHomePageTips async {
    return MMKVStore.getBool(key: _showHomePageTipsKey);
  }

  Future<bool> setShowHomePageTips(bool isShow) async {
    final result =
        await MMKVStore.setBool(key: _showHomePageTipsKey, value: isShow);
    return result;
  }

  Future<String> get homePageBgImage async {
    final name = await MMKVStore.getString(key: _homePageBgImageKey);
    final directory = await getApplicationDocumentsDirectory();
    return "${directory.path}/$name";
  }

  Future<bool> setHomePageBgImage(String path) async {
    if (path != null) {
      File file = File(path);
      final directory = await getApplicationDocumentsDirectory();
      final newFileName = "homePageImg${extension(path)}";
      final newPath = "${directory.path}/$newFileName";
      await file.copy(newPath);
      final result = await MMKVStore.setString(
          key: _homePageBgImageKey, value: newFileName);
      return result;
    } else {
      final result =
          await MMKVStore.setString(key: _homePageBgImageKey, value: null);
      return result;
    }
  }

  Future<int> get danmakuCount async {
    return MMKVStore.getInt(key: _danmakuCountKey);
  }

  Future<bool> setDanmakuCount(int value) async {
    final result = await MMKVStore.setInt(key: _danmakuCountKey, value: value);
    final msg = SyncSettingMessage(key: _danmakuCountKey, value: value);
    await MessageChannel.shared.sendMessage(msg);
    return result;
  }

  Future<double> get danmakuAlpha async {
    return MMKVStore.getDouble(key: _danmakuAlphaKey);
  }

  Future<bool> setDanmakuAlpha(double value) async {
    final result =
        await MMKVStore.setDouble(key: _danmakuAlphaKey, value: value);
    final msg = SyncSettingMessage(key: _danmakuAlphaKey, value: value);
    await MessageChannel.shared.sendMessage(msg);
    return result;
  }

  Future<double> get danmakuSpeed async {
    return MMKVStore.getDouble(key: _danmakuSpeedKey);
  }

  Future<bool> setDanmakuSpeed(double value) async {
    final result =
        await MMKVStore.setDouble(key: _danmakuSpeedKey, value: value);
    final msg = SyncSettingMessage(key: _danmakuSpeedKey, value: value);
    await MessageChannel.shared.sendMessage(msg);
    return result;
  }

  Future<double> get danmakuFontSize async {
    return MMKVStore.getDouble(key: _danmakuFontSizeyKey);
  }

  Future<bool> setDanmakuFontSize(double value) async {
    final result =
        await MMKVStore.setDouble(key: _danmakuFontSizeyKey, value: value);
    final msg = SyncSettingMessage(key: _danmakuFontSizeyKey, value: value);
    await MessageChannel.shared.sendMessage(msg);
    return result;
  }

  Future<bool> get fastMatch async {
    return MMKVStore.getBool(key: _fastMatchKey);
  }

  Future<bool> setFastMatch(bool on) async {
    return MMKVStore.setBool(key: _fastMatchKey, value: on);
  }

  Future<bool> get subtitleSafeArea async {
    return MMKVStore.getBool(key: _subtitleSafeAreaKey);
  }

  Future<bool> setSubtitleSafeArea(bool on) async {
    final result =
        await MMKVStore.setBool(key: _subtitleSafeAreaKey, value: on);
    final msg = SyncSettingMessage(key: _subtitleSafeAreaKey, value: on);
    await MessageChannel.shared.sendMessage(msg);
    return result;
  }

  Future<int> get danmakuCacheDay async {
    return MMKVStore.getInt(key: _danmakuCacheDayKey);
  }

  Future<bool> setDanmakuCacheDay(int value) async {
    return MMKVStore.setInt(key: _danmakuCacheDayKey, value: value);
  }
}
