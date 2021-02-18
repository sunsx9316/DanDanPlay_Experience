
import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/Message/Send/LoadFilesMessage.dart';
import 'package:flutter/cupertino.dart';
import 'package:webdav_client/webdav_client.dart';

class _FileDataModel extends FileModelProtocol {
  int fileSize = 0;
  FileDataMediaType fileType;
  String urlDataString;
  String path;
  Map<String, dynamic> otherParameter;
}

extension FileExtension on File {
  FileModelProtocol createProtocolObj({@required String parentPath, String user, String password}) {
    final obj = _FileDataModel();
    obj.fileType = FileDataMediaType.webDav;
    obj.path = parentPath + this.path;
    obj.fileSize = this.size;
    final map = Map<String, dynamic>();
    map["web_dav_user"] = user;
    map["web_dav_password"] = password;
    obj.otherParameter = map;
    return obj;
  }
}
