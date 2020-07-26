import 'package:dandanplay/Model/Login/User.dart';
import 'package:dandanplay/Model/Match/FileMatchCollection.dart';
import 'package:dandanplay/Model/Message/Receive/ParseFileMessage.dart';
import 'package:dandanplay/Model/Message/Receive/SendDanmakuMessage.dart';
import 'package:dandanplay/Model/Message/Send/HUDMessage.dart';
import 'package:dandanplay/Model/Message/Send/LoadDanmakuMessage.dart';
import 'package:dandanplay/NetworkManager/AuthNetWorkManager.dart';
import 'package:dandanplay/NetworkManager/CommentNetworkManager.dart';
import 'package:dandanplay/NetworkManager/MatchNetworkManager.dart';
import 'package:dandanplay/Tools/Preferences.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:flutter/material.dart';

class GlobalConfig {
  static MaterialColor get mainColor {
    return Colors.orange;
  }
}

class Tools {
  static void parseMessage(ParseFileMessage message,
      {Function(String mediaId, FileMatchCollection collection)
          failedCallBack}) async {
    _showProgressHUD("解析视频...", 0.2);

    final res = await MatchNetworkManager.match(message);
    final mediaId = message.mediaId;
    final data = res.data;

    final openFastMatch = await Preferences.shared.fastMatch;

    //精确关联
    if (data.isMatched && data.matches.length == 1 && openFastMatch) {
      _showProgressHUD("解析视频成功，开始匹配弹幕...", 0.5);
      final matched = data.matches[0];
      await getDanmaku(mediaId,
          episodeId: matched.episodeId, title: matched.title);
      _showProgressHUD("弹幕匹配成功，开始播放...", 1.0);
      _dismissProgressHUD();
    } else {
      _dismissProgressHUD();
      if (failedCallBack != null) {
        failedCallBack(mediaId, data);
      }
    }
  }

  static Future getDanmaku(String mediaId,
      {int episodeId, String title}) async {
    LoadDanmakuMessage message;
    if (episodeId != null) {
      _showProgressHUD("开始匹配弹幕...", 0.5);
      final result = await CommentNetworkManager.danmaku(episodeId);
      message = LoadDanmakuMessage(mediaId: mediaId,
          danmakuCollection: result.data, title: title, episodeId: episodeId);
      _showProgressHUD("弹幕匹配成功，开始播放...", 1.0);
      _dismissProgressHUD();
    } else {
      message = LoadDanmakuMessage(mediaId: mediaId, playImmediately: true);
    }

    MessageChannel.shared.sendMessage(message);
  }

  static showSnackBar(String text, BuildContext context) {
    if (text == null) {
      return;
    }

    Scaffold.of(context).hideCurrentSnackBar();
    final snackBar = SnackBar(
        content: Text(text, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.white30);
    Scaffold.of(context).showSnackBar(snackBar);
  }

  static sendDanmaku(SendDanmakuMessage msg) async {
    if (msg == null) {
      return;
    }

    final user = await Preferences.shared.user;
    if (user == null) {
      final message =
          HUDMessage(style: HUDMessageStyle.tips, text: "请先登录才能发送弹幕！");
      MessageChannel.shared.sendMessage(message);
      return;
    }

    final result = await CommentNetworkManager.sendDanmaku(
        time: msg.time,
        mode: msg.mode,
        color: msg.color,
        comment: msg.comment,
        episodeId: msg.episodeId);
    if (result.error != null) {
      final message =
          HUDMessage(style: HUDMessageStyle.tips, text: result.error.message);
      MessageChannel.shared.sendMessage(message);
    } else {
      final message = HUDMessage(style: HUDMessageStyle.tips, text: "发送成功");
      MessageChannel.shared.sendMessage(message);
    }
  }

  static void _showProgressHUD(String text, double progress) {
    HUDMessage message = HUDMessage(
        style: HUDMessageStyle.progress,
        text: text,
        progress: progress,
        key: "parse_file",
        isDismiss: false);
    MessageChannel.shared.sendMessage(message);
  }

  static void _dismissProgressHUD() {
    HUDMessage message = HUDMessage(
        style: HUDMessageStyle.progress, key: "parse_file", isDismiss: true);
    MessageChannel.shared.sendMessage(message);
  }

}
