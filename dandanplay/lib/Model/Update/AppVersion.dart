
import 'package:dandanplay/Model/BaseModel.dart';
import 'package:json_annotation/json_annotation.dart';

part 'AppVersion.g.dart';

@JsonSerializable()
class AppVersion extends BaseModel {
  String url = "";
  String version = "";
  String shortVersion = "";
  String desc = "";
  String hash = "";
  bool forceUpdate = false;

  factory AppVersion.fromJson(Map<String, dynamic> map) {
    return _$AppVersionFromJson(map);
  }

  Map<String, dynamic> toJson() {
    return _$AppVersionToJson(this);
  }

  AppVersion({this.url, this.version, this.shortVersion, this.desc, this.hash, this.forceUpdate});
}