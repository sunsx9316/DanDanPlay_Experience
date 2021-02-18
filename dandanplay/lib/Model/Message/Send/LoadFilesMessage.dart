import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';

abstract class FileModelProtocol {
  FileDataMediaType get fileType;
  int get fileSize;
  String get urlDataString;
  String get path;
  Map<String, dynamic> get otherParameter;

  Map<String, dynamic> data() {
    final map = Map<String, dynamic>();
    map["urlDataString"] = this.urlDataString;
    map["path"] = this.path;
    map["size"] = this.fileSize;
    map["type"] = this.fileType.rawValue;
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

  List<FileModelProtocol> fileDatas;

  LoadFilesMessage({this.fileDatas});

}