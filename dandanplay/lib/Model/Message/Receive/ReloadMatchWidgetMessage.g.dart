// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ReloadMatchWidgetMessage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReloadMatchWidgetMessage _$ReloadMatchWidgetMessageFromJson(
    Map<String, dynamic> json) {
  return ReloadMatchWidgetMessage(
    mediaId: json['mediaId'] as String,
    collectionData: json['collectionData'] as String,
  )..data = json['data'] as Map<String, dynamic>;
}

Map<String, dynamic> _$ReloadMatchWidgetMessageToJson(
        ReloadMatchWidgetMessage instance) =>
    <String, dynamic>{
      'mediaId': instance.mediaId,
      'collectionData': instance.collectionData,
      'data': instance.data,
    };
