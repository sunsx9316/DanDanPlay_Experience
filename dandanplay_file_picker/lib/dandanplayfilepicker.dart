import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

enum DandanplayfilepickerType {
  file,
  video,
  image
}

class Dandanplayfilepicker {
  Dandanplayfilepicker._();
  static const MethodChannel _channel = const MethodChannel('dandanplay.flutter.plugins.file_picker');
  static const String _tag = 'FilePicker';

  static Future<List<File>> getFiles({String fileExtension, @required DandanplayfilepickerType pickType, bool multipleSelection}) async {
    final filePaths = await _getPath(fileExtension: fileExtension, multipleSelection: multipleSelection, pickType: pickType);

    final files = List<File>();
    if (filePaths != null) {
      for (String path in filePaths) {
        final file =  File(path);
        files.add(file);
      }
    }

    return files;
  }

  static Future<File> getFile({String fileExtension, @required DandanplayfilepickerType pickType}) async {
    final files = await getFiles(pickType: pickType, multipleSelection: false, fileExtension: fileExtension);
    return files.first;
  }


  static Future<List<String>> _getPath({String fileExtension, @required DandanplayfilepickerType pickType, bool multipleSelection = false}) async {
    try {
      Map<String, dynamic> aMap = {};
      aMap["multipleSelection"] = multipleSelection;
      aMap["pickType"] = pickType.index;
      if (fileExtension != null) {
        aMap["fileExtension"] = fileExtension;
      }

      List<dynamic> result = await _channel.invokeMethod("pickFiles", aMap);
      final paths = List<String>();
      for (dynamic aPath in result) {
        if (aPath is String) {
          paths.add(aPath);
        }
      }
      return paths;
    } on PlatformException catch (e) {
      print('[$_tag] Platform exception: $e');
      rethrow;
    } catch (e) {
      print('[$_tag] Unsupported operation. Method not found. The exception thrown was: $e');
      rethrow;
    }
  }
}
