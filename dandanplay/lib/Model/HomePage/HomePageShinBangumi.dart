import 'package:dandanplay/Model/BaseModel.dart';
import 'package:json_annotation/json_annotation.dart';

part 'HomePageShinBangumi.g.dart';

@JsonSerializable()
class HomePageShinBangumi extends BaseModel {
  int animeId;
  String animeTitle;
  String imageUrl;
  String searchKeyword;
  bool isOnAir;
  int airDay;
  bool isFavorited;
  bool isRestricted;
  double rating;

  HomePageShinBangumi(this.animeId, this.animeTitle, this.imageUrl,
      this.searchKeyword, this.isOnAir, this.airDay, this.isFavorited,
      this.isRestricted, this.rating);


  factory HomePageShinBangumi.fromJson(Map<String, dynamic> json) {
    return _$HomePageShinBangumiFromJson(json);
  }

  Map<String, dynamic> toJson() {
    return _$HomePageShinBangumiToJson(this);
  }
}
