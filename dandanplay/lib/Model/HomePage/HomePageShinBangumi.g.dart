// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'HomePageShinBangumi.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HomePageShinBangumi _$HomePageShinBangumiFromJson(Map<String, dynamic> json) {
  return HomePageShinBangumi(
      json['animeId'] as int,
      json['animeTitle'] as String,
      json['imageUrl'] as String,
      json['searchKeyword'] as String,
      json['isOnAir'] as bool,
      json['airDay'] as int,
      json['isFavorited'] as bool,
      json['isRestricted'] as bool,
      (json['rating'] as num)?.toDouble());
}

Map<String, dynamic> _$HomePageShinBangumiToJson(
        HomePageShinBangumi instance) =>
    <String, dynamic>{
      'animeId': instance.animeId,
      'animeTitle': instance.animeTitle,
      'imageUrl': instance.imageUrl,
      'searchKeyword': instance.searchKeyword,
      'isOnAir': instance.isOnAir,
      'airDay': instance.airDay,
      'isFavorited': instance.isFavorited,
      'isRestricted': instance.isRestricted,
      'rating': instance.rating
    };
