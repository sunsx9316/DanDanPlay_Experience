// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'FileMatch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileMatch _$FileMatchFromJson(Map<String, dynamic> json) {
  return FileMatch(
      json['episodeId'] as num,
      json['animeId'] as num,
      json['animeTitle'] as String,
      json['episodeTitle'] as String,
      json['type'] as String,
      json['typeDescription'] as String,
      json['shift'] as num);
}

Map<String, dynamic> _$FileMatchToJson(FileMatch instance) => <String, dynamic>{
      'episodeId': instance.episodeId,
      'animeId': instance.animeId,
      'animeTitle': instance.animeTitle,
      'episodeTitle': instance.episodeTitle,
      'shift': instance.shift,
      'type': instance.typeRawValue,
      'typeDescription': instance.typeDescription
    };
