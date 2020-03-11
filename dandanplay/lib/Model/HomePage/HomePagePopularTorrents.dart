import 'package:dandanplay/Model/BaseModel.dart';
import 'package:json_annotation/json_annotation.dart';

part 'HomePagePopularTorrents.g.dart';

@JsonSerializable()
class HomePagePopularTorrents extends BaseModel {

  String name;
  String magnet;
  int hot;

	HomePagePopularTorrents(this.name, this.magnet, this.hot);

	factory HomePagePopularTorrents.fromJson(Map<String, dynamic> json) {
		return _$HomePagePopularTorrentsFromJson(json);
	}

	Map<String, dynamic> toJson() {
		return _$HomePagePopularTorrentsToJson(this);
	}
}
