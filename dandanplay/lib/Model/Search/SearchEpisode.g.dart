// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'SearchEpisode.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchEpisode _$SearchEpisodeFromJson(Map<String, dynamic> json) {
  return SearchEpisode(
    json['episodeId'] as int,
    json['episodeTitle'] as String,
  );
}

Map<String, dynamic> _$SearchEpisodeToJson(SearchEpisode instance) =>
    <String, dynamic>{
      'episodeId': instance.episodeId,
      'episodeTitle': instance.episodeTitle,
    };
