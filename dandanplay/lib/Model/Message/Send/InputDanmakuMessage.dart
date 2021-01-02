
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:json_annotation/json_annotation.dart';

part 'InputDanmakuMessage.g.dart';

@JsonSerializable()
class InputDanmakuMessage extends BaseMessage {

  @override
  String get name => "InputDanmakuMessage";

  @override
  Map<String, dynamic> get data {
    return _$InputDanmakuMessageToJson(this);
  }

  String message;

  InputDanmakuMessage({this.message});
}