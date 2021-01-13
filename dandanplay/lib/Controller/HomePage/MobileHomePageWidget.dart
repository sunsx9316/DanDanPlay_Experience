import 'dart:ffi';
import 'dart:io';

import 'package:dandanplay/Controller/File/FileWidget.dart';
import 'package:dandanplay/Controller/Match/MatchWidget.dart';
import 'package:dandanplay/Controller/Mine/MineWidget.dart';
import 'package:dandanplay/Model/Message/Receive/BaseReceiveMessage.dart';
import 'package:dandanplay/Model/Message/Receive/ParseFileMessage.dart';
import 'package:dandanplay/Model/Message/Receive/ReloadMatchWidgetMessage.dart';
import 'package:dandanplay/Model/Message/Receive/SendDanmakuMessage.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:dandanplay/r.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info/package_info.dart';

class MobileHomePageWidget extends StatefulWidget {
  @override
  MobileHomePageState createState() {
    return MobileHomePageState();
  }
}

class MobileHomePageState extends State<MobileHomePageWidget> with MessageChannelObserver {
  var _selectedIndex = 0;
  String _appName = "";

  void _getInitValue() async {
    final packageInfo = await PackageInfo.fromPlatform();
    _appName = packageInfo.appName ?? "";

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _getInitValue();
  }

  @override
  void dispose() {
    MessageChannel.shared.removeObserve(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MessageChannel.shared.addObserve(this);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    Widget appBar;
    
    if (_selectedIndex == 0) {
      body = FileWidget();
      appBar = AppBar(
        title: Text(_appName),
      );
    } else if (_selectedIndex == 1) {
      body = MineWidget();
      appBar = AppBar(
        title: Text(_appName)
      );
    }

    return Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: Container(
            decoration: BoxDecoration(color: Colors.white, boxShadow: [
              BoxShadow(
                color: Colors.black,
              ),
            ]),
            child: BottomNavigationBar(
              items: [
                BottomNavigationBarItem(
                    icon: Image.asset(R.assetsImagesMainTabbarFile),
                    label: "文件",
                    activeIcon: Image.asset(R.assetsImagesMainTabbarFile,
                        color: GlobalConfig.mainColor)),
                BottomNavigationBarItem(
                    icon: Image.asset(R.assetsImagesMainMine),
                    label: "我的",
                    activeIcon: Image.asset(R.assetsImagesMainMine,
                        color: GlobalConfig.mainColor))
              ],
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            )));
  }

  @override
  void didReceiveMessage(
      BaseReceiveMessage messageData, BasicMessageChannel channel) {
    if (messageData.name == "ParseFileMessage") {
      final message = ParseFileMessage.fromJson(messageData.data);
      Tools.parseMessage(message, failedCallBack: (mediaId, collection) {
        if (Platform.isIOS) {
          final msg = ReloadMatchWidgetMessage.fromParseData(mediaId: mediaId, collection: collection);
          MessageChannel.shared.sendMessage(msg);
        } else {
          Navigator.push(this.context, MaterialPageRoute(builder: (context) {
            return MatchWidget.fromCollection(
                mediaId: mediaId, collection: collection);
          }));
        }
      });
    } else if (messageData.name == "SendDanmakuMessage") {
      final message = SendDanmakuMessage.fromJsonMap(messageData.data);
      Tools.sendDanmaku(message);
    }
  }
}
