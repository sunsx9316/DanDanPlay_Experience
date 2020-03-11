import 'package:dandanplay/Model/BaseModel.dart';
import 'package:json_annotation/json_annotation.dart';

part 'HomePageBangumiSeasons.g.dart';

@JsonSerializable()
class HomePageBangumiSeasons extends BaseModel {

  int year;
  int month;
  String seasonName;

	HomePageBangumiSeasons(this.year, this.month, this.seasonName);

	factory HomePageBangumiSeasons.fromJson(Map<String, dynamic> json) {
		return _$HomePageBangumiSeasonsFromJson(json);
	}

	Map<String, dynamic> toJson() {
		return _$HomePageBangumiSeasonsToJson(this);
	}

}
