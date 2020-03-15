import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:json_annotation/json_annotation.dart';

part 'DanmakuSpeedMessage.g.dart';

@JsonSerializable()
class DanmakuSpeedMessage extends BaseMessage {

  double speed = 0;

  @override
  Map<String, dynamic> get data {
    return _$DanmakuSpeedMessageToJson(this);
  }

  DanmakuSpeedMessage(this.speed);

}