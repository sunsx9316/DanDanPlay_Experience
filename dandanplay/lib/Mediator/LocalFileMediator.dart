
import 'dart:io';

import 'package:dandanplay/Mediator/FileMediator.dart';
import 'package:dandanplay/Model/File/FileProtocol.dart';
import 'package:dandanplay/Model/File/FileDataModel+Extension.dart';
import 'package:flutter/cupertino.dart';


class LocalFileMediator extends FileMediator {

  @override
  Future<List<FileProtocol>> contentOfPath(String path) {
    final dir = Directory(path);
    return dir.list(recursive: false).toList().then((value) {
      return value.map((e) {
        return e.fileModelObj();
      }).toList();
    });
  }

  @override
  String get mediatorTitle => "本地文件";

}