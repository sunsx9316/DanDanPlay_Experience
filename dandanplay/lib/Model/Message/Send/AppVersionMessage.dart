
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:dandanplay/Model/Update/AppVersion.dart';

class AppVersionMessage extends BaseMessage {

  AppVersion _message;
  bool _byManual = false;

  AppVersionMessage(this._message, this._byManual);

  @override
  Map<String, dynamic> get data {
    Map<String, dynamic> data = _message.toJson();
    data["byManual"] = this._byManual;
    return data;
  }

}