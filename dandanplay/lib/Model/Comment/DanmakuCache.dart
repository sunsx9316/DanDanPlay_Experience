
import 'package:dandanplay/Model/BaseModel.dart';

class DanmakuCache extends BaseModel {
  Map<String, dynamic> danmakuData;
  int episodeId = 0;
  int saveTimestamp = 0;

  factory DanmakuCache.fromJsonMap(Map<String, dynamic> map) {
    final cache = DanmakuCache();

    if (map["episodeId"] is int) {
      cache.episodeId = map["episodeId"];
    }

    if (map["saveTimestamp"] is int) {
      cache.saveTimestamp = map["saveTimestamp"];
    }

    if (map["danmakuData"] is Map) {
      cache.danmakuData = map["danmakuData"];
    }

    return cache;
  }

  Map<String, dynamic> toJson() {
    final danmakuCache = Map<String, dynamic>();
    danmakuCache["episodeId"] = episodeId;
    danmakuCache["saveTimestamp"] = saveTimestamp;
    danmakuCache["danmakuData"] = danmakuData;
    return danmakuCache;
  }

  DanmakuCache({this.danmakuData, this.episodeId, this.saveTimestamp});
}