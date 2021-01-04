import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:json_annotation/json_annotation.dart';

part 'LoadFilesMessage.g.dart';

@JsonSerializable()
class LoadFilesMessage extends BaseMessage {

  @JsonKey(ignore: true)
  @override
  String get name => "LoadFilesMessage";

  @override
  Map<String, dynamic> get data {
    return _$LoadFilesMessageToJson(this);
  }

  List<Map> fileDatas;

  LoadFilesMessage({this.fileDatas});

}