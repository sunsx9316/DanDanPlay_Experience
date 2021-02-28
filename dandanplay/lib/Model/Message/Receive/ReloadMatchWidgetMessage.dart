
import 'dart:convert';

import 'package:dandanplay/Model/Match/FileMatchCollection.dart';
import 'package:dandanplay/Model/Message/Receive/BaseReceiveMessage.dart';
import 'package:flutter/cupertino.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ReloadMatchWidgetMessage.g.dart';

@JsonSerializable()
class ReloadMatchWidgetMessage extends BaseReceiveMessage {
  String mediaId;
  String collectionData;

  @JsonKey(ignore: true)
  @override
  String get name => "ReloadMatchWidgetMessage";

  @JsonKey(ignore: true)
  @override
  Map<String, dynamic> get data {
    return this.toJson();
  }

  @JsonKey(ignore: true)
  FileMatchCollection get collection {
    final jsonObj = json.decode(collectionData ?? "");
    if (jsonObj != null) {
      return FileMatchCollection.fromJson(jsonObj);
    }
    return null;
  }

  ReloadMatchWidgetMessage({@required this.mediaId, this.collectionData});

  factory ReloadMatchWidgetMessage.fromParseData({@required String mediaId, FileMatchCollection collection}) {
    final jsonObj = collection.toJson();
    final jsonStr = json.encode(jsonObj);
    return ReloadMatchWidgetMessage(mediaId: mediaId, collectionData: jsonStr);
  }

  factory ReloadMatchWidgetMessage.fromJson(Map<String, dynamic> json) {
    return _$ReloadMatchWidgetMessageFromJson(json);
  }

  Map<String, dynamic> toJson() {
    return _$ReloadMatchWidgetMessageToJson(this);
  }

}