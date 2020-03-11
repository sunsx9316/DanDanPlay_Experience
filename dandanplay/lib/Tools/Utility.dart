import 'dart:io';
import 'package:dandanplay/Controller/BaseNavigation.dart';
import 'package:dandanplay/Controller/Match/MatchWidget.dart';
import 'package:dandanplay/Controller/Search/SearchWidget.dart';
import 'package:dandanplay/Model/Message/Receive/ParseFileMessage.dart';
import 'package:dandanplay/Model/Message/Send/HUDMessage.dart';
import 'package:dandanplay/Model/Message/Send/LoadDanmakuMessage.dart';
import 'package:dandanplay/Model/Search/SearchEpisode.dart';
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
  static void parseMessage(ParseFileMessage message, BuildContext context) async {
    _showProgressHUD("解析视频...", 0.2);

    final res = await MatchNetworkManager.match(message);
    final mediaId = message.mediaId;
    final data = res.data;

    final openFastMatch = await Preferences.shared.fastMatch;

    //精确关联
    if (data.isMatched && data.matches.length == 1 && openFastMatch) {
      _showProgressHUD("解析视频成功，开始匹配弹幕...", 0.5);
      final matched = data.matches[0];
      await getDanmaku(mediaId, episodeId: matched.episodeId, title: matched.title);
      _showProgressHUD("弹幕匹配成功，开始播放...", 1.0);
      _dismissProgressHUD();
    } else {
      _dismissProgressHUD();
      if (context != null) {
        Navigator.push(context, MaterialPageRoute(builder: (context) {
          return MatchWidget.fromCollection(mediaId: mediaId, collection: res.data);
        }));
      }
    }
  }


//  static void parse(File file, {BuildContext context}) async {
//    _showProgressHUD("解析视频...", 0.2);
//
//    final fileModel = FileModel(file);
//    final res = await MatchNetworkManager.match(fileModel);
//
//    final data = res.data;
//    data.isMatched = false;
//    //精确关联
//    if (data.isMatched && data.matches.length == 1) {
//      _showProgressHUD("解析视频成功，开始匹配弹幕...", 0.5);
//      final matched = data.matches[0];
//      await exactMatch(file, episodeId: matched.episodeId);
//      _showProgressHUD("弹幕匹配成功，开始播放...", 1.0);
//      _dismissProgressHUD();
//    } else {
//      _dismissProgressHUD();
//      if (context != null) {
//      Navigator.push(context, MaterialPageRoute(builder: (context) {
//        return MatchWidget.fromCollection(file: file, collection: res.data);
////          BaseNavigation(
////            body: MatchWidget.fromCollection(
////                path: file.path, collection: res.data),
////            titleBar: TextField(
////              style: TextStyle(
////                fontSize: 15.0,
////              ),
////              decoration: InputDecoration(
////                hintText: "试试手动♂搜索",
////                border: OutlineInputBorder(
////                    borderSide: BorderSide(color: Colors.transparent)),
////              ),
////              onSubmitted: (text) {
////                _showSearchWidget(context, text, file.path);
////              },
////            ));
//      }));
//
//      }
//
////      if (matched != null) {
////        _showProgressHUD("开始匹配弹幕...", 0.5);
////        await exactMatch(file, episodeId: matched.episodeId);
////        _showProgressHUD("弹幕匹配成功，开始播放...", 1.0);
////        _dismissProgressHUD();
////      } else {
////        exactMatch(file);
////      }
//    }
//  }

  static Future getDanmaku(String mediaId, {int episodeId, String title}) async {
    LoadDanmakuMessage message;
    if (episodeId != null) {
      _showProgressHUD("开始匹配弹幕...", 0.5);
      final result = await CommentNetworkManager.danmaku(episodeId);
      message = LoadDanmakuMessage(mediaId, danmakuCollection: result.data, title: title);
      _showProgressHUD("弹幕匹配成功，开始播放...", 1.0);
      _dismissProgressHUD();
    } else {
      message = LoadDanmakuMessage(mediaId);
    }

    MessageChannel.shared.sendMessage(message);
  }

  //精确匹配
//  static Future exactMatch(File file, {int episodeId}) async {
//    StartPlayMessage message;
//    if (episodeId != null) {
//      _showProgressHUD("开始匹配弹幕...", 0.5);
//      final danmaku = await CommentNetworkManager.danmaku(episodeId);
//      message = StartPlayMessage(file.path, danmaku: danmaku.data);
//      _showProgressHUD("弹幕匹配成功，开始播放...", 1.0);
//      _dismissProgressHUD();
//    } else {
//      message = StartPlayMessage(file.path);
//    }
//
//    MessageChannel.shared.sendMessage(message);
//  }

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

  //显示搜索
//  static void _showSearchWidget(
//      BuildContext context, String text, String path) async {
//    _dismissProgressHUD();
//
//    final episode = await Navigator.push<SearchEpisode>(context,
//        MaterialPageRoute(builder: (context) {
//      return BaseNavigation(
//          body: SearchWidget(path: path, searchText: text),
//          titleBar: TextField(
//            style: TextStyle(
//              fontSize: 15.0,
//            ),
//            decoration: InputDecoration(
//              hintText: "试试手动♂搜索",
//              border: OutlineInputBorder(
//                  borderSide: BorderSide(color: Colors.transparent)),
//            ),
//            onSubmitted: (text1) {
//              _showSearchWidget(context, text1, path);
//            },
//          ));
//    }));
//
//    if (episode != null) {
//      StartPlayMessage message;
//      final danmaku = await CommentNetworkManager.danmaku(episode.episodeId);
//      message = StartPlayMessage(path, danmaku: danmaku.data);
//      MessageChannel.shared.sendMessage(message);
//    }
//  }
}
