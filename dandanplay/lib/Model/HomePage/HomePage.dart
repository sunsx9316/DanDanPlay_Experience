import 'package:dandanplay/Model/HomePage/HomePagePopularTorrents.dart';
import 'package:dandanplay/Model/HomePage/HomePageShinBangumi.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:dandanplay/Model/BaseModel.dart';
import 'HomePageBanner.dart';

part 'HomePage.g.dart';

@JsonSerializable()
class HomePage extends BaseModel {

  HomePage(this.banners, this.shinBangumiList, this.popularTorrents);

  List<HomePageBanner> banners;
  List<HomePageShinBangumi> shinBangumiList;
  List<HomePagePopularTorrents> popularTorrents;

  factory HomePage.fromJson(Map<String, dynamic> json) {
    return _$HomePageFromJson(json);
  }

  Map<String, dynamic> toJson() {
    return _$HomePageToJson(this);
  }
}