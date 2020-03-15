
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:flutter/cupertino.dart';
import 'package:json_annotation/json_annotation.dart';

part 'HUDMessage.g.dart';

enum HUDMessageStyle {
  tips,
  progress
}

@JsonSerializable()
class HUDMessage extends BaseMessage {

  @JsonKey(ignore: true)
  @override
  String get name => "HUDMessage";

  @override
  Map<String, dynamic> get data {
    return _$HUDMessageToJson(this);
  }

  HUDMessageStyle style;
  String text;
  double progress = 0;
  bool isDismiss = false;
  String key;

  HUDMessage({@required this.style, this.text, this.progress, this.isDismiss, this.key});

}