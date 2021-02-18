// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'RequestAppVersionMessage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestAppVersionMessage _$RequestAppVersionMessageFromJson(
    Map<String, dynamic> json) {
  return RequestAppVersionMessage(
    json['byManual'] as bool,
  )
    ..data = json['data'] as Map<String, dynamic>
    ..name = json['name'] as String;
}

Map<String, dynamic> _$RequestAppVersionMessageToJson(
        RequestAppVersionMessage instance) =>
    <String, dynamic>{
      'data': instance.data,
      'name': instance.name,
      'byManual': instance.byManual,
    };
