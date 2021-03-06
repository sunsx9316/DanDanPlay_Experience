
import 'package:dandanplay/Controller/File/WebDavFileWidget.dart';
import 'package:dandanplay/Model/Message/Send/LoadFilesMessage.dart';
import 'package:dandanplay/Vendor/file_picker/dandanplayfilepicker.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:webdav_client/webdav_client.dart';
import 'package:dandanplay/Model//File/FileDataModel+Extension.dart';


class FileWidget extends StatefulWidget {
  @override
  _FileWidgetState createState() {
    return _FileWidgetState();
  }
}

class _FileWidgetState extends State<FileWidget> {

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              color: Colors.white38,
              iconSize: 130,
              icon: Icon(Icons.folder),
              onPressed: () {
                _onTapLocalFile(context);
              }),
          Text("点击选取视频播放", style: TextStyle(fontSize: 16, color: Colors.white38)),
        ]));

    // return ListView(
    //   children: <Widget>[
    //     _createListTile('本地视频', Icon(Icons.folder, size: 30), () {
    //       _onTapLocalFile(context);
    //     }),
    //     _createListTile('WebDav', Icon(Icons.device_hub, size: 30), () {
    //       _onTapWevDav(context);
    //     })
    //   ],
    // );
  }

  Widget _createListTile(String title, Icon icon, GestureTapCallback onTap) {
    return InkWell(
        child: Padding(
            padding: EdgeInsets.only(top: 10, left: 10, bottom: 10),
            child: Row(
              children: [icon, SizedBox(width: 10), Text(title)],
            )),
        onTap: onTap);
  }

  /* 点击本地文件 */
  void _onTapLocalFile(BuildContext context) async {
    try {
      final files = await Dandanplayfilepicker.getFiles(
          pickType: DandanplayfilepickerType.file);
      if (files != null) {
        final arr = List<FileModelProtocol>.empty(growable: true);

        for (final file in files) {
          final obj = file.createProtocolObj();
          arr.add(obj);
        }

        final msg = LoadFilesMessage(fileDatas: arr);
        MessageChannel.shared.sendMessage(msg);
      }
    } catch (e) {
      print("error $e");
    }
  }

  void _onTapWevDav(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) {
      return WebDavFileWidget(client: newClient("http://jimhuangdeMacBook-Pro.local:8080/", password: "123", user: "jim"), path: "/");
    }));
  }
}
