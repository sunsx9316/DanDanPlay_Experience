// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'SearchAnimate.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchAnimate _$SearchAnimateFromJson(Map<String, dynamic> json) {
  return SearchAnimate(
    json['animeId'] as num,
    json['animeTitle'] as String,
    json['type'] as String,
    json['typeDescription'] as String,
    (json['episodes'] as List)
        ?.map((e) => e == null
            ? null
            : SearchEpisode.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$SearchAnimateToJson(SearchAnimate instance) =>
    <String, dynamic>{
      'animeId': instance.animeId,
      'animeTitle': instance.animeTitle,
      'type': instance.typeRawValue,
      'typeDescription': instance.typeDescription,
      'episodes': instance.episodes,
    };
