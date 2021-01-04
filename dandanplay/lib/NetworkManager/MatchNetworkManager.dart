import 'dart:convert';

import 'package:connectivity/connectivity.dart';
import 'package:dandanplay/Model/HttpResponse.dart';
import 'package:dandanplay/Model/Match/FileMatch.dart';
import 'package:dandanplay/Model/Match/FileMatchCollection.dart';
import 'package:dandanplay/NetworkManager/BaseNetworkManager.dart';
import 'package:dandanplay/Protocol/FileMatchProtocol.dart';
import 'package:dandanplaystore/dandanplaystore.dart';

class MatchNetworkManager extends BaseNetworkManager {
  static Future<HttpResponseResult<FileMatchCollection>> match(
      FileMatchProtocol file) async {
    Map<String, dynamic> map = {};
    map["fileName"] = file.matchFileName;
    map["fileHash"] = await file.matchFileHash;
    map["fileSize"] = await file.matchFileSize;

    final connectivityResult = await Connectivity().checkConnectivity();
    //当前是离线状态，读取缓存
    if (connectivityResult == ConnectivityResult.none) {
      String jsonStr;
      if (map["fileHash"] != null) {
        jsonStr = await Dandanplaystore.getString(
            key: map["fileHash"], id: "com.dandanplay.match");
        if (jsonStr != null) {
          Map<String, dynamic> jsonObj = json.decode(jsonStr);
          final matchModel = FileMatch.fromJson(jsonObj);
          if (matchModel != null) {
            final collection = FileMatchCollection(true, [matchModel]);
            return HttpResponseResult(data: collection, error: null);
          }
        }
      }
    }

    final res = await BaseNetworkManager.post("/match", data: map);
    final collection = FileMatchCollection.fromJson(res.data);

    if (collection.isMatched && collection.matches.length == 1) {
      final match = collection.matches.first;
      final jsonStr = json.encode(match.toJson());
      Dandanplaystore.setString(
          key: map["fileHash"], value: jsonStr, id: "com.dandanplay.match");
    }

    return HttpResponseResult(data: collection, error: res.error);
  }
}
