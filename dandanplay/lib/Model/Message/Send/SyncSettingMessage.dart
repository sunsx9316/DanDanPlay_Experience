
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:json_annotation/json_annotation.dart';

part 'SyncSettingMessage.g.dart';

@JsonSerializable()
class SyncSettingMessage extends BaseMessage {
  dynamic value;
  String key;

  @override
  Map<String, dynamic> get data {
    return _$SyncSettingMessageToJson(this);
  }

  SyncSettingMessage({this.value, this.key});

}