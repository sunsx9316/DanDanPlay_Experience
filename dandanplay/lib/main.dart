import 'dart:io';

import 'package:dandanplay/Controller/File/FileWidget.dart';
import 'package:dandanplay/Controller/Setting/PlayerSettingWidget.dart';
import 'package:dandanplay/Controller/Setting/SettingWidget.dart';
import 'package:dandanplay/Model/Message/Receive/ParseFileMessage.dart';
import 'package:dandanplay/Model/Message/Receive/SetInitialRouteMessage.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(App());

class App extends StatefulWidget {
  @override
  MyAppState createState() {
    return MyAppState();
  }
}

class MyAppState extends State<App> {
  final _channel =
      BasicMessageChannel("com.dandanplay.native/message", JSONMessageCodec());

  @override
  void initState() {
    super.initState();

    _channel.setMessageHandler((message) {
      _didReceiveMessage(message);
      return;
    });
  }

  void _didReceiveMessage(data) {
    Map<String, dynamic> aMap = data;

    final name = aMap["name"] as String;
    final messageData = aMap["data"];

    if (name == "ParseFileMessage") {
      final message = ParseFileMessage.fromJson(messageData);
      Tools.parseMessage(message, context);
    } else if (name == "SetInitialRouteMessage") {
      final message = SetInitialRouteMessage.fromJson(messageData);
      setState(() {
        _initRoute = message.routeName ?? "/";
      });
    }
  }

  var _initRoute = "/";

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          FocusScopeNode currentFocus = FocusScope.of(context);

          if (!currentFocus.hasPrimaryFocus) {
            currentFocus.unfocus();
          }
        },
        child: MaterialApp(
            title: 'Flutter Demo',
            theme: ThemeData(
                sliderTheme: SliderThemeData(valueIndicatorTextStyle: TextStyle(
                    color: Colors.white), activeTickMarkColor: Colors.deepOrangeAccent),
                primarySwatch: Colors.orange,
                primaryColor: GlobalConfig.mainColor),
            home: MyHomePage(title: 'Flutter Demo Home Page'),
            initialRoute: _initRoute,
            routes: {
              "setting": (context) {
                return SettingWidget();
              },
              "playerSetting": (context) {
                return PlayerSettingWidget();
              }
            }));
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
//  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (Platform.isMacOS) {
      return Scaffold(
          body: Stack(children: <Widget>[
//        Image.file(File("/Users/jimhuang/Desktop/225803-15824698839cdf.jpg"),
//            fit: BoxFit.cover),
        GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, "setting");
            },
            child: Center(
                child: Text("拖拽 视频/文件夹 到这里开始播放",
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                              blurRadius: 8,
                              color: Colors.black,
                              offset: Offset(0, 1))
                        ]))))
      ], fit: StackFit.expand));
    } else {
      return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
          ),
          body: FileWidget());
    }

//    Widget body;
//
//    if (_selectedIndex == 0) {
//      body = Column(children: [
//        SizedBox(height: 130, child: HomePageWidget()),
//        Expanded(
//            child: ListView(
//          physics: AlwaysScrollableScrollPhysics(),
//          shrinkWrap: true,
//          padding: const EdgeInsets.all(20.0),
//          children: <Widget>[
//            const Text('I\'m dedicating every day to you'),
//            const Text('Domestic life was never quite my style'),
//            const Text('When you smile, you knock me out, I fall apart'),
//            const Text('And I thought I was so smart'),
//          ],
//        ))
//      ]);
//    } else if (_selectedIndex == 1) {
//      body = FileWidget();
//    }
//
//    return Scaffold(
//        appBar: AppBar(
//          title: Text(widget.title),
//        ),
//        body: body,
//        bottomNavigationBar: BottomNavigationBar(
//          items: [
//            BottomNavigationBarItem(
//                title: Text("首页"),
//                icon: Image.asset(R.assetsImagesMainBangumi),
//                activeIcon: Image.asset(R.assetsImagesMainBangumi,
//                    color: GlobalConfig.mainColor)),
//            BottomNavigationBarItem(
//                title: Text("看番"),
//                icon: Image.asset(R.assetsImagesMainTabbarFile),
//                activeIcon: Image.asset(R.assetsImagesMainTabbarFile,
//                    color: GlobalConfig.mainColor)),
//            BottomNavigationBarItem(
//                title: Text("我的"),
//                icon: Image.asset(R.assetsImagesMainMine),
//                activeIcon: Image.asset(R.assetsImagesMainMine,
//                    color: GlobalConfig.mainColor))
//          ],
//          currentIndex: _selectedIndex,
//          onTap: (index) {
//            setState(() {
//              _selectedIndex = index;
//            });
//          },
//        ));
  }
}
