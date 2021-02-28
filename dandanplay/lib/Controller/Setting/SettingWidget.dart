import 'dart:io';

import 'package:dandanplay/Controller/HomePage/DesktopHomePageWidget.dart';
import 'package:dandanplay/Tools/Preferences.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:dandanplay/Vendor/file_picker/dandanplayfilepicker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum _SettingCellType {
  faseMatch,
  autoLoadCustomDanmaku,
  subtitleProtectlArea,
  showHomePageTips,
  danmakuCacheTime,
  homePageBackGround,
  autoCheckVersion,
  reset,
}

class SettingWidget extends StatefulWidget {
  @override
  SettingWidgetState createState() {
    return SettingWidgetState();
  }
}

class SettingWidgetState extends State<SettingWidget> {
  var _fastMatch = true;
  var _subtitleSafeArea = true;
  var _showHomePageTips = true;
  var _danmakuCacheDay = 0;
  var _checkUpdate = false;
  var _requestDidFinish = false;
  var _autoLoadCustomDanmaku = false;
  var _dataSource = List<_SettingCellType>.empty(growable: true);

  @override
  void initState() {
    super.initState();

    if (Platform.isIOS) {
      _dataSource = [
        _SettingCellType.faseMatch,
        _SettingCellType.autoLoadCustomDanmaku,
        _SettingCellType.subtitleProtectlArea,
        _SettingCellType.danmakuCacheTime,
        _SettingCellType.reset
      ];
    } else {
      _dataSource = [
        _SettingCellType.faseMatch,
        _SettingCellType.autoLoadCustomDanmaku,
        _SettingCellType.subtitleProtectlArea,
        _SettingCellType.showHomePageTips,
        _SettingCellType.danmakuCacheTime,
        _SettingCellType.homePageBackGround,
        _SettingCellType.autoCheckVersion,
        _SettingCellType.reset
      ];
    }

    _initValue();
  }

  @override
  Widget build(BuildContext context) {
    if (_requestDidFinish) {
      return Scaffold(
          appBar: AppBar(title: Text("设置")),
          body: ListView.builder(
              itemCount: _dataSource.length,
              itemBuilder: (context, index) {
                final style = _dataSource[index];

                switch (style) {
                  case _SettingCellType.faseMatch:
                    {
                      return _switchCell(
                          titleValue: "弹幕快速匹配",
                          subtitleValue: "自动识别视频，并匹配弹幕",
                          on: _fastMatch,
                          onChanged: (on) {
                            Preferences.shared.setFastMatch(on).then((value) {
                              setState(() {
                                _fastMatch = on;
                              });
                            });
                          });
                    }
                    break;
                  case _SettingCellType.autoLoadCustomDanmaku: {
                    return _switchCell(
                        titleValue: "自动加载同名“弹幕”文件",
                        subtitleValue: "目前支持 XML 格式",
                        on: _autoLoadCustomDanmaku,
                        onChanged: (on) {
                          Preferences.shared.setAutoLoadCusomDanmaku(on).then((value) {
                            setState(() {
                              _autoLoadCustomDanmaku = on;
                            });
                          });
                        });
                  }
                  break;
                  case _SettingCellType.subtitleProtectlArea:
                    {
                      return _switchCell(
                          titleValue: "字幕保护区域",
                          subtitleValue: "在画面底部大约15%的位置禁止弹幕出现",
                          on: _subtitleSafeArea,
                          onChanged: (on) {
                            Preferences.shared
                                .setSubtitleSafeArea(on)
                                .then((value) {
                              setState(() {
                                _subtitleSafeArea = on;
                              });
                            });
                          });
                    }
                    break;
                  case _SettingCellType.showHomePageTips:
                    {
                      return _switchCell(
                          titleValue: "显示首页拖拽播放提示文字",
                          subtitleValue: "就是 \"拖拽 视频/文件夹 到屏幕中开始播放\"这一串",
                          on: _showHomePageTips,
                          onChanged: (on) {
                            Preferences.shared
                                .setShowHomePageTips(on)
                                .then((value) {
                              setState(() {
                                _showHomePageTips = on;
                              });
                            });
                          });
                    }
                    break;
                  case _SettingCellType.danmakuCacheTime:
                    {
                      return InkWell(
                          child: _titleCell("弹幕缓存时间",
                              subtitleValue: "$_danmakuCacheDay天"),
                          onTap: () {
                            _showDanmakuCacheInputDialog(context);
                          });
                    }
                    break;
                  case _SettingCellType.homePageBackGround:
                    {
                      return Column(children: <Widget>[
                        InkWell(
                            child: _defaultInsetsCell(children: [
                              Expanded(
                                  child: Wrap(
                                      direction: Axis.vertical,
                                      children: <Widget>[
                                    Text(
                                      "设置首页背景...",
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ])),
                              MaterialButton(
                                color: GlobalConfig.mainColor,
                                highlightColor: Colors.orangeAccent,
                                colorBrightness: Brightness.dark,
                                splashColor: Colors.grey,
                                child: Text("恢复默认"),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0)),
                                onPressed: () {
                                  _resetHomePageBgImageToDefault();
                                },
                              )
                            ]),
                            onTap: () {
                              _getHomePageBgImage(context);
                            }),
                        _homePageThumb()
                      ]);
                    }
                    break;
                  case _SettingCellType.autoCheckVersion:
                    {
                      return _switchCell(
                          titleValue: "自动检查更新",
                          on: _checkUpdate,
                          onChanged: (on) {
                            Preferences.shared.setCheckUpdate(on).then((value) {
                              setState(() {
                                _checkUpdate = on;
                              });
                            });
                          });
                    }
                    break;
                  case _SettingCellType.reset:
                    {
                      return Column(children: <Widget>[
                        _defaultInsetsCell(children: [
                          Expanded(
                              child: Wrap(
                                  direction: Axis.vertical,
                                  children: <Widget>[
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "恢复默认设置",
                                        style: TextStyle(fontSize: 18),
                                      ),
                                      Text("出现问题可以尝试还原设置",
                                          style: TextStyle(color: Colors.grey))
                                    ])
                              ])),
                          MaterialButton(
                            color: GlobalConfig.mainColor,
                            highlightColor: Colors.orangeAccent,
                            colorBrightness: Brightness.dark,
                            splashColor: Colors.grey,
                            child: Text("一键重来"),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0)),
                            onPressed: () {
                              _resetToDefault();
                            },
                          )
                        ]),
                      ]);
                    }
                    break;
                }

                return Container();
              }));
    } else {
      return Scaffold(appBar: AppBar(title: Text("设置")), body: Container());
    }
  }

  //获取首页背景图
  void _getHomePageBgImage(BuildContext context) async {
    final paths = await Dandanplayfilepicker.getFiles(
        pickType: DandanplayfilepickerType.image);
    if (paths != null && paths.isNotEmpty) {
      await Preferences.shared.setHomePageBgImage(paths[0].path);
      setState(() {});
    }
  }

  void _resetHomePageBgImageToDefault() async {
    await Preferences.shared.setHomePageBgImage(null);
    setState(() {});
  }

  //初始化一些值
  void _initValue() async {

    _fastMatch = await Preferences.shared.fastMatch;
    _subtitleSafeArea = await Preferences.shared.subtitleSafeArea;
    _danmakuCacheDay = await Preferences.shared.danmakuCacheDay;
    _showHomePageTips = await Preferences.shared.showHomePageTips;
    _checkUpdate = await Preferences.shared.checkUpdate;
    _autoLoadCustomDanmaku = await Preferences.shared.autoLoadCusomDanmaku;
    setState(() {
      _requestDidFinish = true;
    });
  }

  //生成按钮
  Widget _switchCell(
      {String titleValue,
      bool on,
      String subtitleValue,
      ValueChanged<bool> onChanged}) {
    var expandedChildren = List<Widget>.empty(growable: true);
    expandedChildren.add(Text(
      titleValue,
      style: TextStyle(fontSize: 18),
    ));

    if (subtitleValue != null) {
      expandedChildren
          .add(Text(subtitleValue, style: TextStyle(color: Colors.grey)));
    }

    return _defaultInsetsCell(children: [
      Expanded(
          child: Wrap(direction: Axis.vertical, children: expandedChildren)),
      Switch(value: on, onChanged: onChanged)
    ]);
  }

  Widget _titleCell(String titleValue, {String subtitleValue}) {
    return _defaultInsetsCell(children: [
      Expanded(
          child: Wrap(direction: Axis.vertical, children: <Widget>[
        Text(
          titleValue,
          style: TextStyle(fontSize: 18),
        ),
      ])),
      Text(
        subtitleValue ?? "",
        style: TextStyle(fontSize: 18),
      )
    ]);
  }

  Widget _defaultInsetsCell({@required List<Widget> children}) {
    return Padding(
        padding: EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 10),
        child: Row(children: children));
  }

  Widget _homePageThumb() {
    return Stack(children: <Widget>[
      Container(
          child: DesktopHomePageWidget(isPreView: true),
          height: 320,
          padding: EdgeInsets.only(top: 40, left: 40, right: 40, bottom: 20)),
      Positioned(
        left: 20,
        top: 10,
        child: Text("预览效果："),
      )
    ]);
  }

  void _showDanmakuCacheInputDialog(BuildContext context) {
    showDialog<void>(
        context: context,
        builder: (context) {
          TextField inputTextField = TextField(
              autofocus: true,
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: "$_danmakuCacheDay"));

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
              MaterialButton(
                child: Text('取消'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              MaterialButton(
                child: Text('确认'),
                onPressed: () {
                  if (inputTextField != null) {
                    try {
                      final day = int.parse(inputTextField.controller.text);
                      Preferences.shared.setDanmakuCacheDay(day).then((value) {
                        setState(() {
                          _danmakuCacheDay = day;
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

  void _resetToDefault() async {
    await Preferences.shared.setupDefaultValue(force: true);
    _initValue();
  }
}
