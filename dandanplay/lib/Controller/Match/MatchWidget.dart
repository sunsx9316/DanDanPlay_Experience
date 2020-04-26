import 'dart:math';
import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Controller/Search/SearchWidget.dart';
import 'package:dandanplay/Model/Match/FileMatch.dart';
import 'package:dandanplay/Model/Match/FileMatchCollection.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:dandanplay/Vendor/tree_view/tree_view.dart';
import 'package:flutter/material.dart';

class MatchWidget extends StatefulWidget {
  final Map<AnimateType, List<FileMatch>> map;
  final String mediaId;

  MatchWidget({this.mediaId, this.map});

  factory MatchWidget.fromCollection(
      {@required String mediaId, @required FileMatchCollection collection}) {
    var aMap = Map<AnimateType, List<FileMatch>>();
    var matches = collection.matches ?? [];
    for (FileMatch model in matches) {
      if (aMap[model.type] == null) {
        aMap[model.type] = List<FileMatch>();
      }

      aMap[model.type].add(model);
    }

    return MatchWidget(mediaId: mediaId ?? "", map: aMap);
  }

  @override
  MatchWidgetState createState() {
    return MatchWidgetState();
  }
}

class MatchWidgetState extends State<MatchWidget> {
  final _selectedMap = Map<AnimateType, bool>();

  @override
  Widget build(BuildContext context) {
    final parentList = List<Parent>();
    widget.map.forEach((key, value) {
      final aParent = _creatTitle(key);
      parentList.add(aParent);
    });

    return Scaffold(
        appBar: AppBar(
          title: Padding(
              padding: EdgeInsets.only(left: 0, right: 30),
              child: TextField(
                cursorColor: Colors.white,
                textInputAction: TextInputAction.search,
                autofocus: true,
                decoration: InputDecoration(
                    border: InputBorder.none, hintText: "试试手动♂搜素"),
                onSubmitted: (str) {
                  if (str == null || str.isEmpty) {
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return SearchWidget(
                        mediaId: widget.mediaId, searchText: str);
                  }));
                },
              )),
          actions: [
            GestureDetector(
                child: Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Align(child: Text("直接播放"))),
                onTap: () {
                  Tools.getDanmaku(widget.mediaId);
                })
          ],
        ),
        body: TreeView(parentList: parentList));
  }

  Widget _creatTitle(AnimateType type) {
    final values = widget.map[type];

    Widget icon = Icon(Icons.arrow_forward_ios, size: 15);
    final selected = this._selectedMap[type] ?? false;
    if (selected) {
      icon = Transform.rotate(angle: pi / 2, child: icon);
    }

    //标题
    Widget title = Row(children: <Widget>[
      Expanded(child: Text(values.first.typeDescription)),
      icon
    ]);

    title = Padding(padding: EdgeInsets.all(8), child: title);

    return Parent(
        parent: _createBox(title, EdgeInsets.only(left: 5, right: 5, top: 10)),
        childList: _creatEpisodes(values),
        isSelected: selected,
        callback: (selected) {
          setState(() {
            this._selectedMap[type] = selected;
          });
        });
  }

  //创建二级菜单
  Widget _creatEpisodes(List<FileMatch> matchs) {
    final childrenWidget = List<Widget>();
    for (FileMatch match in matchs) {
      Widget text = Text("${match.animeTitle} - ${match.episodeTitle}");
      text = Padding(padding: EdgeInsets.all(8), child: text);
      text = _createBox(text, EdgeInsets.only(left: 15, right: 5, top: 5));
      text = GestureDetector(
          child: text,
          onTap: () {
            _onTap(context, match);
          });
      childrenWidget.add(text);
    }

    return ChildList(children: childrenWidget);
  }

  Widget _createBox(Widget child, EdgeInsets edge) {
    return Padding(
        padding: edge,
        child: Flex(direction: Axis.horizontal, children: <Widget>[
          Expanded(
              child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 3.0,
                            spreadRadius: 0,
                            offset: Offset(
                              0.0,
                              2.0,
                            ))
                      ],
                      borderRadius: BorderRadius.all(Radius.circular(5))),
                  child: child))
        ]));
  }

  void _onTap(BuildContext content, FileMatch model) {
    Tools.getDanmaku(widget.mediaId,
        episodeId: model.episodeId, title: model.title);
  }
}
