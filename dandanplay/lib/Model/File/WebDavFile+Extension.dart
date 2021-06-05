import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/File/FileProtocol.dart';
import 'package:flutter/cupertino.dart';
import 'package:webdav_client/webdav_client.dart';

class _FileModel extends FileProtocol {

  File _file;

  String _parentPath;

  FileType get fileType {
    if (this._file.isDir) {
      return FileType.folder;
    } else {
      return FileType.file;
    }
  }

  String get path {
    var parentPath = this._parentPath;

    if (parentPath.endsWith("/")) {
      parentPath = parentPath.substring(0, parentPath.lastIndexOf('/'));
    }

    return parentPath + this._file.path;
  }

  int get fileSize {
    return this._file.size;
  }

  FileURLType get urlType {
    return FileURLType.webDav;
  }

  Map<String, dynamic> otherParameter;

  _FileModel({@required File file, @required String parentPath, Auth auth}) {
    this._file = file;
    this._parentPath = parentPath;

    final map = Map<String, dynamic>();
    map["web_dav_user"] = auth.user;
    map["web_dav_password"] = auth.pwd;
    this.otherParameter = map;
  }
}

extension FileExtension on File {
  FileProtocol fileModelObj({@required String parentPath, Auth auth}) {
    final obj = _FileModel(file: this, parentPath: parentPath, auth: auth);
    return obj;
  }
}
