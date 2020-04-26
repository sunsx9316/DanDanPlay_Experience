// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'LoadDanmakuMessage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoadDanmakuMessage _$LoadDanmakuMessageFromJson(Map<String, dynamic> json) {
  return LoadDanmakuMessage(
      mediaId: json['mediaId'] as String,
      danmakuCollection: json['danmakuCollection'] as Map<String, dynamic>,
      title: json['title'] as String,
      playImmediately: json['playImmediately'] as bool,
      episodeId: json['episodeId'] as int);
}

Map<String, dynamic> _$LoadDanmakuMessageToJson(LoadDanmakuMessage instance) =>
    <String, dynamic>{
      'mediaId': instance.mediaId,
      'danmakuCollection': instance.danmakuCollection,
      'title': instance.title,
      'episodeId': instance.episodeId,
      'playImmediately': instance.playImmediately
    };
