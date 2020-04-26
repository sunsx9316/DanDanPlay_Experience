import 'package:dandanplay/NetworkManager/AuthNetWorkManager.dart';
import 'package:dandanplay/Tools/Preferences.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RegisterWidget extends StatefulWidget {
  @override
  _RegisterWidgetState createState() {
    return _RegisterWidgetState();
  }
}

class _RegisterWidgetState extends State<RegisterWidget> {
  @override
  Widget build(BuildContext context) {
    final userNameTextFieldController = TextEditingController();
    final passwordTextFieldController = TextEditingController();
    final nickNamFieldController = TextEditingController();
    final emailTextFieldController = TextEditingController();

    return Scaffold(
        appBar: AppBar(title: Text("注册")),
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
                        labelText: "用户账号",
                        hintText: "只能包含英文或数字，长度为5-20位，首位不能为数字。"),
                  ),
                  width: double.infinity),
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
                        labelText: "密码",
                        hintText: "长度为5到20位之间。"),
                  ),
                  width: double.infinity),
              Container(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: TextField(
                    controller: nickNamFieldController,
                    style: TextStyle(fontSize: 20),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person_outline),
                        enabledBorder: UnderlineInputBorder(),
                        hintText: "昵称"),
                  ),
                  width: double.infinity),
              Container(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: TextField(
                    keyboardType: TextInputType.emailAddress,
                    controller: emailTextFieldController,
                    style: TextStyle(fontSize: 20),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                        prefixIcon: Icon(Icons.email),
                        enabledBorder: UnderlineInputBorder(),
                        hintText: "邮箱"),
                  ),
                  width: double.infinity),
              Container(
                padding: EdgeInsets.only(top: 20, bottom: 20),
                child: FlatButton(
                  color: GlobalConfig.mainColor,
                  highlightColor: Colors.orangeAccent,
                  colorBrightness: Brightness.dark,
                  splashColor: Colors.grey,
                  child: Text("提交"),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0)),
                  onPressed: () {
                    final userName = userNameTextFieldController.text;
                    final password = passwordTextFieldController.text;
                    final nickName = nickNamFieldController.text;
                    final email = emailTextFieldController.text;

                    _submit(
                        userName: userName,
                        password: password,
                        email: email,
                        nickName: nickName,
                        context: context);
                  },
                ),
                width: 300,
                height: 80,
              )
            ],
          );
        }));
  }

  void _submit(
      {@required String userName,
      @required String password,
      @required String email,
      @required String nickName,
      @required BuildContext context}) async {
    if (userName == null || userName.isEmpty) {
      Tools.showSnackBar("用户账号不能为空！", context);
      return;
    }

    if (password == null || password.isEmpty) {
      Tools.showSnackBar("密码不能为空！", context);
      return;
    }

    if (nickName == null || nickName.isEmpty) {
      Tools.showSnackBar("昵称不能为空！", context);
      return;
    }

    if (email == null || email.isEmpty) {
      Tools.showSnackBar("邮箱不能为空！", context);
      return;
    }

    final result = await AuthNetWorkManager.register(
        userName: userName,
        password: password,
        email: email,
        screenName: nickName);

    if (result.error != null) {
      Tools.showSnackBar(result.error.message, context);
    } else {
      final user = result.data;
      await Preferences.shared.setUser(user);
      Navigator.pop(context);
    }
  }
}
