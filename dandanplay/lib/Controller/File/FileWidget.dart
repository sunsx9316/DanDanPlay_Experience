import 'package:dandanplay/Model/Message/Send/LoadFilesMessage.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:dandanplayfilepicker/dandanplayfilepicker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FileWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        _createListTile('本地视频', Icon(Icons.folder, size: 30), () {
          _onTapLocalFile(context);
        }),
        _createListTile('网络', Icon(Icons.device_hub, size: 30), () {})
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
    try {
      final file = await Dandanplayfilepicker.getFile(pickType: DandanplayfilepickerType.video);
      if (file != null) {
        final msg = LoadFilesMessage(paths: [file.path]);
        MessageChannel.shared.sendMessage(msg);
      }
    } catch (e) {
      print("error $e");
    }
  }
}
