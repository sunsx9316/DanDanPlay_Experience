import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Mediator/FileMediator.dart';
import 'package:dandanplay/Model/File/FileProtocol.dart';
import 'package:dandanplay/Model/Message/Send/LoadFilesMessage.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:dandanplay/Vendor/message/MessageChannel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class FileListWidget extends StatefulWidget {
  final FileMediator mediator;
  final String path;
  final FileFilterType filterType;

  FileListWidget({@required this.mediator, this.path, this.filterType});

  @override
  _FileListWidgetState createState() {
    return _FileListWidgetState();
  }
}

class _FileListWidgetState extends State<FileListWidget> {
  RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  List<FileProtocol> _items;

  @override
  void initState() {
    super.initState();
    _onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final path = this.widget.path;

    return Scaffold(
        appBar: AppBar(
          title: Text(this.widget.mediator.mediatorTitle),
        ),
        body: SafeArea(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
                message: path,
                child: Padding(
                    padding:
                        EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 5),
                    child: Text("当前路径：" + path,
                        style: TextStyle(color: Colors.white54),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2))),
            Expanded(
                child: SmartRefresher(
              enablePullDown: true,
              enablePullUp: false,
              header: WaterDropHeader(
                  complete: Icon(
                Icons.done,
                color: Colors.grey,
              )),
              controller: _refreshController,
              onRefresh: _onRefresh,
              child: ListView.builder(
                itemBuilder: (ctx, idx) {
                  final file = _items[idx];
                  if (file.fileType == FileType.folder) {
                    return _createDirTitle(file.name, () {
                      Navigator.push(ctx, MaterialPageRoute(builder: (ctx) {
                        return FileListWidget(
                            mediator: this.widget.mediator, path: file.path);
                      }));
                    });
                  } else {
                    return _createFileTitle(file.name, () {
                      final msg = LoadFilesMessage(fileDatas: [file]);
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
                Icon(Icons.folder),
                Padding(padding: EdgeInsets.only(right: 5)),
                Expanded(child: Text(title)),
                Icon(Icons.keyboard_arrow_right)
              ],
            )),
        onTap: onTap);
  }

  Widget _createFileTitle(String title, GestureTapCallback onTap) {
    List<Widget> children;
    final mineType = lookupMimeType(title);
    if (mineType != null && mineType.startsWith("video")) {
      children = [
        Container(
            child: Text(extensionFromMime(mineType)),
            decoration: BoxDecoration(
                color: GlobalConfig.mainColor,
                borderRadius: BorderRadius.all(Radius.circular(3))),
            padding: EdgeInsets.all(5)),
        Padding(padding: EdgeInsets.only(right: 5)),
        Expanded(child: Text(title))
      ];
    } else {
      children = [Expanded(child: Text(title))];
    }

    return InkWell(
        child: Padding(
            padding: EdgeInsets.only(top: 15, left: 10, bottom: 15),
            child: Row(
              children: children,
            )),
        onTap: onTap);
  }

  void _onRefresh() async {
    final mediator = this.widget.mediator;
    final path = this.widget.path;

    if (mediator == null || path == null) {
      _refreshController.refreshCompleted();
      return;
    }

    var items = mediator.contentOfPath(path);

    _items = await items.then((value) {
      var arr = value;
      switch (this.widget.filterType) {
        case FileFilterType.danmaku:
          arr = arr.map((e) {
            return e.isDanmakuFile ? e : null;
          });
          break;
        case FileFilterType.subtitle:
          arr = arr.map((e) {
            return e.isSubtitleFile ? e : null;
          });
          break;
        case FileFilterType.video:
          arr = arr.map((e) {
            return e.isVideoFile ? e : null;
          });
          break;
        default:
          break;
      }
      return arr;
    }).then((value) {
      value.sort((f1, f2) {
        if (f1.fileType == FileType.folder && f2.fileType == FileType.file) {
          return -1;
        } else if (f1.fileType == FileType.file &&
            f2.fileType == FileType.folder) {
          return 1;
        } else if (f1.fileType == FileType.folder &&
            f2.fileType == FileType.folder) {
          return f1.name.compareTo(f2.name);
        } else {
          if (f1.isVideoFile && !f2.isVideoFile) {
            return -1;
          } else if (!f1.isVideoFile && f2.isVideoFile) {
            return 1;
          }

          return f1.name.compareTo(f2.name);
        }
      });
      return value;
    });

    setState(() {
      _refreshController.refreshCompleted();
    });
  }
}
