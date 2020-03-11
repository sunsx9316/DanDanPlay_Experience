
import 'package:dandanplay/Model/HttpResponse.dart';
import 'package:dandanplay/Model/Search/SearchAnimateCollection.dart';
import 'package:dandanplay/NetworkManager/BaseNetworkManager.dart';

class SearchNetworkManager extends BaseNetworkManager {
  static Future<HttpResponseResult<SearchAnimateCollection>> searchEpisode(String animeTitle, {String episodeTitle}) async {
    Map<String, dynamic> map = {};
    map["anime"] = animeTitle;
    if (episodeTitle != null) {
      map["episode"] = episodeTitle;
    }

    final res = await BaseNetworkManager.get("/search/episodes", queryParameters: map);

    return HttpResponseResult(data: SearchAnimateCollection.fromJson(res.data), error: res.error);
  }
}