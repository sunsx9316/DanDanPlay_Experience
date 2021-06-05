
import 'dart:io';

import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/File/FileProtocol.dart';
import 'package:flutter/cupertino.dart';

class _FileDataModel extends FileProtocol {

  FileSystemEntity _file;

  _FileDataModel({@required FileSystemEntity file}) {
    this._file = file;
    this.path = file.path;
  }

  int get fileSize {
    if (this.fileType == FileType.file) {
      final file = File(this.path);
      return file.lengthSync();
    }
    return 0;
  }

  FileURLType get urlType {
    return FileURLType.localFile;
  }

  String path;

  Map<String, dynamic> otherParameter;

  FileType get fileType {
    final type = FileSystemEntity.typeSync(this.path);
    if (type == FileSystemEntityType.file) {
      return FileType.file;
    } else {
      return FileType.folder;
    }
  }
}

extension FileExtension on FileSystemEntity {
  FileProtocol fileModelObj() {
    final obj = _FileDataModel(file: this);
    return obj;
  }

}
