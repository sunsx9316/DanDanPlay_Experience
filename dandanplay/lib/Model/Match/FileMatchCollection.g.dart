// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'FileMatchCollection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileMatchCollection _$FileMatchCollectionFromJson(Map<String, dynamic> json) {
  return FileMatchCollection(
    json['isMatched'] as bool,
    (json['matches'] as List)
        ?.map((e) =>
            e == null ? null : FileMatch.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$FileMatchCollectionToJson(
        FileMatchCollection instance) =>
    <String, dynamic>{
      'isMatched': instance.isMatched,
      'matches': instance.matches,
    };
