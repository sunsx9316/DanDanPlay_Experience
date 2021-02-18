// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'HomePagePopularTorrents.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HomePagePopularTorrents _$HomePagePopularTorrentsFromJson(
    Map<String, dynamic> json) {
  return HomePagePopularTorrents(
    json['name'] as String,
    json['magnet'] as String,
    json['hot'] as int,
  );
}

Map<String, dynamic> _$HomePagePopularTorrentsToJson(
        HomePagePopularTorrents instance) =>
    <String, dynamic>{
      'name': instance.name,
      'magnet': instance.magnet,
      'hot': instance.hot,
    };
