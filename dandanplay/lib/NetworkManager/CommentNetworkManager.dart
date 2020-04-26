import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/Comment/DanmakuCache.dart';
import 'package:dandanplay/Model/Error.dart';
import 'package:dandanplay/Model/HttpResponse.dart';
import 'package:dandanplay/NetworkManager/BaseNetworkManager.dart';
import 'package:dandanplay/Tools/Cache.dart';
import 'package:dandanplay/Tools/Preferences.dart';
import 'package:flutter/cupertino.dart';

class CommentNetworkManager extends BaseNetworkManager {
  //  获取弹幕
  //  episodeId 弹幕库编号
  //  from 起始弹幕编号，忽略此编号以前的弹幕。默认值为0
  //  withRelated 是否同时获取关联的第三方弹幕。
  static Future<HttpResponseResult<Map<String, dynamic>>> danmaku(int episodeId,
      {int from, bool withRelated = true}) async {
    final cache = await Cache.shared.getDanmaku(episodeId);
    if (cache != null) {
      int saveTimestamp = cache.saveTimestamp;
      if (saveTimestamp != null) {
        int timestamp = DateTime.now().millisecondsSinceEpoch;
        int cacheDay = await Preferences.shared.danmakuCacheDay;
        //最长有效期
        saveTimestamp += cacheDay * 24 * 60 * 60 * 1000;
        if (saveTimestamp >= timestamp) {
          return HttpResponseResult(data: cache.danmakuData);
        }
      }
    }

    Map<String, dynamic> map = {};
    map["episodeId"] = episodeId;
    if (from != null) {
      map["from"] = from;
    }
    map["withRelated"] = withRelated;

    final res = await BaseNetworkManager.get("/comment/$episodeId",
        queryParameters: map);
    if (res.data != null) {
      final cacheObj = DanmakuCache(danmakuData: res.data, episodeId: episodeId, saveTimestamp: DateTime.now().millisecondsSinceEpoch);
      Cache.shared.saveDanmaku(cacheObj);
      return HttpResponseResult(data: res.data);
    } else {
      return HttpResponseResult(error: res.error);
    }
  }

  static Future<HttpResponseResult> sendDanmaku(
      {@required num time,
      @required DanmakuMode mode,
      @required int color,
      @required String comment,
      @required num episodeId}) async {
    if (time == null || mode == null || color == null || comment == null) {
      assert(false, "参数不能为空！");
      return HttpResponseResult(error: HttpError(-999, "参数错误！"));
    }

    Map<String, dynamic> map = {};
    map["time"] = time;
    map["mode"] = danmakuModeRawValueWithEnum(mode);
    map["color"] = color;
    map["comment"] = comment;

    final res = await BaseNetworkManager.post("/comment/$episodeId", data: map);
    return HttpResponseResult(error: res.error, data: res.data);
  }
}
