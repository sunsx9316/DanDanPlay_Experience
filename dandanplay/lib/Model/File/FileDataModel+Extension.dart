
import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/Message/Send/LoadFilesMessage.dart';
import 'package:dandanplayfilepicker/dandanplayfilepicker.dart';

class _FileDataModel extends FileModelProtocol {
  int fileSize;
  FileDataMediaType fileType;
  String urlDataString;
  String path;
  Map<String, dynamic> otherParameter;
}

extension FileDataModelExtension on FileDataModel {
  FileModelProtocol createProtocolObj() {
    final obj = _FileDataModel();
    obj.fileType = FileDataMediaType.localFile;
    obj.urlDataString = this.urlDataString;
    return obj;
  }
}
