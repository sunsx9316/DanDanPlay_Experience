import 'dart:io';
import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Controller/File/FileListWidget.dart';
import 'package:dandanplay/Controller/HomePage/DesktopHomePageWidget.dart';
import 'package:dandanplay/Controller/HomePage/MobileHomePageWidget.dart';
import 'package:dandanplay/Controller/Login/ForgetPasswordWidget.dart';
import 'package:dandanplay/Controller/Login/LoginWidget.dart';
import 'package:dandanplay/Controller/Login/RegisterWidget.dart';
import 'package:dandanplay/Controller/Match/MatchWidget.dart';
import 'package:dandanplay/Controller/Mine/AboutUsWidget.dart';
import 'package:dandanplay/Controller/Player/SendDanmakuWidget.dart';
import 'package:dandanplay/Controller/Setting/PlayerSettingWidget.dart';
import 'package:dandanplay/Controller/Setting/SettingWidget.dart';
import 'package:dandanplay/Mediator/LocalFileMediator.dart';
import 'package:dandanplay/Mediator/WebDavFileMediator.dart';
import 'package:dandanplay/Model/Message/Receive/BaseReceiveMessage.dart';
import 'package:dandanplay/Model/Message/Receive/RequestAppVersionMessage.dart';
import 'package:dandanplay/Model/Message/Receive/SetInitialRouteMessage.dart';
import 'package:dandanplay/Model/Message/Send/AppVersionMessage.dart';
import 'package:dandanplay/NetworkManager/CheckVersionNetworkManager.dart';
import 'package:dandanplay/Tools/Preferences.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webdav_client/webdav_client.dart';

void main() => runApp(App());

class App extends StatefulWidget {
  static final routeObserver = RouteObserver<PageRoute>();

  @override
  AppState createState() {
    return AppState();
  }
}

class AppState extends State<App> with MessageChannelObserver {
  var _initRoute = "/";
  Map<String, dynamic> _initRouteParameters;

  @override
  void initState() {
    super.initState();
    _setupDefaultValue();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MessageChannel.shared.addObserve(this);
  }

  @override
  void dispose() {
    super.dispose();
    MessageChannel.shared.removeObserve(this);
  }

  @override
  Widget build(BuildContext context) {
    Widget home;

    if (Platform.isIOS) {
      home = MobileHomePageWidget();
    } else {
      home = DesktopHomePageWidget();
    }

    return GestureDetector(
        onTap: () {
          FocusScopeNode currentFocus = FocusScope.of(context);

          if (!currentFocus.hasPrimaryFocus) {
            currentFocus.unfocus();
          }
        },
        child: MaterialApp(
            title: 'AniXPlayer',
            theme: ThemeData(
                brightness: Brightness.dark,
                sliderTheme: SliderThemeData(
                    valueIndicatorTextStyle: TextStyle(color: Colors.white),
                    activeTickMarkColor: Colors.deepOrangeAccent),
                primarySwatch: Colors.orange,
                toggleableActiveColor: GlobalConfig.mainColor,
                primaryColor: GlobalConfig.mainColor,
                accentColor: GlobalConfig.mainColor,
                inputDecorationTheme: InputDecorationTheme(
                    focusedBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: GlobalConfig.mainColor)))),
            home: home,
            initialRoute: _initRoute,
            navigatorObservers: [
              App.routeObserver
            ],
            routes: {
              "setting": (context) {
                return SettingWidget();
              },
              "playerSetting": (context) {
                return PlayerSettingWidget();
              },
              "login": (context) {
                return LoginWidget();
              },
              "forgetPassword": (context) {
                return ForgetPasswordWidget();
              },
              "register": (context) {
                return RegisterWidget();
              },
              "sendDanmaku": (context) {
                return SendDanmakuWidget();
              },
              "aboutUs": (context) {
                return AboutUsWidget();
              },
              "match": (context) {
                return MatchWidget();
              },
              "localFiles": (context) {
                String path;
                FileFilterType filterType = FileFilterType.none;

                if (_initRouteParameters != null) {
                  path = _initRouteParameters["path"];
                  final filterTypeRawValue = _initRouteParameters["filterType"];
                  if (filterTypeRawValue is num) {
                    filterType = FileFilterTypeWithRawValue(filterTypeRawValue);
                  }
                } else {
                  path = "";
                }

                return FileListWidget(mediator: LocalFileMediator(), path: path, filterType: filterType);
              },
              "webDavFiles": (context) {

                String user;
                String pwd;
                String path;
                FileFilterType filterType = FileFilterType.none;

                if (_initRouteParameters != null) {
                  user = _initRouteParameters["user"];
                  pwd = _initRouteParameters["pwd"];
                  path = _initRouteParameters["path"];
                  final filterTypeRawValue = _initRouteParameters["filterType"];
                  if (filterTypeRawValue is num) {
                    filterType = FileFilterTypeWithRawValue(filterTypeRawValue);
                  }
                } else {
                  user = "";
                  pwd = "";
                  path = "";
                }

                final mediator = WebDavFileMediator(auth: Auth(user: user, pwd: pwd));
                return FileListWidget(mediator: mediator, path: path, filterType: filterType);
              },
            }));
  }

  @override
  void didReceiveMessage(
      BaseReceiveMessage messageData, BasicMessageChannel channel) {
    if (messageData.name == "SetInitialRouteMessage") {
      final message = SetInitialRouteMessage.fromJson(messageData.data);
      setState(() {
        _initRoute = message.routeName ?? "/";
        _initRouteParameters = message.parameters;
      });
    } else if (messageData.name == "RequestAppVersionMessage") {
      final msg = RequestAppVersionMessage.fromJson(messageData.data);
      _requestAppVersion(msg.byManual);
    }
  }

  void _setupDefaultValue() async {
    await Preferences.shared.setupDefaultValue();
    setState(() {});
  }

  //请求最新版本信息
  void _requestAppVersion(bool byManual) async {
    final res = await CheckVersionNetworkManager.checkNewVersion();
    MessageChannel.shared.sendMessage(AppVersionMessage(res, byManual));
  }
}
