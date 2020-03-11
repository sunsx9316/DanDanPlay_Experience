
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:json_annotation/json_annotation.dart';

part 'LoadDanmakuMessage.g.dart';

@JsonSerializable()
class LoadDanmakuMessage extends BaseMessage<Map<String, dynamic>> {

  @JsonKey(ignore: true)
  @override
  String get name => "LoadDanmakuMessage";

  @override
  Map<String, dynamic> get data {
    return _$LoadDanmakuMessageToJson(this);
  }

  String mediaId;
  Map<String, dynamic> danmakuCollection;
  String title;

  LoadDanmakuMessage(this.mediaId, {this.danmakuCollection, this.title});

}