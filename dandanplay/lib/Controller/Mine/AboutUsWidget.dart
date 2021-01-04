import 'dart:ffi';

import 'package:dandanplay/r.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info/package_info.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutUsWidget extends StatefulWidget {
  @override
  _AboutUsWidgetState createState() {
    return _AboutUsWidgetState();
  }
}

class _AboutUsWidgetState extends State {
  String _appName = "";

  @override
  void initState() {
    super.initState();
    _getInitValue();
  }

  @override
  Widget build(BuildContext context) {
    Widget icon = Image.asset(R.assetsImagesMineIcon);

    return Scaffold(
        appBar: AppBar(
          title: Text("关于" + _appName),
        ),
        body: Column(children: [
          SizedBox.fromSize(child: icon, size: Size(double.infinity, 220)),
          _createListTitle("开源代码", _openSourceLink),
          _createListTitle("联系我们", _homwPageLink)
        ]));
  }

  void _getInitValue() async {
    final packageInfo = await PackageInfo.fromPlatform();
    _appName = packageInfo.appName ?? "";

    setState(() {});
  }

  Widget _createListTitle(String title, GestureTapCallback onTap) {
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

  void _openSourceLink() async {
    final url = "https://github.com/sunsx9316/DanDanPlay_Experience";
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _homwPageLink() async {
    final url = "http://www.dandanplay.com/contact.html";
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

}
