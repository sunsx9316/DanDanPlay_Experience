// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'LoadDanmakuMessage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoadDanmakuMessage _$LoadDanmakuMessageFromJson(Map<String, dynamic> json) {
  return LoadDanmakuMessage(json['mediaId'] as String,
      danmakuCollection: json['danmakuCollection'] as Map<String, dynamic>,
      title: json['title'] as String);
}

Map<String, dynamic> _$LoadDanmakuMessageToJson(LoadDanmakuMessage instance) =>
    <String, dynamic>{
      'mediaId': instance.mediaId,
      'danmakuCollection': instance.danmakuCollection,
      'title': instance.title
    };
