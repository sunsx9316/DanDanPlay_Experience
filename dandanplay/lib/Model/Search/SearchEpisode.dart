
import 'package:dandanplay/Model/BaseModel.dart';
import 'package:json_annotation/json_annotation.dart';

part 'SearchEpisode.g.dart';

@JsonSerializable()
class SearchEpisode extends BaseModel {

  int episodeId;
  String episodeTitle;

	SearchEpisode(this.episodeId, this.episodeTitle);

	factory SearchEpisode.fromJson(Map<String, dynamic> map) {
	  return _$SearchEpisodeFromJson(map);
  }

	Map<String, dynamic> toJson() {
		return _$SearchEpisodeToJson(this);
	}
}
