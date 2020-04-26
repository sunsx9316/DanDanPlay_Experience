// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AppVersion.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppVersion _$AppVersionFromJson(Map<String, dynamic> json) {
  return AppVersion(
      url: json['url'] as String,
      version: json['version'] as String,
      shortVersion: json['shortVersion'] as String,
      desc: json['desc'] as String,
      hash: json['hash'] as String,
      forceUpdate: json['forceUpdate'] as bool);
}

Map<String, dynamic> _$AppVersionToJson(AppVersion instance) =>
    <String, dynamic>{
      'url': instance.url,
      'version': instance.version,
      'shortVersion': instance.shortVersion,
      'desc': instance.desc,
      'hash': instance.hash,
      'forceUpdate': instance.forceUpdate
    };
