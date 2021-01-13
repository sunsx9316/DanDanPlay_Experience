import 'dart:io';

import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/Message/Send/NaviBackMessage.dart';
import 'package:dandanplay/Model/Message/Send/InputDanmakuMessage.dart';
import 'package:dandanplay/Tools/Preferences.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class SendDanmakuWidget extends StatefulWidget {
  @override
  _SendDanmakuWidgetState createState() {
    return _SendDanmakuWidgetState();
  }
}

class _SendDanmakuWidgetState extends State {

  Color _currentColor = Colors.white;
  DanmakuMode _danmakuMode = DanmakuMode.normal;

  @override
  void initState() {
    super.initState();
    setupInit();
  }

  void setupInit() async {
    _currentColor = await Preferences.shared.sendDanmakuColor;
    _danmakuMode = await Preferences.shared.sendDanmakuType;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {

    bool autofocus;

    if (Platform.isIOS) {
      autofocus = false;
    } else {
      autofocus = true;
    }

    return Scaffold(
        appBar: AppBar(
          title: Text("发送弹幕"),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () {
              final msg = NaviBackMessage();
              MessageChannel.shared.sendMessage(msg);
            },
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.settings, color: Colors.black),
              onPressed: () {
                _showColorPicker(context);
              },
            )
          ],
        ),
        body: Padding(
            padding: EdgeInsets.all(10),
            child: TextField(
              cursorColor: Colors.white,
              style: TextStyle(color: _currentColor),
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              autofocus: autofocus,
              decoration: InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: "发送内容……"),
              onSubmitted: (str) {
                final msg = InputDanmakuMessage(message: str);
                MessageChannel.shared.sendMessage(msg);
              },
            )));
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            titlePadding: const EdgeInsets.all(0.0),
            contentPadding: const EdgeInsets.all(0.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25.0),
            ),
            content: SingleChildScrollView(
              padding: EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SlidePicker(
                    pickerColor: _currentColor,
                    onColorChanged: changeColor,
                    paletteType: PaletteType.rgb,
                    enableAlpha: false,
                    displayThumbColor: true,
                    showLabel: false,
                    showIndicator: true
                  ),
                  SizedBox(
                      width: 300,
                      child: CupertinoSegmentedControl(
                        children: {
                          DanmakuMode.normal: Text("滚动"),
                          DanmakuMode.top: Text("顶部"),
                          DanmakuMode.bottom: Text("底部")
                        },
                        onValueChanged: (value) {
                          setState(() {
                            _danmakuMode = value;
                            Preferences.shared
                                .setSendDanmakuType(_danmakuMode);
                          });
                        },
                        groupValue: _danmakuMode,
                      ))
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void changeColor(Color color) {
    setState(() {
      _currentColor = color;
      Preferences.shared.setSendDanmakuColor(_currentColor);
    });
  }
}
