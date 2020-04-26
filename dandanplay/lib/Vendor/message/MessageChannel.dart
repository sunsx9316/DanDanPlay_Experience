import 'package:dandanplay/Model/Message/Receive/BaseReceiveMessage.dart';
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:dandanplay/Model/MessageChannelResponse.dart';
import 'package:flutter/services.dart';

abstract class MessageChannelObserver {
  void didReceiveMessage(
      BaseReceiveMessage messageData, BasicMessageChannel channel);
}

class MessageChannel {
  static final shared = MessageChannel();
  final channel =
      BasicMessageChannel("com.dandanplay.native/message", JSONMessageCodec());
  final _observers = Set<MessageChannelObserver>();
  var _initMessageHandler = false;

  Future<MessageChannelResponse> sendMessage(BaseMessage message) async {
    var map = Map<String, dynamic>();
    map["name"] = message.name;
    map["data"] = message.data;
    final result = await channel.send(map);
    return MessageChannelResponse(result);
  }

  void addObserve(MessageChannelObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }

    if (_initMessageHandler == false) {
      channel.setMessageHandler((message) {
        if (message is Map) {
          Map<String, dynamic> aMap = message;

          final msgData = BaseReceiveMessage();
          msgData.name = aMap["name"];
          msgData.data = aMap["data"];
          for (final item in _observers) {
            item.didReceiveMessage(msgData, this.channel);
          }
        }

        return null;
      });
      _initMessageHandler = true;
    }
  }

  void removeObserve(MessageChannelObserver observer) {
    if (_observers.contains(observer)) {
      _observers.remove(observer);
    }
  }
}
