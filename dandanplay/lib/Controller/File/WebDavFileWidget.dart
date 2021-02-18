import 'package:dandanplay/Model/Message/Send/LoadFilesMessage.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:webdav_client/webdav_client.dart';
import 'package:dandanplay/Model/File/WebDavFile+Extension.dart';

class WebDavFileWidget extends StatefulWidget {
  final Client client;
  final String path;

  WebDavFileWidget({@required this.client, @required this.path});

  @override
  _WebDavFileWidgetState createState() {
    return _WebDavFileWidgetState();
  }
}

class _WebDavFileWidgetState extends State<WebDavFileWidget> {
  RefreshController _refreshController =
      RefreshController(initialRefresh: true);
  List<File> _items;
  String get _parentDirection {
    final uri = this.widget.client.uri;
    if (uri != null && uri.endsWith("/")) {
      return uri.substring(0, uri.lastIndexOf('/'));
    }
    return uri;
  }

  @override
  Widget build(BuildContext context) {
    String path = this._parentDirection + this.widget.path;

    return Scaffold(
        appBar: AppBar(
          title: Text("WebDav"),
        ),
        body: SafeArea(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
                message: path,
                child: Padding(
                    padding: EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 5),
                    child: Text("当前路径：" + path,
                        style: TextStyle(color: Colors.white54),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2))),
            Expanded(
                child: SmartRefresher(
              enablePullDown: true,
              enablePullUp: false,
              header: WaterDropHeader(complete: Icon(
                Icons.done,
                color: Colors.grey,
              )),
              controller: _refreshController,
              onRefresh: _onRefresh,
              child: ListView.builder(
                itemBuilder: (ctx, idx) {
                  final file = _items[idx];
                  if (file.isDir) {
                    return _createDirTitle(file.name, () {
                      Navigator.push(ctx, MaterialPageRoute(builder: (ctx) {
                        return WebDavFileWidget(client: this.widget.client, path: file.path);
                      }));
                    });
                  } else {
                    return _createFileTitle(file.name, () {
                      final obj = file.createProtocolObj(parentPath: this._parentDirection, user: this.widget.client.auth.user, password: this.widget.client.auth.pwd);
                      final msg = LoadFilesMessage(fileDatas: [obj]);
                      MessageChannel.shared.sendMessage(msg);

                    });
                  }
                },
                itemCount: _items != null ? _items.length : 0,
              ),
            ))
          ],
        )));
  }

  Widget _createDirTitle(String title, GestureTapCallback onTap) {
    return InkWell(
        child: Padding(
            padding: EdgeInsets.only(top: 15, left: 10, bottom: 15),
            child: Row(
              children: [
                Expanded(child: Text(title)),
                Icon(Icons.keyboard_arrow_right)
              ],
            )),
        onTap: onTap);
  }

  Widget _createFileTitle(String title, GestureTapCallback onTap) {
    return InkWell(
        child: Padding(
            padding: EdgeInsets.only(top: 15, left: 10, bottom: 15),
            child: Row(
              children: [Expanded(child: Text(title))],
            )),
        onTap: onTap);
  }

  void _onRefresh() async {
    final client = this.widget.client;
    final path = this.widget.path;

    if (client == null || path == null) {
      _refreshController.refreshCompleted();
      return;
    }

    _items = await client.readDir(path);
    _items.sort((f1, f2) {
      if (f1.isDir) {
        return 0;
      } else {
        return 1;
      }
    });
    setState(() {
      _refreshController.refreshCompleted();
    });
  }
}
