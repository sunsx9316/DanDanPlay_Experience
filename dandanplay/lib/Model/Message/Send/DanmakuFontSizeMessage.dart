
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:json_annotation/json_annotation.dart';

part 'DanmakuFontSizeMessage.g.dart';

@JsonSerializable()
class DanmakuFontSizeMessage extends BaseMessage {

  double size = 0;

  @override
  Map<String, dynamic> get data {
    return _$DanmakuFontSizeMessageToJson(this);
  }

  DanmakuFontSizeMessage(this.size);

}