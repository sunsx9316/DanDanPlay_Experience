// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'LoadFilesMessage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoadFilesMessage _$LoadFilesMessageFromJson(Map<String, dynamic> json) {
  return LoadFilesMessage(
      paths: (json['paths'] as List)?.map((e) => e as String)?.toList());
}

Map<String, dynamic> _$LoadFilesMessageToJson(LoadFilesMessage instance) =>
    <String, dynamic>{'paths': instance.paths};
