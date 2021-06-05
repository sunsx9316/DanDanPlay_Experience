import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';

abstract class FileDataProtocol {
  FileURLType get urlType;
  int get fileSize;
  String get path;
  Map<String, dynamic> get otherParameter;

  Map<String, dynamic> data() {
    final map = Map<String, dynamic>();
    map["path"] = this.path;
    map["size"] = this.fileSize;
    map["type"] = this.urlType.rawValue;
    map["otherParameter"] = this.otherParameter;
    return map;
  }
}

class LoadFilesMessage extends BaseMessage {

  @override
  String get name => "LoadFilesMessage";

  @override
  Map<String, dynamic> get data {
    final map = Map<String, dynamic>();
    if (this.fileDatas != null) {

      final arr = List.empty(growable: true);
      for (final obj in this.fileDatas) {
        arr.add(obj.data());
      }

      map["fileDatas"] = arr;
    }

    return map;
  }

  List<FileDataProtocol> fileDatas;

  LoadFilesMessage({this.fileDatas});

}