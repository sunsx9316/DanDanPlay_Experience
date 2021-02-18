// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ParseFileMessage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ParseFileMessage _$ParseFileMessageFromJson(Map<String, dynamic> json) {
  return ParseFileMessage(
    json['fileName'] as String,
    json['fileHash'] as String,
    json['fileSize'] as num,
    json['mediaId'] as String,
  );
}

Map<String, dynamic> _$ParseFileMessageToJson(ParseFileMessage instance) =>
    <String, dynamic>{
      'fileName': instance.fileName,
      'fileHash': instance.fileHash,
      'fileSize': instance.fileSize,
      'mediaId': instance.mediaId,
    };
