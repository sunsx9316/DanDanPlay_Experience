// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'LoadFilesMessage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoadFilesMessage _$LoadFilesMessageFromJson(Map<String, dynamic> json) {
  return LoadFilesMessage(
      fileDatas: (json['fileDatas'] as List)
          ?.map((e) => e as Map<String, dynamic>)
          ?.toList());
}

Map<String, dynamic> _$LoadFilesMessageToJson(LoadFilesMessage instance) =>
    <String, dynamic>{'fileDatas': instance.fileDatas};
