// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'HomePageBanner.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HomePageBanner _$HomePageBannerFromJson(Map<String, dynamic> json) {
  return HomePageBanner(json['title'] as String, json['description'] as String,
      json['url'] as String, json['imageUrl'] as String);
}

Map<String, dynamic> _$HomePageBannerToJson(HomePageBanner instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'url': instance.url,
      'imageUrl': instance.imageUrl
    };
