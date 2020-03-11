
import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/BaseModel.dart';
import 'package:dandanplay/Model/Search/SearchEpisode.dart';
import 'package:json_annotation/json_annotation.dart';

part 'SearchAnimate.g.dart';

@JsonSerializable()
class SearchAnimate extends BaseModelCollection {

	num animeId;
	String animeTitle;

	AnimateType get type {
		return animateTypeWithString(typeRawValue);
	}

	@JsonKey(name: "type")
	String typeRawValue;
	String typeDescription;
	List<SearchEpisode> episodes;

	SearchAnimate(this.animeId, this.animeTitle, this.typeRawValue, this.typeDescription, this.episodes);


	factory SearchAnimate.fromJson(Map<String, dynamic> map) {
		return _$SearchAnimateFromJson(map);
	}

	Map<String, dynamic> toJson() {
		return _$SearchAnimateToJson(this);
	}
}
