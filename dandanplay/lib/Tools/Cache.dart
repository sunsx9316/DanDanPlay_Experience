import 'dart:convert';
import 'dart:io';
import 'package:dandanplay/Model/Comment/DanmakuCache.dart';
import 'package:path_provider/path_provider.dart';

class Cache {
  static final shared = Cache();

  Future<String> get _localPath async {
    final directory = await getTemporaryDirectory();
    final danmakuCacheDirectory = Directory("${directory.path}/danmaku_cache");
    final exists = await danmakuCacheDirectory.exists();
    if (!exists) {
      await danmakuCacheDirectory.create();
    }
    return danmakuCacheDirectory.path;
  }

  //保存弹幕
  Future<File> saveDanmaku(DanmakuCache cache) async {
    try {
      final jsonStr = json.encode(cache.toJson());
      final path = await _localPath;
      final jsonFile = File("$path/${cache.episodeId}");
      return jsonFile.writeAsString(jsonStr);
    } catch (e) {
      print(e);
      return null;
    }
  }

  //从缓存中获取弹幕
  Future<DanmakuCache> getDanmaku(num episodeId) async {
    try {
      final path = await _localPath;
      final jsonFile = File("$path/$episodeId");
      final danmakuStr = await jsonFile.readAsString();
      final cacheObj = DanmakuCache.fromJsonMap(json.decode(danmakuStr));
      return cacheObj;
    } catch (e) {
      print(e);
      return null;
    }
  }
}