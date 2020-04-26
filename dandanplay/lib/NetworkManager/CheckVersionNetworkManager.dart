
import 'package:dandanplay/Model/HttpResponse.dart';
import 'package:dandanplay/Model/Update/AppVersion.dart';
import 'package:dandanplay/NetworkManager/BaseNetworkManager.dart';

class CheckVersionNetworkManager extends BaseNetworkManager {
  static Future<AppVersion> checkNewVersion() async {
    final res = await BaseNetworkManager.get("http://dandanmac.acplay.net/cross-platform/check_version.json");
    return AppVersion.fromJson(res.data);
  }
}