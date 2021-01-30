
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:json_annotation/json_annotation.dart';

part 'LoadCustomDanmakuMessage.g.dart';

@JsonSerializable()
class LoadCustomDanmakuMessage extends BaseMessage {

  @JsonKey(ignore: true)
  @override
  String get name => "LoadCustomDanmakuMessage";

  @override
  Map<String, dynamic> get data {
    return _$LoadCustomDanmakuMessageToJson(this);
  }

}