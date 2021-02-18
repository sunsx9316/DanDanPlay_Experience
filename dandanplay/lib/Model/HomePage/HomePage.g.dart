// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'HomePage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HomePage _$HomePageFromJson(Map<String, dynamic> json) {
  return HomePage(
    (json['banners'] as List)
        ?.map((e) => e == null
            ? null
            : HomePageBanner.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    (json['shinBangumiList'] as List)
        ?.map((e) => e == null
            ? null
            : HomePageShinBangumi.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    (json['popularTorrents'] as List)
        ?.map((e) => e == null
            ? null
            : HomePagePopularTorrents.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$HomePageToJson(HomePage instance) => <String, dynamic>{
      'banners': instance.banners,
      'shinBangumiList': instance.shinBangumiList,
      'popularTorrents': instance.popularTorrents,
    };
