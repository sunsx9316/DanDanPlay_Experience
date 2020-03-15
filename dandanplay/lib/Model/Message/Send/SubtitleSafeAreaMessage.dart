
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:json_annotation/json_annotation.dart';

part 'SubtitleSafeAreaMessage.g.dart';

@JsonSerializable()
class SubtitleSafeAreaMessage extends BaseMessage {

  bool on = false;

  @override
  Map<String, dynamic> get data {
    return _$SubtitleSafeAreaMessageToJson(this);
  }

  SubtitleSafeAreaMessage(this.on);

}