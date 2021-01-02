import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dandanplay/Model/Login/User.dart';
import 'package:dandanplay/Model/Message/Send/HUDMessage.dart';
import 'package:dandanplay/NetworkManager/AuthNetWorkManager.dart';
import 'package:dandanplay/Tools/Preferences.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:dandanplay/main.dart';
import 'package:dandanplay/r.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MineWidget extends StatefulWidget {
  @override
  MineWidgetState createState() {
    return MineWidgetState();
  }
}

class MineWidgetState extends State with RouteAware {
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
  void didPopNext() {
    super.didPopNext();
    _getInitValue(false);
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    App.routeObserver.subscribe(this, ModalRoute.of(context));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User>(
      future: Preferences.shared.user,
      builder: (context, snapshot) {
        // 请求已结束
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            // 请求失败，显示错误
            return Container();
          } else {
            final _user = snapshot.data;
            Widget icon;
            Widget title;
            if (_user != null && _user.profileImage != null) {
              final profileImage = _user.profileImage;
              icon = CachedNetworkImage(
                  imageUrl: profileImage,
                  placeholder: (context, url) {
                    return Image.asset(R.assetsImagesMineIcon);
                  });

              var titleList = List<Widget>();
              if (_user.screenName != null) {
                titleList.add(Text(_user.screenName));
              }

              if (_user.userName != null) {
                titleList.add(Text("@${_user.userName}",
                    style: TextStyle(color: Colors.white60, fontSize: 12)));
              }
              title = Column(
                children: titleList,
              );
            } else {
              icon = Image.asset(R.assetsImagesMineIcon);
              title = Text("点击登录");
            }

            return ListView(children: [
              GestureDetector(
                  child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 260),
                      child: ClipRect(
                          child: Stack(
                        alignment: Alignment.center,
                        fit: StackFit.expand,
                        children: <Widget>[
                          FittedBox(child: icon, fit: BoxFit.cover),
                          ClipRect(
                              child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                                  child: Container(
                                    color: Colors.black.withOpacity(0.6),
                                  ))),
                          Center(
                              child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.white.withAlpha(120),
                                        width: 5.0,
                                      ),
                                      borderRadius: BorderRadius.circular(40)),
                                  child: ClipOval(
                                      child: SizedBox(
                                          width: 80, height: 80, child: icon))),
                              title
                            ],
                          ))
                        ],
                      ))),
                  onTap: () {
                    _onTapUserIcon(_user);
                  }),
              _createListTile("关于弹弹play", () {})
            ]);
          }
        } else {
          // 请求未结束，显示loading
          return Container();
        }
      },
    );
  }

  void _getInitValue(bool isFirstGet) async {
    final _user = await Preferences.shared.user;

    //交换token
    if (isFirstGet && _user != null && _user.token != null) {
      final result = await AuthNetWorkManager.renew();
      final user = result.data;
      Preferences.shared.setUser(user);
    }
    setState(() {});
  }

  Widget _createListTile(String title, GestureTapCallback onTap) {
    return InkWell(
        child: Padding(
            padding: EdgeInsets.only(top: 10, left: 10, bottom: 10),
            child: Row(
              children: [
                Expanded(child: Text(title)),
                Icon(Icons.keyboard_arrow_right)
              ],
            )),
        onTap: onTap);
  }

  //点击用户头像
  void _onTapUserIcon(User user) {
    if (user != null) {
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
                      _showChangeProfileDialog(user);
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

  void _showChangeProfileDialog(User user) async {
    showDialog<void>(
        context: context,
        builder: (context) {
          final textField = TextField(
              autofocus: true,
              decoration: InputDecoration(hintText: "输入昵称"),
              controller: TextEditingController(text: user.screenName ?? ""));

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
                FlatButton(
                  child: Text('取消'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                FlatButton(
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
                FlatButton(
                  child: Text('取消'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                FlatButton(
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
      var user = await Preferences.shared.user;
      user.screenName = name;
      await Preferences.shared.setUser(user);
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
}
