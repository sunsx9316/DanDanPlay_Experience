
import 'package:dandanplay/Model/Message/Receive/BaseReceiveMessage.dart';
import 'package:json_annotation/json_annotation.dart';

part 'RequestAppVersionMessage.g.dart';

@JsonSerializable()
class RequestAppVersionMessage extends BaseReceiveMessage {
  bool byManual = false;

  RequestAppVersionMessage(this.byManual);

  factory RequestAppVersionMessage.fromJson(Map<String, dynamic> json) {
    return _$RequestAppVersionMessageFromJson(json);
  }

  Map<String, dynamic> toJson() {
    return _$RequestAppVersionMessageToJson(this);
  }
}