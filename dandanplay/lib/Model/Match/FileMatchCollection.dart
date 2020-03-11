
import 'package:dandanplay/Model/BaseModel.dart';
import 'package:dandanplay/Model/Match/FileMatch.dart';
import 'package:json_annotation/json_annotation.dart';

part 'FileMatchCollection.g.dart';

@JsonSerializable()
class FileMatchCollection extends BaseModelCollection {

  /* 是否已精确关联到某个弹幕库  */
  bool isMatched;
  List<FileMatch> matches;

  FileMatchCollection(this.isMatched, this.matches);

  factory FileMatchCollection.fromJson(Map<String, dynamic> json) {
    return _$FileMatchCollectionFromJson(json);
  }

  Map<String, dynamic> toJson() {
    return _$FileMatchCollectionToJson(this);
  }
}