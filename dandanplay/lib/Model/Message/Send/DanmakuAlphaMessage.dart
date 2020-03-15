
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:json_annotation/json_annotation.dart';

part 'DanmakuAlphaMessage.g.dart';

@JsonSerializable()
class DanmakuAlphaMessage extends BaseMessage {

  double value = 0;

  @override
  Map<String, dynamic> get data {
    return _$DanmakuAlphaMessageToJson(this);
  }

  DanmakuAlphaMessage(this.value);

}