import 'package:dandanplay/Model/HttpResponse.dart';
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
    final req = _createDefaultRequestObj();
    print("[Http] [Get request] path: $path, parameters: $queryParameters");
    final res = await req.get(path, queryParameters: queryParameters);
    print("[Http] [Get response] path: $path, response: ");
    return HttpResponse(res.data);
  }

  static Future<HttpResponse> post(String path,
      {Map<String, dynamic> data}) async {
    final req = _createDefaultRequestObj();
    print("[Http] [Post request] path: $path, parameters: $data");
    final res = await req.post(path, data: data);
    print("[Http] [Post response] path: $path, response: ");
    return HttpResponse(res.data);
  }

  static Dio _createDefaultRequestObj() {
    final dio = Dio();
    dio.options.baseUrl = BaseNetworkManager.apiPath;
    dio.options.connectTimeout = 5000; //5s
    dio.options.receiveTimeout = 3000;
    return dio;
  }
}
