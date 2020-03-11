
import 'package:dandanplay/Model/BaseModel.dart';
import 'package:json_annotation/json_annotation.dart';

part 'Danmaku.g.dart';

@JsonSerializable()
class Danmaku extends BaseModel {

	int cid;
	String p;
	String m;

	Danmaku(this.cid, this.p, this.m);

	factory Danmaku.fromJsonMap(Map<String, dynamic> map) {
		return _$DanmakuFromJson(map);
	}

	Map<String, dynamic> toJson() {
		return _$DanmakuToJson(this);
	}
}
