import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/BaseModel.dart';
import 'package:json_annotation/json_annotation.dart';

part 'FileMatch.g.dart';

@JsonSerializable()
class FileMatch extends BaseModel {
  num episodeId = 0;

  num animeId = 0;
  String animeTitle = "";
  String episodeTitle = "";

  // 弹幕偏移时间（弹幕应延迟多少秒出现）。此数字为负数时表示弹幕应提前多少秒出现。
  num shift = 0.0;

  @JsonKey(ignore: true)
  String get title {
    return "$animeTitle - $episodeTitle";
  }

  // 作品类别
  @JsonKey(name: "type")
  String typeRawValue = "";
  String typeDescription = "";

  AnimateType get type {
    return animateTypeWithString(typeRawValue);
  }

  FileMatch(this.episodeId, this.animeId, this.animeTitle, this.episodeTitle,
      this.typeRawValue, this.typeDescription, this.shift);

  factory FileMatch.fromJson(Map<String, dynamic> json) {
    return _$FileMatchFromJson(json);
  }

  Map<String, dynamic> toJson() {
    return _$FileMatchToJson(this);
  }
}
