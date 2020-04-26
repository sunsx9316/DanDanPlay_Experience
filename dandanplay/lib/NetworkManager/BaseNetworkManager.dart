import 'package:dandanplay/Model/HttpResponse.dart';
import 'package:dandanplay/Tools/Preferences.dart';
import 'package:dio/dio.dart';

class BaseNetworkManager {
  static String get oldApiPath {
    return "https://api.acplay.net/api/v1";
  }

  static String get apiPath {
    return "https://api.acplay.net/api/v2";
  }

  static Future<HttpResponse> get(String path,
      {Map<String, dynamic> queryParameters}) async {
    final req = await _createDefaultRequestObj();
    print("[Http] [Get request] path: $path, parameters: $queryParameters");

    Response res;
    try {
      res = await req.get(path, queryParameters: queryParameters);
      print("[Http] [Get response] path: $path, response: ");
    } catch (e) {
      print("请求失败 ：$e");
    }

    return HttpResponse(res.data);
  }

  static Future<HttpResponse> post(String path,
      {Map<String, dynamic> data}) async {
    final req = await _createDefaultRequestObj();
    print("[Http] [Post request] path: $path, parameters: $data");
    Response res;
    try {
      res = await req.post(path, data: data);
      print("[Http] [Post response] path: $path, response: ");
    } catch (e) {
      print("请求失败 ：$e");
    }

    return HttpResponse(res.data);
  }

  static Future<Dio> _createDefaultRequestObj() async {
    final dio = Dio();
    dio.options.baseUrl = BaseNetworkManager.apiPath;
    dio.options.connectTimeout = 5000; //5s
    dio.options.receiveTimeout = 3000;
    final user = await Preferences.shared.user;

    if (user != null && user.token != null) {
      dio.options.headers["Authorization"] = "Bearer ${user.token}";
    }
    dio.options.headers["user-agent"] = "DDPlay_Exp/Mac 5.0.0";
    return dio;
  }
}
