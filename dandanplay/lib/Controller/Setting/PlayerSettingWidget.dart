import 'dart:io';

import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/Message/Send/LoadCustomDanmakuMessage.dart';
import 'package:dandanplay/Tools/Preferences.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:dandanplayfilepicker/dandanplayfilepicker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _DanmakuCellType {
  fontSize,
  speed,
  alpha,
  count,
  danmakuSwitch,
  local,
}

class PlayerSettingWidget extends StatefulWidget {
  @override
  PlayerSettingWidgetState createState() {
    return PlayerSettingWidgetState();
  }
}

class PlayerSettingWidgetState extends State<PlayerSettingWidget> {
  double _danmakuFontSize = 18;
  double _danmakuSpeed = 1;
  double _danmakuAlpha = 1;
  double _danmakuMaxCount = 100;
  double _playerSpeed = 1.0;
  PlayerMode _playerMode;
  bool _danmakuOpen = false;

  bool _didGetInitValue = false;

  List<_DanmakuCellType> _cellTypes =
      List<_DanmakuCellType>.empty(growable: true);

  @override
  void initState() {
    super.initState();
    _getInitValue();
  }

  @override
  Widget build(BuildContext context) {
    if (!_didGetInitValue) {
      return Container();
    }

    return DefaultTabController(
        length: 2,
        child: Scaffold(
            appBar: TabBar(
                indicatorColor: GlobalConfig.mainColor,
                labelColor: Colors.white,
                tabs: <Widget>[Tab(text: "播放器设置"), Tab(text: "弹幕设置")],
                indicatorPadding: EdgeInsets.only(left: 30, right: 30)),
            body: TabBarView(children: [
              _createPlayerSettingWidget(),
              _createDanmakuSettingWidget()
            ])));
  }

  //初始化数据
  void _getInitValue() async {
    _danmakuFontSize = await Preferences.shared.danmakuFontSize;
    _danmakuSpeed = await Preferences.shared.danmakuSpeed;
    _danmakuAlpha = await Preferences.shared.danmakuAlpha;
    final danmakuCount = await Preferences.shared.danmakuCount;
    _danmakuMaxCount = danmakuCount.toDouble();
    _playerSpeed = await Preferences.shared.playerSpeed;
    _playerMode = await Preferences.shared.playerMode;
    _danmakuOpen = await Preferences.shared.showDanmaku;

    if (Platform.isIOS) {
      _cellTypes = [
        _DanmakuCellType.fontSize,
        _DanmakuCellType.speed,
        _DanmakuCellType.alpha,
        _DanmakuCellType.count,
        _DanmakuCellType.danmakuSwitch,
        _DanmakuCellType.local
      ];
    } else {
      _cellTypes = [
        _DanmakuCellType.fontSize,
        _DanmakuCellType.speed,
        _DanmakuCellType.alpha,
        _DanmakuCellType.count,
        _DanmakuCellType.local
      ];
    }

    setState(() {
      _didGetInitValue = true;
    });
  }

  Widget _createSliderCell(String title, double min, double max, double value,
      ValueChanged<double> onChanged,
      {String minString,
      String maxString,
      int divisions = 1,
      String label,
      Color maxValueColor}) {
    assert(value >= min && value <= max, "值不符合规范 $title, $min $value $max");

    return SafeArea(
        child: Padding(
            padding: EdgeInsets.all(10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title),
                  Row(children: <Widget>[
                    Text(minString ?? "$min"),
                    Expanded(
                        child: Slider(
                            value: value,
                            min: min,
                            max: max,
                            label: label ?? "$value",
                            divisions: divisions,
                            onChanged: (value) {
                              final format = NumberFormat();
                              format.minimumFractionDigits = 0;
                              format.maximumFractionDigits = 2;
                              final formatValue = format.format(value);
                              var doubleValue = double.parse(formatValue);
                              onChanged(doubleValue);
                            })),
                    Text(maxString ?? "$max",
                        style: maxValueColor != null
                            ? TextStyle(color: maxValueColor)
                            : null)
                  ])
                ])));
  }

  Widget _createPlayerSettingWidget() {
    return ListView.builder(
        itemCount: 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _createSliderCell("播放速度", 0.5, 2, _playerSpeed, (value) {
              setState(() {
                _playerSpeed = value;
                Preferences.shared.setPlayerSpeed(value);
              });
            }, divisions: 15);
          } else if (index == 1) {
            return SafeArea(
                child: InkWell(
                    child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Row(children: [
                          Expanded(child: Text("播放模式")),
                          Text(_playerModeTypeDesc(_playerMode))
                        ])),
                    onTap: () {
                      _onTapPlayerMode(context);
                    }));
          }
          return Container();
        });
  }

  Widget _createDanmakuSettingWidget() {
    return ListView.builder(
        itemCount: _cellTypes.length,
        itemBuilder: (context, index) {
          final cellType = _cellTypes[index];

          switch (cellType) {
            case _DanmakuCellType.fontSize:
              {
                double danmakuFontMinSize = 18;
                if (Platform.isIOS) {
                  danmakuFontMinSize = 10;
                }

                double danmakuFontMacSize = 32;

                final divisions =
                    (danmakuFontMacSize - danmakuFontMinSize).toInt();
                return _createSliderCell(
                    "弹幕字体大小", danmakuFontMinSize, 32, _danmakuFontSize,
                    (value) {
                  setState(() {
                    _danmakuFontSize = value;
                    Preferences.shared.setDanmakuFontSize(value);
                  });
                },
                    minString: "$danmakuFontMinSize",
                    maxString: "$danmakuFontMacSize",
                    divisions: divisions);
              }
              break;
            case _DanmakuCellType.speed:
              {
                double maxValue = 3;
                final isMaxValue = _danmakuSpeed == maxValue;
                return _createSliderCell("弹幕速度", 1, maxValue, _danmakuSpeed,
                    (value) {
                  setState(() {
                    _danmakuSpeed = value;
                    Preferences.shared.setDanmakuSpeed(value);
                  });
                },
                    divisions: 20,
                    maxValueColor: isMaxValue ? Colors.red : null);
              }
              break;
            case _DanmakuCellType.alpha:
              {
                return _createSliderCell("弹幕透明度", 0, 1, _danmakuAlpha, (value) {
                  setState(() {
                    _danmakuAlpha = value;
                    Preferences.shared.setDanmakuAlpha(value);
                  });
                }, divisions: 10);
              }
              break;
            case _DanmakuCellType.count:
              {
                double max = 100;
                final isMaxValue = _danmakuMaxCount == max;
                return _createSliderCell("同屏弹幕数", 10, max, _danmakuMaxCount,
                    (value) {
                  setState(() {
                    _danmakuMaxCount = value;
                    Preferences.shared.setDanmakuCount(value.toInt());
                  });
                },
                    divisions: 18,
                    label: isMaxValue ? "∞" : "$_danmakuMaxCount",
                    maxString: "∞");
              }
              break;
            case _DanmakuCellType.danmakuSwitch:
              {
                return SafeArea(
                    child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Row(children: [
                          Expanded(child: Text("弹幕开关")),
                          // Text(_playerModeTypeDesc(_playerMode))
                          Switch(
                              value: _danmakuOpen,
                              activeColor: GlobalConfig.mainColor,
                              onChanged: (on) {
                                setState(() {
                                  _danmakuOpen = on;
                                  Preferences.shared.setShowDanmaku(on);
                                });
                              })
                        ])));
              }
              break;
            case _DanmakuCellType.local:
              {
                return SafeArea(
                    child: InkWell(
                        child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Expanded(child: Text("加载本地弹幕..."))),
                        onTap: () {
                          _onTapLocalDanmaku(context);
                        }));
              }
              break;
            default:
              return Container();
          }
        });
  }

  String _playerModeTypeDesc(PlayerMode mode) {
    switch (mode) {
      case PlayerMode.notRepeat:
        return "不循环";
      case PlayerMode.repeatCurrentItem:
        return "单集循环";
      case PlayerMode.repeatAllItem:
        return "列表循环";
      default:
        return "";
    }
  }

  void _onTapLocalDanmaku(BuildContext context) async {
    final msg = LoadCustomDanmakuMessage();
    MessageChannel.shared.sendMessage(msg);
  }

  void _onTapPlayerMode(BuildContext context) {
    showDialog<void>(
        context: context,
        builder: (context) {
          PlayerMode tmpMode = _playerMode;

          return AlertDialog(
            title: Text('设置播放模式...'),
            content: StatefulBuilder(builder: (context, setState) {
              final children = List<Widget>.empty(growable: true);

              for (PlayerMode mode in PlayerMode.values) {
                Widget text = Text(_playerModeTypeDesc(mode));
                if (mode == tmpMode) {
                  text = Row(children: <Widget>[
                    Expanded(child: text),
                    Icon(Icons.check_circle,
                        color: GlobalConfig.mainColor, size: 20)
                  ], mainAxisSize: MainAxisSize.min);
                }

                children.add(InkWell(
                    child: Padding(
                        padding: EdgeInsets.only(left: 10, top: 5, bottom: 5),
                        child: text),
                    onTap: () {
                      setState(() {
                        tmpMode = mode;
                      });
                    }));
              }

              return SingleChildScrollView(
                child: ListBody(children: children),
              );
            }),
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
                  setState(() {
                    _playerMode = tmpMode;
                    Preferences.shared.setPlayerMode(_playerMode);
                    Navigator.of(context).pop();
                  });
                },
              ),
            ],
          );
        });
  }
}
