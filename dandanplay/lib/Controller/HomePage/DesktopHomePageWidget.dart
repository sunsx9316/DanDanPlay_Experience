
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dandanplay/Controller/Match/MatchWidget.dart';
import 'package:dandanplay/Model/Login/User.dart';
import 'package:dandanplay/Model/Message/Receive/BaseReceiveMessage.dart';
import 'package:dandanplay/Model/Message/Receive/ParseFileMessage.dart';
import 'package:dandanplay/Model/Message/Receive/SendDanmakuMessage.dart';
import 'package:dandanplay/Model/Message/Send/BecomeKeyWindowMessage.dart';
import 'package:dandanplay/Model/Message/Send/HUDMessage.dart';
import 'package:dandanplay/NetworkManager/AuthNetWorkManager.dart';
import 'package:dandanplay/Tools/Preferences.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:dandanplay/r.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dandanplay/main.dart';
import 'package:flutter/services.dart';

class DesktopHomePageWidget extends StatefulWidget {
  DesktopHomePageWidget({Key key, this.title, this.isPreView = false}) : super(key: key);

  final String title;
  final bool isPreView;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<DesktopHomePageWidget>
    with RouteAware, MessageChannelObserver {
  String _bgImgPath;
  bool _showHomePageTips = false;
  User _user;

  @override
  void initState() {
    super.initState();
    _getInitValue(true);
  }

  @override
  void dispose() {
    App.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    App.routeObserver.subscribe(this, ModalRoute.of(context));
    MessageChannel.shared.addObserve(this);
  }

  @override
  void didUpdateWidget(DesktopHomePageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _getInitValue(false);
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _getInitValue(false);
  }

  @override
  Widget build(BuildContext context) {
    var stackChildren = List<Widget>.empty(growable: true);
    if (_bgImgPath != null) {
      final imgFile = File(_bgImgPath);
      if (imgFile.existsSync()) {
        stackChildren.add(Image.file(imgFile, fit: BoxFit.cover));
      } else {
        stackChildren.add(Container(color: Colors.black));
        stackChildren.add(Image.asset(R.assetsImagesHome));
      }
    }

    if (_showHomePageTips) {
      stackChildren.add(Positioned(
          right: 20,
          bottom: 20,
          child: Text("拖拽 视频/文件夹 到屏幕中开始播放",
              style: TextStyle(fontSize: 20, color: Colors.white, shadows: [
                Shadow(blurRadius: 8, color: Colors.black, offset: Offset(0, 1))
              ]))));
    }

    Widget icon;
    if (_user != null && _user.profileImage != null) {
      final profileImage = _user.profileImage;
      icon = CachedNetworkImage(
          imageUrl: profileImage,
          placeholder: (context, url) {
            return Icon(Icons.person, color: Colors.black54, size: 36);
          });
    } else {
      icon = Icon(Icons.person, color: Colors.black54, size: 36);
    }

    List<Widget> iconList = [
      ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Container(
            width: 50,
            height: 50,
            child: icon,
            color: Colors.white70,
          ))
    ];

    if (_user != null && _user.screenName != null) {
      iconList.add(Padding(
          padding: EdgeInsets.only(top: 5), child: Text(_user.screenName)));
    }

    stackChildren.add(Positioned(
      right: 20,
      top: 20,
      child: GestureDetector(
          child: Column(
            children: iconList,
          ),
          onTap: () {
            if (widget.isPreView == false) {
              _onTapUserIcon();
            }
          }),
    ));

    return Scaffold(body: Stack(children: stackChildren, fit: StackFit.expand));
  }

  void _getInitValue(bool isFirstGet) async {
    _bgImgPath = await Preferences.shared.homePageBgImage;
    _showHomePageTips = await Preferences.shared.showHomePageTips;
    _user = await Preferences.shared.user;

    //交换token
    if (isFirstGet &&
        !widget.isPreView &&
        _user != null &&
        _user.token != null) {
      final result = await AuthNetWorkManager.renew();
      final user = result.data;
      Preferences.shared.setUser(user);
      _user = user;
    }
    setState(() {});
  }

  //点击用户头像
  void _onTapUserIcon() {
    if (_user != null) {
      showModalBottomSheet(
          context: context,
          builder: (BuildContext bc) {
            return Container(
              child: Wrap(
                children: <Widget>[
                  ListTile(
                    leading: Icon(Icons.account_box),
                    title: Text('修改昵称'),
                    onTap: () {
                      Navigator.pop(context);
                      _showChangeProfileDialog();
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.security),
                    title: Text('修改密码'),
                    onTap: () {
                      Navigator.pop(context);
                      _showChangePasswordDialog();
                    },
                  ),
                  ListTile(
                      leading: Icon(Icons.keyboard_return),
                      title: Text('退出登录'),
                      onTap: () {
                        _logout();
                      }),
                ],
              ),
            );
          });
    } else {
      Navigator.pushNamed(context, "login");
    }
  }

  void _showChangeProfileDialog() async {
    showDialog<void>(
        context: context,
        builder: (context) {
          final textField = TextField(
              autofocus: true,
              decoration: InputDecoration(hintText: "输入昵称"),
              controller: TextEditingController(text: _user.screenName ?? ""));

          String errorText;

          return StatefulBuilder(builder: (context, setState) {
            List<Widget> children = [textField];

            if (errorText != null) {
              children.add(Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 10),
                  child: Text(errorText,
                      style: TextStyle(color: Colors.redAccent))));
            }

            return AlertDialog(
              title: Text('修改昵称'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: children,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('取消'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('确认'),
                  onPressed: () {
                    final name = textField.controller.text;

                    if (name == null || name.isEmpty) {
                      errorText = "请输入昵称！";
                      setState(() {});
                      return;
                    }

                    _confirmChangeName(name);
                  },
                ),
              ],
            );
          });
        });
  }

  void _showChangePasswordDialog() async {
    showDialog<void>(
        context: context,
        builder: (context) {
          final oldPasswordTextField = TextField(
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                  hintText: "输入原密码", prefixIcon: Icon(Icons.lock)),
              controller: TextEditingController());

          final newPasswordTextField = TextField(
              obscureText: true,
              decoration: InputDecoration(
                  hintText: "输入新密码", prefixIcon: Icon(Icons.lock)),
              controller: TextEditingController());

          final newPasswordConfirmTextField = TextField(
              obscureText: true,
              decoration: InputDecoration(
                  hintText: "确认新密码", prefixIcon: Icon(Icons.lock)),
              controller: TextEditingController());

          String errorText;

          return StatefulBuilder(builder: (context, setState) {
            List<Widget> children = [
              oldPasswordTextField,
              newPasswordTextField,
              newPasswordConfirmTextField
            ];

            if (errorText != null) {
              children.add(Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 10),
                  child: Text(errorText,
                      style: TextStyle(color: Colors.redAccent))));
            }

            return AlertDialog(
              title: Text('修改密码'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: children,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('取消'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('确认'),
                  onPressed: () {
                    final oldPassword = oldPasswordTextField.controller.text;
                    final newPassword = newPasswordTextField.controller.text;
                    final newPasswordConfirm =
                        newPasswordConfirmTextField.controller.text;

                    if (oldPassword == null || oldPassword.isEmpty) {
                      errorText = "请输入原密码！";
                      setState(() {});
                      return;
                    }

                    if (newPassword == null || newPassword.isEmpty) {
                      errorText = "请输入新密码！";
                      setState(() {});
                      return;
                    }

                    if (newPasswordConfirm != newPassword) {
                      errorText = "两次输入的新密码不一致！";
                      setState(() {});
                      return;
                    }

                    _confirmChangePassword(newPassword, oldPassword);
                  },
                ),
              ],
            );
          });
        });
  }

  //登出
  void _logout() async {
    await Preferences.shared.setUser(null);
    setState(() {
      _user = null;
      Navigator.pop(context);
    });
  }

  //改名
  void _confirmChangeName(String name) async {
    final result = await AuthNetWorkManager.profile(screenName: name);
    if (result.error != null) {
      final msg =
      HUDMessage(style: HUDMessageStyle.tips, text: result.error.message);
      MessageChannel.shared.sendMessage(msg);
    } else {
      _user.screenName = name;
      await Preferences.shared.setUser(_user);
      setState(() {
        Navigator.of(context).pop();
      });
    }
  }

  //请求修改密码
  void _confirmChangePassword(String newPassword, String oldPassword) async {
    final result = await AuthNetWorkManager.changePassword(
        oldPassword: oldPassword, newPassword: newPassword);
    if (result.error != null) {
      final msg =
      HUDMessage(style: HUDMessageStyle.tips, text: result.error.message);
      MessageChannel.shared.sendMessage(msg);
    } else {
      final msg = HUDMessage(style: HUDMessageStyle.tips, text: "修改成功！");
      MessageChannel.shared.sendMessage(msg);
      Navigator.of(context).pop();
    }
  }

  @override
  void didReceiveMessage(
      BaseReceiveMessage messageData, BasicMessageChannel channel) {
    if (messageData.name == "ParseFileMessage") {
      final message = ParseFileMessage.fromJson(messageData.data);
      Tools.parseMessage(message, failedCallBack: (mediaId, collection) {
        MessageChannel.shared.sendMessage(BecomeKeyWindowMessage());

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
