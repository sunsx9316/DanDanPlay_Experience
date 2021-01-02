import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:json_annotation/json_annotation.dart';

part 'NaviBackMessage.g.dart';

@JsonSerializable()
class NaviBackMessage extends BaseMessage {

  @override
  String get name => "NaviBackMessage";

  @override
  Map<String, dynamic> get data {
    return _$NaviBackMessageToJson(this);
  }

}