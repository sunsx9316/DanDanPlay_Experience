
import 'package:dandanplay/Model/Message/Send/BaseMessage.dart';
import 'package:dandanplay/Model/MessageChannelResponse.dart';
import 'package:flutter/services.dart';

abstract class MessageChannelObserver {
  void didReceiveMessage(dynamic data, BasicMessageChannel channel);
}

class MessageChannel {
  static final shared = MessageChannel();
  final channel = BasicMessageChannel("com.dandanplay.native/message", JSONMessageCodec());
//  final _observers = List<MessageChannelObserver>();

//  MessageChannel() {
//    channel.setMessageHandler((message) {
//      for (var item in _observers) {
//        item.didReceiveMessage(message, this.channel);
//      }
//      return;
//    });
//  }

  Future<MessageChannelResponse> sendMessage(BaseMessage message) async {
    var map = Map<String, dynamic>();
    map["name"] = message.name;
    map["data"] = message.data;
    final result = await channel.send(map);
    return MessageChannelResponse(result);
  }

//  void addObserve(MessageChannelObserver observer) {
//    if (!_observers.contains(observer)) {
//      _observers.add(observer);
//    }
//  }
//
//  void removeObserve(MessageChannelObserver observer) {
//    if (_observers.contains(observer)) {
//      _observers.remove(observer);
//    }
//  }

}