// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'SearchAnimateCollection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchAnimateCollection _$SearchAnimateCollectionFromJson(
    Map<String, dynamic> json) {
  return SearchAnimateCollection(
      json['hasMore'] as bool,
      (json['animes'] as List)
          ?.map((e) => e == null
              ? null
              : SearchAnimate.fromJson(e as Map<String, dynamic>))
          ?.toList());
}

Map<String, dynamic> _$SearchAnimateCollectionToJson(
        SearchAnimateCollection instance) =>
    <String, dynamic>{'hasMore': instance.hasMore, 'animes': instance.animes};
