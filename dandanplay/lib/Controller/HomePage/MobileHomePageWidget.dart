import 'package:dandanplay/Controller/Match/MatchWidget.dart';
import 'package:dandanplay/Model/Message/Receive/BaseReceiveMessage.dart';
import 'package:dandanplay/Model/Message/Receive/ParseFileMessage.dart';
import 'package:dandanplay/Model/Message/Receive/SendDanmakuMessage.dart';
import 'package:dandanplay/Model/Message/Send/LoadFilesMessage.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:dandanplay/r.dart';
import 'package:dandanplayfilepicker/dandanplayfilepicker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MobileHomePageWidget extends StatefulWidget {
  @override
  MobileHomePageState createState() {
    return MobileHomePageState();
  }
}

class MobileHomePageState extends State<MobileHomePageWidget> with MessageChannelObserver {
  var _selectedIndex = 0;

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

    if (_selectedIndex == 0) {
      body = ListView(
        children: <Widget>[
          _createListTile('本地视频', Icon(Icons.folder, size: 30), () {
            _onTapLocalFile(context);
          }),
          _createListTile('网络', Icon(Icons.device_hub, size: 30), () {})
        ],
      );
    } else if (_selectedIndex == 1) {
      body = Container();
    }

    return Scaffold(
        appBar: AppBar(
          title: Text("弹弹play"),
        ),
        body: body,
        bottomNavigationBar: BottomNavigationBar(
          items: [
//            BottomNavigationBarItem(
//                title: Text("首页"),
//                icon: Image.asset(R.assetsImagesMainBangumi),
//                activeIcon: Image.asset(R.assetsImagesMainBangumi,
//                    color: GlobalConfig.mainColor)),
            BottomNavigationBarItem(
                title: Text("文件"),
                icon: Image.asset(R.assetsImagesMainTabbarFile),
                activeIcon: Image.asset(R.assetsImagesMainTabbarFile,
                    color: GlobalConfig.mainColor)),
            BottomNavigationBarItem(
                title: Text("我的"),
                icon: Image.asset(R.assetsImagesMainMine),
                activeIcon: Image.asset(R.assetsImagesMainMine,
                    color: GlobalConfig.mainColor))
          ],
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        ));
  }

  Widget _createListTile(String title, Icon icon, GestureTapCallback onTap) {
    return InkWell(
        child: Padding(
            padding: EdgeInsets.only(top: 10, left: 10, bottom: 10),
            child: Row(
              children: [icon, SizedBox(width: 10), Text(title)],
            )),
        onTap: onTap);
  }

  /* 点击本地文件 */
  void _onTapLocalFile(BuildContext context) async {
    try {
      final file = await Dandanplayfilepicker.getFile(pickType: DandanplayfilepickerType.video);
      if (file != null) {
        final msg = LoadFilesMessage(paths: [file.path]);
        MessageChannel.shared.sendMessage(msg);
      }
    } catch (e) {
      print("error $e");
    }
  }

  @override
  void didReceiveMessage(
      BaseReceiveMessage messageData, BasicMessageChannel channel) {
    if (messageData.name == "ParseFileMessage") {
      final message = ParseFileMessage.fromJson(messageData.data);
      Tools.parseMessage(message, failedCallBack: (mediaId, collection) {
        Navigator.push(this.context, MaterialPageRoute(builder: (context) {
          return MatchWidget.fromCollection(
              mediaId: mediaId, collection: collection);
        }));
      });
    } else if (messageData.name == "SendDanmakuMessage") {
      final message = SendDanmakuMessage.fromJsonMap(messageData.data);
      Tools.sendDanmaku(message);
    }
  }
}
