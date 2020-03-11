import 'package:dandanplay/Model/HttpResponse.dart';
import 'package:dandanplay/NetworkManager/BaseNetworkManager.dart';
import 'package:dandanplay/Tools/Cache.dart';

class CommentNetworkManager extends BaseNetworkManager {
  //  获取弹幕
  //  episodeId 弹幕库编号
  //  from 起始弹幕编号，忽略此编号以前的弹幕。默认值为0
  //  withRelated 是否同时获取关联的第三方弹幕。
  static Future<HttpResponseResult<Map<String, dynamic>>> danmaku(int episodeId,
      {int from, bool withRelated = true}) async {

    final cache = await Cache.shared.getDanmaku(episodeId);
    if (cache != null) {
      return HttpResponseResult(data: cache);
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
      Cache.shared.saveDanmaku(res.data, episodeId);
      return HttpResponseResult(data: res.data);
    } else {
      return HttpResponseResult(error: res.error);
    }
  }
}
