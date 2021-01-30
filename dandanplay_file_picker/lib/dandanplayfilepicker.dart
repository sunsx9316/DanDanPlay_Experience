import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

enum DandanplayfilepickerType {
  file,
  video,
  image
}

class FileDataModel {
  String path;
  //对于沙盒外的URL 需要通过这种方式获取
  String urlDataString;

  Map<String, dynamic> get mapData {
    var dic = Map<String, dynamic>();
    dic["path"] = path;
    dic["urlDataString"] = urlDataString;
    return dic;
  }

  FileDataModel(Map jsonDic) {
    this.path = jsonDic["path"] as String;
    this.urlDataString = jsonDic["urlDataString"] as String;
  }
}

class Dandanplayfilepicker {
  Dandanplayfilepicker._();
  static const MethodChannel _channel = const MethodChannel('dandanplay.flutter.plugins.file_picker');
  static const String _tag = 'FilePicker';

  static Future<List<FileDataModel>> getFiles({String fileExtension, @required DandanplayfilepickerType pickType, bool multipleSelection = false}) async {
    try {
      Map<String, dynamic> aMap = {};
      aMap["multipleSelection"] = multipleSelection;
      aMap["pickType"] = pickType.index;
      if (fileExtension != null) {
        aMap["fileExtension"] = fileExtension;
      }

      List<dynamic> result = await _channel.invokeMethod("pickFiles", aMap);
      final files = List<FileDataModel>.empty(growable: true);
      if (result is List) {
        for (dynamic model in result) {
          if (model is Map) {
            final dataModel = FileDataModel(model);
            files.add(dataModel);
          }
        }
      }
      return files;
    } on PlatformException catch (e) {
      print('[$_tag] Platform exception: $e');
      rethrow;
    } catch (e) {
      print('[$_tag] Unsupported operation. Method not found. The exception thrown was: $e');
      rethrow;
    }
  }
}
