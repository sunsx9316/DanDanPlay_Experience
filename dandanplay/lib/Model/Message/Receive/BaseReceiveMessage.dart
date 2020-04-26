
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';

class BaseReceiveMessage extends BaseMessage {
  @override
  Map<String, dynamic> data;

  @override
  String name;
}