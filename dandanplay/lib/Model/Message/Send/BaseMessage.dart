
import 'package:dandanplay/Model/BaseModel.dart';
import 'package:json_annotation/json_annotation.dart';

abstract class BaseMessage extends BaseModel {

  @JsonKey(ignore: true)
  String get name {
    return "${this.runtimeType}";
  }

  Map<String, dynamic> get data;
}