
import 'package:dandanplay/Model/BaseModel.dart';
import 'package:dandanplay/Protocol/FileMatchProtocol.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ParseFileMessage.g.dart';

@JsonSerializable()
class ParseFileMessage extends BaseModel with FileMatchProtocol {
  String fileName;
  String fileHash;
  num fileSize;
  String mediaId;

  String get matchFileName {
    return fileName;
  }

  Future<String> get matchFileHash async {
    return fileHash;
  }

  Future<int> get matchFileSize async {
    return fileSize;
  }

  ParseFileMessage(this.fileName, this.fileHash, this.fileSize, this.mediaId);

  factory ParseFileMessage.fromJson(Map<String, dynamic> json) {
    return _$ParseFileMessageFromJson(json);
  }

  Map<String, dynamic> toJson() {
    return _$ParseFileMessageToJson(this);
  }
}