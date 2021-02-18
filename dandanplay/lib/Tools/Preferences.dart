import 'dart:convert';
import 'dart:io';

import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/Login/User.dart';
import 'package:dandanplay/Model/Message/Send/SyncSettingMessage.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:dandanplaystore/dandanplaystore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

  //发送弹幕类型
  final _sendDanmakuTypeKey = "sendDanmakuType";

  //发送弹幕颜色
  final _sendDanmakuColorKey = "sendDanmakuColor";

  //显示弹幕
  final _showDanmakuKey = "showDanmaku";

  //自动加载同名弹幕文件
  final _autoLoadCusomDanmakuKey = "autoLoadCusomDanmaku";

  Future<void> setupDefaultValue({bool force = false}) async {
    var isContains = await Dandanplaystore.contains(key: _fastMatchKey);
    if (!isContains || force) {
      await setFastMatch(true);
    }

    isContains = await Dandanplaystore.contains(key: _subtitleSafeAreaKey);
    if (!isContains || force) {
      await setSubtitleSafeArea(true, sync: false);
    }

    isContains = await Dandanplaystore.contains(key: _danmakuCacheDayKey);
    if (!isContains || force) {
      await setDanmakuCacheDay(7);
    }

    isContains = await Dandanplaystore.contains(key: _danmakuFontSizeyKey);
    if (!isContains || force) {
      await setDanmakuFontSize(20, sync: false);
    }

    isContains = await Dandanplaystore.contains(key: _danmakuSpeedKey);
    if (!isContains || force) {
      await setDanmakuSpeed(1, sync: false);
    }

    isContains = await Dandanplaystore.contains(key: _danmakuAlphaKey);
    if (!isContains || force) {
      await setDanmakuAlpha(1, sync: false);
    }

    isContains = await Dandanplaystore.contains(key: _danmakuCountKey);
    if (!isContains || force) {
      await setDanmakuCount(100, sync: false);
    }

    isContains = await Dandanplaystore.contains(key: _showHomePageTipsKey);
    if (!isContains || force) {
      await setShowHomePageTips(true);
    }

    isContains = await Dandanplaystore.contains(key: _playerSpeedKey);
    if (!isContains || force) {
      await setPlayerSpeed(1, sync: false);
    }

    isContains = await Dandanplaystore.contains(key: _playerModeKey);
    if (!isContains || force) {
      await setPlayerMode(PlayerMode.notRepeat, sync: false);
    }

    isContains = await Dandanplaystore.contains(key: _checkUpdateKey);
    if (!isContains || force) {
      await setCheckUpdate(true, sync: false);
    }

    isContains = await Dandanplaystore.contains(key: _sendDanmakuColorKey);
    if (!isContains || force) {
      await setSendDanmakuColor(Colors.white, sync: false);
    }

    isContains = await Dandanplaystore.contains(key: _sendDanmakuTypeKey);
    if (!isContains || force) {
      await setSendDanmakuType(DanmakuMode.normal, sync: false);
    }

    isContains = await Dandanplaystore.contains(key: _showDanmakuKey);
    if (!isContains || force) {
      await setShowDanmaku(false, sync: false);
    }

    isContains = await Dandanplaystore.contains(key: _autoLoadCusomDanmakuKey);
    if (!isContains || force) {
      await setAutoLoadCusomDanmakuKey(true, sync: false);
    }
  }

  Future<bool> get autoLoadCusomDanmaku async {
    final value = await Dandanplaystore.getBool(key: _autoLoadCusomDanmakuKey);
    return value;
  }

  Future<bool> setAutoLoadCusomDanmakuKey(bool value, {bool sync = true}) async {
    final result = await Dandanplaystore.setBool(key: _autoLoadCusomDanmakuKey, value: value);
    if (sync) {
      await _sendSyncMsg(_autoLoadCusomDanmakuKey, value);
    }

    return result;
  }

  Future<bool> get showDanmaku async {
    final value = await Dandanplaystore.getBool(key: _showDanmakuKey);
    return value;
  }

  Future<bool> setShowDanmaku(bool value, {bool sync = true}) async {
    final result = await Dandanplaystore.setBool(key: _showDanmakuKey, value: value);
    if (sync) {
      await _sendSyncMsg(_showDanmakuKey, value);
    }

    return result;
  }

  Future<Color> get sendDanmakuColor async {
    final rgbaValue = await Dandanplaystore.getInt(key: _sendDanmakuColorKey);
    return Color.fromARGB(rgbaValue & 0xFF,
        ((rgbaValue & 0xFF000000) >> 24),
        ((rgbaValue & 0xFF0000) >> 16),
        ((rgbaValue & 0xFF00) >> 8));
  }

  Future<bool> setSendDanmakuColor(Color color, {bool sync = true}) async {
    final r = color.red;
    final g = color.green;
    final b = color.blue;
    final a = color.alpha;

    final value = ((r << 24) + (g << 16) + (b << 8) + a);

    final result = await Dandanplaystore.setInt(key: _sendDanmakuColorKey, value: value);
    if (sync) {
      await _sendSyncMsg(_sendDanmakuColorKey, value);
    }

    return result;
  }

  Future<DanmakuMode> get sendDanmakuType async {
    final value = await Dandanplaystore.getInt(key: _sendDanmakuTypeKey);
    return danmakuModeTypeWithRawValue(value);
  }

  Future<bool> setSendDanmakuType(DanmakuMode value, {bool sync = true}) async {
    final intValue = danmakuModeRawValueWithEnum(value);
    final result = await Dandanplaystore.setInt(key: _sendDanmakuTypeKey, value: intValue);
    if (sync) {
      await _sendSyncMsg(_sendDanmakuTypeKey, intValue);
    }

    return result;
  }

  Future<User> get user async {
    final value = await Dandanplaystore.getString(key: _userKey);

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
      result = await Dandanplaystore.setString(key: _userKey, value: str);
    } else {
      result = await Dandanplaystore.setString(key: _userKey, value: null);
    }
    return result;
  }

  Future<bool> get checkUpdate async {
    final value = await Dandanplaystore.getBool(key: _checkUpdateKey);
    return value;
  }

  Future<bool> setCheckUpdate(bool value, {bool sync = true}) async {
    final result = await Dandanplaystore.setBool(key: _checkUpdateKey, value: value);
    if (sync) {
      await _sendSyncMsg(_checkUpdateKey, value);
    }

    return result;
  }

  Future<PlayerMode> get playerMode async {
    final value = await Dandanplaystore.getInt(key: _playerModeKey);
    return playerModeTypeWithRawValue(value);
  }

  Future<bool> setPlayerMode(PlayerMode value, {bool sync = true}) async {
    final rawValue = playerModeRawValueWithEnum(value);
    final result = await Dandanplaystore.setInt(key: _playerModeKey, value: rawValue);
    if (sync) {
      await _sendSyncMsg(_playerModeKey, rawValue);
    }

    return result;
  }

  Future<double> get playerSpeed async {
    return Dandanplaystore.getDouble(key: _playerSpeedKey);
  }

  Future<bool> setPlayerSpeed(double value, {bool sync = true}) async {
    final result =
        await Dandanplaystore.setDouble(key: _playerSpeedKey, value: value);
    if (sync) {
      await _sendSyncMsg(_playerSpeedKey, value);
    }

    return result;
  }

  Future<bool> get showHomePageTips async {
    return Dandanplaystore.getBool(key: _showHomePageTipsKey);
  }

  Future<bool> setShowHomePageTips(bool isShow) async {
    final result =
        await Dandanplaystore.setBool(key: _showHomePageTipsKey, value: isShow);
    return result;
  }

  Future<String> get homePageBgImage async {
    final name = await Dandanplaystore.getString(key: _homePageBgImageKey);
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
      final result = await Dandanplaystore.setString(
          key: _homePageBgImageKey, value: newFileName);
      return result;
    } else {
      final result =
          await Dandanplaystore.setString(key: _homePageBgImageKey, value: null);
      return result;
    }
  }

  Future<int> get danmakuCount async {
    return Dandanplaystore.getInt(key: _danmakuCountKey);
  }

  Future<bool> setDanmakuCount(int value, {bool sync = true}) async {
    final result = await Dandanplaystore.setInt(key: _danmakuCountKey, value: value);
    if (sync) {
      await _sendSyncMsg(_danmakuCountKey, value);
    }
    return result;
  }

  Future<double> get danmakuAlpha async {
    return Dandanplaystore.getDouble(key: _danmakuAlphaKey);
  }

  Future<bool> setDanmakuAlpha(double value, {bool sync = true}) async {
    final result =
        await Dandanplaystore.setDouble(key: _danmakuAlphaKey, value: value);
    if (sync) {
      await _sendSyncMsg(_danmakuAlphaKey, value);
    }
    return result;
  }

  Future<double> get danmakuSpeed async {
    return Dandanplaystore.getDouble(key: _danmakuSpeedKey);
  }

  Future<bool> setDanmakuSpeed(double value, {bool sync = true}) async {
    final result =
        await Dandanplaystore.setDouble(key: _danmakuSpeedKey, value: value);
    if (sync) {
      await _sendSyncMsg(_danmakuSpeedKey, value);
    }
    return result;
  }

  Future<double> get danmakuFontSize async {
    return Dandanplaystore.getDouble(key: _danmakuFontSizeyKey);
  }

  Future<bool> setDanmakuFontSize(double value, {bool sync = true}) async {
    final result =
        await Dandanplaystore.setDouble(key: _danmakuFontSizeyKey, value: value);
    if (sync) {
      await _sendSyncMsg(_danmakuFontSizeyKey, value);
    }
    return result;
  }

  Future<bool> get fastMatch async {
    return Dandanplaystore.getBool(key: _fastMatchKey);
  }

  Future<bool> setFastMatch(bool on) async {
    return Dandanplaystore.setBool(key: _fastMatchKey, value: on);
  }

  Future<bool> get subtitleSafeArea async {
    return Dandanplaystore.getBool(key: _subtitleSafeAreaKey);
  }

  Future<bool> setSubtitleSafeArea(bool on, {bool sync = true}) async {
    final result =
        await Dandanplaystore.setBool(key: _subtitleSafeAreaKey, value: on);
    if (sync) {
      await _sendSyncMsg(_subtitleSafeAreaKey, on);
    }
    return result;
  }

  Future<int> get danmakuCacheDay async {
    return Dandanplaystore.getInt(key: _danmakuCacheDayKey);
  }

  Future<bool> setDanmakuCacheDay(int value) async {
    return Dandanplaystore.setInt(key: _danmakuCacheDayKey, value: value);
  }

  Future _sendSyncMsg(String key, dynamic value) async {
    final msg = SyncSettingMessage(key: key, value: value);
    return MessageChannel.shared.sendMessage(msg);
  }
}
