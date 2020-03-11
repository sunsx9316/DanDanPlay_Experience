import 'package:dandanplay/Model/HttpResponse.dart';
import 'package:dandanplay/Model/Match/FileMatchCollection.dart';
import 'package:dandanplay/NetworkManager/BaseNetworkManager.dart';
import 'package:dandanplay/Protocol/FileMatchProtocol.dart';

class MatchNetworkManager extends BaseNetworkManager {
  static Future<HttpResponseResult<FileMatchCollection>> match(
      FileMatchProtocol file) async {
    Map<String, dynamic> map = {};
    map["fileName"] = file.matchFileName;
    map["fileHash"] = await file.matchFileHash;
    map["fileSize"] = await file.matchFileSize;

    final res = await BaseNetworkManager.post("/match", data: map);
    return HttpResponseResult(
        data: FileMatchCollection.fromJson(res.data), error: res.error);
  }
}
