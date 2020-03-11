import 'package:dandanplay/Model/BaseModel.dart';
import 'package:json_annotation/json_annotation.dart';

part 'HomePageBanner.g.dart';

@JsonSerializable()
class HomePageBanner extends BaseModel {

  HomePageBanner(this.title, this.description, this.url, this.imageUrl);

  String title;
  String description;
  String url;
  String imageUrl;

  factory HomePageBanner.fromJson(Map<String, dynamic> json) {
    return _$HomePageBannerFromJson(json);
  }

  Map<String, dynamic> toJson() {
    return _$HomePageBannerToJson(this);
  }
}