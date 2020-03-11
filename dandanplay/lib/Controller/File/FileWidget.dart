import 'package:dandanplay/Controller/BaseNavigation.dart';
import 'package:dandanplay/Controller/Match/MatchWidget.dart';
import 'package:dandanplay/Model/File/FileModel.dart';
import 'package:dandanplay/NetworkManager/MatchNetworkManager.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:dandanplay/r.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FileWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.all(10),
        child: GridView(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10),
            children: <Widget>[
              Material(
                  color: Colors.lightBlue,
                  child: InkWell(
                      onTap: () {
                        _onTapLocalFile(context);
                      },
                      child: Container(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                            Image.asset(R.assetsImagesFileFilePhone,
                                color: Colors.white),
                            Padding(padding: EdgeInsets.only(top: 10)),
                            Text("本机视频",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 20))
                          ])))),
              Material(
                  color: Colors.orange,
                  child: InkWell(
                      onTap: () {},
                      child: Container(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                            Image.asset(R.assetsImagesFileFileNetEquipment,
                                color: Colors.white),
                            Padding(padding: EdgeInsets.only(top: 10)),
                            Text("局域网设备",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 20))
                          ])))),
              Material(
                  color: Colors.green,
                  child: InkWell(
                      onTap: () {},
                      child: Container(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                            Image.asset(R.assetsImagesFileFileComputer,
                                color: Colors.white),
                            Padding(padding: EdgeInsets.only(top: 10)),
                            Text("连接电脑版",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 20))
                          ]))))
            ]));
  }

  /* 点击本地文件 */
  void _onTapLocalFile(BuildContext context) async {
    try {
      final file = await FilePicker.getFile();
      if (file != null) {
//        Tools.parse(file, context: context);
      }
    } catch (e) {
      print("error $e");
    }
  }
}
