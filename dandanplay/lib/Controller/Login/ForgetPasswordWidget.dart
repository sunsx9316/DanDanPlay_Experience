import 'package:dandanplay/Model/Login/User.dart';
import 'package:dandanplay/NetworkManager/AuthNetWorkManager.dart';
import 'package:dandanplay/Tools/Preferences.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:flutter/material.dart';

class ForgetPasswordWidget extends StatefulWidget {
  @override
  _ForgetPasswordWidgetState createState() {
    return _ForgetPasswordWidgetState();
  }
}

class _ForgetPasswordWidgetState extends State<ForgetPasswordWidget> {
  User _user;

  @override
  Widget build(BuildContext context) {

    String userName = "";
    if (_user != null && _user.userName != null) {
      userName = _user.userName;
    }

    final userNameTextFieldController = TextEditingController(text: userName);
    final emailTextFieldController = TextEditingController();

    return Scaffold(
        appBar: AppBar(title: Text("重置密码")),
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
                    keyboardType: TextInputType.emailAddress,
                    controller: emailTextFieldController,
                    style: TextStyle(fontSize: 20),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock),
                        enabledBorder: UnderlineInputBorder(),
                        hintText: "邮箱"),
                    onSubmitted: (str) {},
                  ),
                  width: double.infinity,
                  height: 60),
              Container(
                padding: EdgeInsets.only(top: 20, bottom: 20),
                child: MaterialButton(
                  color: GlobalConfig.mainColor,
                  highlightColor: Colors.orangeAccent,
                  colorBrightness: Brightness.dark,
                  splashColor: Colors.grey,
                  child: Text("提交"),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0)),
                  onPressed: () {
                    final userName = userNameTextFieldController.text;
                    final email = emailTextFieldController.text;

                    _submit(userName, email, context);
                  },
                ),
                width: 300,
                height: 80,
              )
            ],
          );
        }));
  }

  @override
  void initState() {
    super.initState();
    _initValue();
  }

  void _initValue() async {
    _user = await Preferences.shared.user;
    setState(() {});
  }

  void _submit(String userName, String email, BuildContext context) async {
    if (userName == null || userName.isEmpty) {
      Tools.showSnackBar("请输入用户名！", context);
      return;
    }

    if (email == null || email.isEmpty) {
      Tools.showSnackBar("请输入邮箱！", context);
      return;
    }

    final result = await AuthNetWorkManager.resetPassword(
        userName: userName, email: email);

    if (result.error != null) {
      Tools.showSnackBar(result.error.message, context);
    } else {
      Tools.showSnackBar("密码重置成功，请登录邮箱查看！", context);
    }
  }
}
