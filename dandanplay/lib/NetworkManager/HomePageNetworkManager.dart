import 'package:dandanplay/Model/HomePage/HomePage.dart';
import 'package:dandanplay/Model/HttpResponse.dart';
import 'package:dandanplay/NetworkManager/BaseNetworkManager.dart';

class HomePageNetworkManager extends BaseNetworkManager {
  static Future<HttpResponseResult<HomePage>> getHomepage() async {
    final res = await BaseNetworkManager.get("/homepage");
    return HttpResponseResult(
        data: HomePage.fromJson(res.data), error: res.error);
  }
}
