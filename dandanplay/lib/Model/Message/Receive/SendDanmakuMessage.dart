
import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/Message/Receive/BaseReceiveMessage.dart';

class SendDanmakuMessage extends BaseReceiveMessage {

  num time;
  DanmakuMode mode;
  int color;
  String comment;
	num episodeId;

	SendDanmakuMessage.fromJsonMap(Map<String, dynamic> map) {
		time = map["time"];
		mode = danmakuModeTypeWithRawValue(map["mode"]);
		color = map["color"];
		comment = map["comment"];
		episodeId = map["episodeId"];
	}


	Map<String, dynamic> toJson() {
		final Map<String, dynamic> data = new Map<String, dynamic>();
		data['time'] = time;
		data['mode'] = danmakuModeRawValueWithEnum(mode);
		data['color'] = color;
		data['comment'] = comment;
		data['episodeId'] = episodeId;
		return data;
	}

}
