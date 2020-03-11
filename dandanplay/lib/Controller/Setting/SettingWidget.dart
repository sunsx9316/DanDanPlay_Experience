import 'package:dandanplay/NetworkManager/HomePageNetworkManager.dart';
import 'package:dandanplay/Tools/Preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SettingWidget extends StatefulWidget {
  @override
  SettingWidgetState createState() {
    return SettingWidgetState();
  }
}

class SettingWidgetState extends State<SettingWidget> {
  var fastMatch = true;
  var subtitleSafeArea = true;
  var danmakuCacheDay = 0;
  var didFinish = false;

  @override
  void initState() {
    super.initState();
    _initValue();
  }

  @override
  Widget build(BuildContext context) {
    if (didFinish) {
      return Scaffold(
          appBar: AppBar(title: Text("设置")),
          body: ListView.builder(
              itemCount: 3,
              itemExtent: 60,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _switchCell("弹幕快速匹配", "自动识别视频，并匹配弹幕", fastMatch,
                      onChanged: (on) {
                    Preferences.shared.setFastMatch(on).then((value) {
                      setState(() {
                        fastMatch = on;
                      });
                    });
                  });
                } else if (index == 1) {
                  return _switchCell(
                      "字幕保护区域", "在画面底部大约15%的位置禁止弹幕出现", subtitleSafeArea,
                      onChanged: (on) {
                    Preferences.shared.setSubtitleSafeArea(on).then((value) {
                      setState(() {
                        subtitleSafeArea = on;
                      });
                    });
                  });
                } else if (index == 2) {
                  return InkWell(
                      child: _titleCell("弹幕缓存时间", "$danmakuCacheDay天"),
                      onTap: () {
                        _showDanmakuCacheInputDialog(context);
                      });
                }
                return _switchCell("弹幕快速匹配", "自动识别视频，并匹配弹幕", true);
              }));
    } else {
      return Scaffold(appBar: AppBar(title: Text("设置")), body: Container());
    }
  }

  //初始化一些值
  void _initValue() async {
    fastMatch = await Preferences.shared.fastMatch;
    subtitleSafeArea = await Preferences.shared.subtitleSafeArea;
    danmakuCacheDay = await Preferences.shared.danmakuCacheDay;
    setState(() {
      didFinish = true;
    });
  }

  //生成按钮
  Widget _switchCell(String titleValue, String subtitleValue, bool on,
      {ValueChanged<bool> onChanged}) {
    return Padding(
        padding: EdgeInsets.only(left: 10, right: 10),
        child: Row(children: <Widget>[
          Expanded(
              child: Wrap(direction: Axis.vertical, children: <Widget>[
            Text(
              titleValue,
              style: TextStyle(fontSize: 18),
            ),
            Text(subtitleValue, style: TextStyle(color: Colors.grey))
          ])),
          Switch(value: on, onChanged: onChanged)
        ]));
  }

  Widget _titleCell(String titleValue, String subtitleValue) {
    return Padding(
        padding: EdgeInsets.only(left: 10, right: 10),
        child: Row(children: <Widget>[
          Expanded(
              child: Wrap(direction: Axis.vertical, children: <Widget>[
            Text(
              titleValue,
              style: TextStyle(fontSize: 18),
            ),
          ])),
          Text(
            subtitleValue,
            style: TextStyle(fontSize: 18),
          )
        ]));
  }

  void _showDanmakuCacheInputDialog(BuildContext context) {
    showDialog<void>(
        context: context,
        builder: (context) {
          TextField inputTextField = TextField(
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: "$danmakuCacheDay"));

          return AlertDialog(
            title: Text('设置弹幕缓存有效期'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text('默认7天'),
                  inputTextField,
                ],
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
                  if (inputTextField != null) {
                    try {
                      final day = int.parse(inputTextField.controller.text);
                      Preferences.shared.setDanmakuCacheDay(day).then((value) {
                        setState(() {
                          danmakuCacheDay = day;
                          Navigator.of(context).pop();
                        });
                      });
                    } catch (e) {
                      print(e);
                    }
                  }
                },
              ),
            ],
          );
        });
  }
}
