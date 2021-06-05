// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'SetInitialRouteMessage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetInitialRouteMessage _$SetInitialRouteMessageFromJson(
    Map<String, dynamic> json) {
  return SetInitialRouteMessage(
    json['routeName'] as String,
  )..parameters = json['parameters'] as Map<String, dynamic>;
}

Map<String, dynamic> _$SetInitialRouteMessageToJson(
        SetInitialRouteMessage instance) =>
    <String, dynamic>{
      'routeName': instance.routeName,
      'parameters': instance.parameters,
    };
