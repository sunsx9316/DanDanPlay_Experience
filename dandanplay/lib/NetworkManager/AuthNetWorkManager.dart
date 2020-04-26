import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dandanplay/Config/AppConfig.dart';
import 'package:dandanplay/Model/Error.dart';
import 'package:dandanplay/Model/HttpResponse.dart';
import 'package:dandanplay/Model/Login/User.dart';
import 'package:dandanplay/NetworkManager/BaseNetworkManager.dart';
import 'package:flutter/cupertino.dart';

class AuthNetWorkManager extends BaseNetworkManager {
  static Future<HttpResponseResult<User>> login(
      {@required String userName, @required String password}) async {
    if (userName == null || password == null) {
      assert(false, "参数不能为空！");
      return HttpResponseResult(error: HttpError(-999, "参数错误！"));
    }

    final map = Map<String, dynamic>();
    map["userName"] = userName;
    map["password"] = password;
    map["appId"] = AppConfig.appId;
    map["unixTimestamp"] = _timestamp();

    List<String> arr = [
      map["appId"],
      map["password"],
      map["unixTimestamp"],
      map["userName"],
      AppConfig.appSecret
    ];
    map["hash"] = _convertHash(arr);

    final res = await BaseNetworkManager.post("/login", data: map);

    return HttpResponseResult(
        data: User.fromJsonMap(res.data), error: res.error);
  }

  static Future<HttpResponseResult<User>> renew() async {
    final res = await BaseNetworkManager.get("/login/renew");
    try {
      final data = User.fromJsonMap(res.data);
      return HttpResponseResult(
          data: User.fromJsonMap(res.data), error: res.error);
    } catch (e) {
      print(e);
      return HttpResponseResult(data: null, error: res.error);
    }
  }

  //修改用户昵称
  static Future<HttpResponseResult> profile(
      {@required String screenName}) async {
    if (screenName == null) {
      assert(false, "参数不能为空！");
      return HttpResponseResult(error: HttpError(-999, "参数错误！"));
    }

    final map = Map<String, dynamic>();
    map["screenName"] = screenName;

    final res = await BaseNetworkManager.post("/user/profile", data: map);
    return HttpResponseResult(data: res.data, error: res.error);
  }

  //修改密码
  static Future<HttpResponseResult> changePassword(
      {@required String oldPassword, @required String newPassword}) async {
    if (oldPassword == null ||
        newPassword == null) {
      assert(false, "参数不能为空！");
      return HttpResponseResult(error: HttpError(-999, "参数错误！"));
    }

    final map = Map<String, dynamic>();
    map["oldPassword"] = oldPassword;
    map["newPassword"] = newPassword;

    final res = await BaseNetworkManager.post("/user/password", data: map);
    return HttpResponseResult(data: res.data, error: res.error);
  }

  //注册
  static Future<HttpResponseResult<User>> register(
      {@required String userName,
        @required String password,
        @required String email,
        @required String screenName}) async {
    if (userName == null ||
        password == null ||
        email == null ||
        screenName == null) {
      assert(false, "参数不能为空！");
      return HttpResponseResult(error: HttpError(-999, "参数错误！"));
    }

    final map = Map<String, dynamic>();
    map["appId"] = AppConfig.appId;
    map["userName"] = userName;
    map["password"] = password;
    map["email"] = email;
    map["screenName"] = screenName;
    map["unixTimestamp"] = _timestamp();

    List<String> arr = [
      map["appId"],
      map["email"],
      map["password"],
      map["screenName"],
      map["unixTimestamp"],
      map["userName"],
      AppConfig.appSecret
    ];
    map["hash"] = _convertHash(arr);

    final res = await BaseNetworkManager.post("/register", data: map);
    return HttpResponseResult(
        data: User.fromJsonMap(res.data), error: res.error);
  }

  //重设密码
  static Future<HttpResponseResult> resetPassword(
      {@required String userName,
        @required String email}) async {
    if (userName == null ||
        email == null) {
      assert(false, "参数不能为空！");
      return HttpResponseResult(error: HttpError(-999, "参数错误！"));
    }

    final map = Map<String, dynamic>();
    map["appId"] = AppConfig.appId;
    map["userName"] = userName;
    map["email"] = email;
    map["unixTimestamp"] = _timestamp();

    List<String> arr = [
      map["appId"],
      map["email"],
      map["unixTimestamp"],
      map["userName"],
      AppConfig.appSecret
    ];
    map["hash"] = _convertHash(arr);
    final res = await BaseNetworkManager.post("/register/resetpassword", data: map);
    return HttpResponseResult(
        data: res.data, error: res.error);
  }

  static Future<HttpResponseResult> findmyid(
      {@required String email}) async {
    if (email == null) {
      assert(false, "参数不能为空！");
      return HttpResponseResult(error: HttpError(-999, "参数错误！"));
    }

    final map = Map<String, dynamic>();
    map["appId"] = AppConfig.appId;
    map["email"] = email;
    map["unixTimestamp"] = _timestamp();

    List<String> arr = [
      map["appId"],
      map["email"],
      map["unixTimestamp"],
      AppConfig.appSecret
    ];
    map["hash"] = _convertHash(arr);
    final res = await BaseNetworkManager.post("/register/findmyid", data: map);
    return HttpResponseResult(
        data: res.data, error: res.error);
  }

  //转hash
  static String _convertHash(List<String> parameter) {
    String hashStr = "";

    for (String aStr in parameter) {
      hashStr += aStr;
    }

    final bytes = utf8.encode(hashStr);
    final hash = md5.convert(bytes);
    return "$hash";
  }
  //生存时间戳
  static String _timestamp() {
    return "${DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000}";
  }

}
