
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:json_annotation/json_annotation.dart';

part 'DanmakuCountMessage.g.dart';

@JsonSerializable()
class DanmakuCountMessage extends BaseMessage {

  int count = 0;

  @override
  Map<String, dynamic> get data {
    return _$DanmakuCountMessageToJson(this);
  }

  DanmakuCountMessage(this.count);

}