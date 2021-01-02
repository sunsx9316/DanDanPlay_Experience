import 'package:dandanplay/NetworkManager/AuthNetWorkManager.dart';
import 'package:dandanplay/Tools/Preferences.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LoginWidget extends StatefulWidget {
  @override
  _LoginWidgetState createState() {
    return _LoginWidgetState();
  }
}

class _LoginWidgetState extends State<LoginWidget> {
  final userNameTextFieldController = TextEditingController();
  final passwordTextFieldController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("登录")),
        body: Builder(builder: (context) {
          return Column(
            children: <Widget>[
              Container(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: TextField(
                    controller: userNameTextFieldController,
                    style: TextStyle(fontSize: 20),
                    cursorColor: Colors.white,
                    autofocus: true,
                    decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person),
                        enabledBorder: UnderlineInputBorder(),
                        hintText: "用户名"),
                  ),
                  width: double.infinity,
                  height: 60),
              Container(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: TextField(
                    controller: passwordTextFieldController,
                    style: TextStyle(fontSize: 20),
                    cursorColor: Colors.white,
                    obscureText: true,
                    decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock),
                        enabledBorder: UnderlineInputBorder(),
                        hintText: "密码"),
                  ),
                  width: double.infinity,
                  height: 60),
              Container(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: Row(children: [
                    FlatButton(
                        child: Text("忘记密码", style: TextStyle(fontSize: 16)),
                        onPressed: () {
                          Navigator.pushNamed(context, "forgetPassword");
                        }),
                    Expanded(
                        child: Row(
                      children: [
                        FlatButton(
                            child: Text("没有账号？去注册",
                                style: TextStyle(fontSize: 16)),
                            onPressed: () {
                              Navigator.pushNamed(context, "register");
                            })
                      ],
                      mainAxisAlignment: MainAxisAlignment.end,
                    ))
                  ])),
              Container(
                padding: EdgeInsets.only(top: 20, bottom: 20),
                child: FlatButton(
                  color: GlobalConfig.mainColor,
                  highlightColor: Colors.orangeAccent,
                  colorBrightness: Brightness.dark,
                  splashColor: Colors.grey,
                  child: Text("登录"),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0)),
                  onPressed: () {
                    final userName = userNameTextFieldController.text;
                    final password = passwordTextFieldController.text;

                    _login(userName, password, context);
                  },
                ),
                width: 300,
                height: 80,
              )
            ],
          );
        }));
  }

  void _login(String userName, String password, BuildContext context) async {
    if (userName == null || userName.isEmpty) {
      Tools.showSnackBar("请输入用户名！", context);
      return;
    }

    if (password == null || password.isEmpty) {
      Tools.showSnackBar("请输入密码！", context);
      return;
    }

    final result =
        await AuthNetWorkManager.login(userName: userName, password: password);
    if (result.error != null) {
      Tools.showSnackBar(result.error.message, context);
    } else {
      await Preferences.shared.setUser(result.data);
      Navigator.pop(context);
    }

  }
}
