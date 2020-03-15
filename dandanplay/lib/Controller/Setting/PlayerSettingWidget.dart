import 'package:dandanplay/Tools/Preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PlayerSettingWidget extends StatefulWidget {
  @override
  PlayerSettingWidgetState createState() {
    return PlayerSettingWidgetState();
  }
}

class PlayerSettingWidgetState extends State<PlayerSettingWidget> {
  List<Widget> _widget = [];
  double _danmakuFontSize = 18;
  double _danmakuSpeed = 1;
  double _danmakuAlpha = 1;
  double _danmakuMaxCount = 100;

  bool _didGetInitValue = false;

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

    final danmakuSetting = ListView.builder(
        itemCount: 4,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _createSliderCell("弹幕字体大小", 18, 32, _danmakuFontSize,
                (value) {
              setState(() {
                _danmakuFontSize = value;
                Preferences.shared.setDanmakuFontSize(value);
              });
            }, minString: "18", maxString: "32", divisions: 14);
          } else if (index == 1) {
            double maxValue = 3;
            final isMaxValue = _danmakuSpeed == maxValue;
            return _createSliderCell("弹幕速度", 1, maxValue, _danmakuSpeed,
                (value) {
              setState(() {
                _danmakuSpeed = value;
                Preferences.shared.setDanmakuSpeed(value);
              });
            }, divisions: 20, maxValueColor: isMaxValue ? Colors.red : null);
          } else if (index == 2) {
            return _createSliderCell("弹幕透明度", 0, 1, _danmakuAlpha, (value) {
              setState(() {
                _danmakuAlpha = value;
                Preferences.shared.setDanmakuAlpha(value);
              });
            }, divisions: 10);
          } else if (index == 3) {
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
          return Container();
        });

    return DefaultTabController(
        length: 2,
        child: Scaffold(
            appBar: TabBar(
                tabs: <Widget>[Tab(text: "弹幕设置"), Tab(text: "播放器设置")],
                indicatorPadding: EdgeInsets.only(left: 30, right: 30)),
            body: TabBarView(
                children: [danmakuSetting, Container(color: Colors.orange)])));
  }

  //初始化数据
  void _getInitValue() async {
    _danmakuFontSize = await Preferences.shared.danmakuFontSize;
    _danmakuSpeed = await Preferences.shared.danmakuSpeed;
    _danmakuAlpha = await Preferences.shared.danmakuAlpha;
    final danmakuCount = await Preferences.shared.danmakuCount;
    _danmakuMaxCount = danmakuCount.toDouble();
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
    return Padding(
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
                        onChanged: onChanged)),
                Text(maxString ?? "$max",
                    style: TextStyle(color: maxValueColor ?? Colors.black))
              ])
            ]));
  }
}
