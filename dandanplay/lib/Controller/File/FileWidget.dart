
import 'package:dandanplay/Controller/File/FileListWidget.dart';
import 'package:dandanplay/Mediator/LocalFileMediator.dart';
import 'package:dandanplay/Mediator/WebDavFileMediator.dart';
import 'package:dandanplay/Model/Message/Send/LoadFilesMessage.dart';
import 'package:dandanplay/Vendor/file_picker/dandanplayfilepicker.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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
    // return Center(
    //     child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    //       IconButton(
    //           color: Colors.white38,
    //           iconSize: 130,
    //           icon: Icon(Icons.folder),
    //           onPressed: () {
    //             _onTapLocalFile(context);
    //           }),
    //       Text("点击选取视频播放", style: TextStyle(fontSize: 16, color: Colors.white38)),
    //     ]));

    return ListView(
      children: <Widget>[
        _createListTile('本地视频', Icon(Icons.folder, size: 30), () {
          _onTapLocalFile(context);
        }),
        _createListTile('WebDav', Icon(Icons.device_hub, size: 30), () {
          _onTapWevDav(context);
        })
      ],
    );
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
    final path = (await getApplicationDocumentsDirectory()).path;
    Navigator.push(context, MaterialPageRoute(builder: (ctx) {
      final mediator = LocalFileMediator();
      return FileListWidget(mediator: mediator, path: path);
    }));
  }

  void _onTapWevDav(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) {
      final mediator = WebDavFileMediator(auth: Auth(user: "jim", pwd: "123"), url: "http://jimhuangdemacbook-pro.local:8080/");
      return FileListWidget(mediator: mediator, path: "/");
    }));
  }
}
