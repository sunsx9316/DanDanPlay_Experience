import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Cache {
  static final shared = Cache();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final danmakuCacheDirectory = Directory("${directory.path}/danmaku_cache");
    final exists = await danmakuCacheDirectory.exists();
    if (!exists) {
      await danmakuCacheDirectory.create();
    }
    return danmakuCacheDirectory.path;
  }

  //保存弹幕
  Future<File> saveDanmaku(dynamic danmaku, num episodeId) async {
    try {
      final jsonStr = json.encode(danmaku);
      final path = await _localPath;
      final jsonFile = File("$path/$episodeId");
      return jsonFile.writeAsString(jsonStr);
    } catch (e) {
      print(e);
      return null;
    }
  }

  //从缓存中获取弹幕
  Future<dynamic> getDanmaku(num episodeId) async {
    try {
      final path = await _localPath;
      final jsonFile = File("$path/$episodeId");
      String danmaku = await jsonFile.readAsString();
      return json.decode(danmaku);
    } catch (e) {
      print(e);
      return null;
    }
  }
}