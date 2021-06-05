
import 'package:dandanplay/Model/BaseModel.dart';
import 'package:json_annotation/json_annotation.dart';

part 'SetInitialRouteMessage.g.dart';

@JsonSerializable()
class SetInitialRouteMessage extends BaseModel {
  String routeName;
  Map<String, dynamic> parameters;

  SetInitialRouteMessage(this.routeName);

  factory SetInitialRouteMessage.fromJson(Map<String, dynamic> json) {
    return _$SetInitialRouteMessageFromJson(json);
  }

  Map<String, dynamic> toJson() {
    return _$SetInitialRouteMessageToJson(this);
  }
}