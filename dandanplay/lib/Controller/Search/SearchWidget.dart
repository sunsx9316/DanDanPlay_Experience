import 'dart:math';

import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/Search/SearchAnimate.dart';
import 'package:dandanplay/Model/Search/SearchEpisode.dart';
import 'package:dandanplay/NetworkManager/SearchNetworkManager.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:dandanplay/Vendor/tree_view/tree_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SearchWidget extends StatefulWidget {
  final String mediaId;
  final String searchText;

  SearchWidget({@required this.mediaId, @required this.searchText});

  @override
  SearchWidgetState createState() {
    return SearchWidgetState(searchText);
  }
}

class SearchWidgetState extends State<SearchWidget> {
  final _selectedAnimateTypeMap = Map<AnimateType, bool>();
  final _selectedAnimateMap = Map<num, bool>();
  var _searchText = "";
  Map<AnimateType, List<SearchAnimate>> _map;

  SearchWidgetState(this._searchText);

  @override
  void initState() {
    super.initState();

    _getResult();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_map == null) {
      body = Center(child: CircularProgressIndicator());
    } else {
      if (_map.isEmpty) {
        body = Center(child: Text("并没有匹配到结果，试试更换搜索关键字╮(╯▽╰)╭"));
      } else {
        var parentList = List<Parent>();

        _map.forEach((key, value) {
          final animateTypeTitle = _creatAnimate(key);

          Widget icon = Icon(Icons.arrow_forward_ios, size: 15);
          final selected = this._selectedAnimateTypeMap[key] ?? false;
          if (selected) {
            icon = Transform.rotate(angle: pi / 2, child: icon);
          }

          //标题
          Widget title = Row(children: <Widget>[
            Expanded(child: Text(value.first.typeDescription)),
            icon
          ]);

          title = Padding(padding: EdgeInsets.all(8), child: title);

          final aParent = Parent(
              parent: _createBox(
                  title, EdgeInsets.only(left: 5, right: 5, top: 10)),
              childList: animateTypeTitle,
              isSelected: selected,
              callback: (selected) {
                setState(() {
                  this._selectedAnimateTypeMap[key] = selected;
                });
              });
          parentList.add(aParent);
        });

        body = TreeView(parentList: parentList);
      }
    }

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
                    _searchText = str;
                    _getResult();
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
            ]),
        body: body);
  }

  //请求数据
  void _getResult() async {
    final result = await SearchNetworkManager.searchEpisode(_searchText);

    setState(() {
      final animates = result.data.animes;
      var aMap = Map<AnimateType, List<SearchAnimate>>();
      if (animates != null) {
        for (SearchAnimate model in animates) {
          if (aMap[model.type] == null) {
            aMap[model.type] = List<SearchAnimate>();
          }

          aMap[model.type].add(model);
        }

        _map = aMap;
      }
    });
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

  ChildList _creatEpisode(SearchAnimate animate) {
    var childrenWidget = List<Widget>();
    //二级标题
    for (SearchEpisode m in animate.episodes) {
      Widget widget = Text("${m.episodeTitle}");
      widget = Padding(padding: EdgeInsets.all(8), child: widget);
      widget = _createBox(widget, EdgeInsets.only(left: 25, right: 5, top: 5));
      widget = GestureDetector(
          child: widget,
          onTap: () {
            _onTap(context, m);
          });
      childrenWidget.add(widget);
    }

    return ChildList(children: childrenWidget);
  }

  ChildList _creatAnimate(AnimateType animateType) {
    var childrenWidget = List<Widget>();
    final animateList = _map[animateType];
    if (animateList != null) {
      //二级标题
      for (SearchAnimate m in animateList) {
        Widget icon = Icon(Icons.arrow_forward_ios, size: 15);
        final animeId = m.animeId;
        final selected = this._selectedAnimateMap[animeId] ?? false;
        if (selected) {
          icon = Transform.rotate(angle: pi / 2, child: icon);
        }

        //标题
        Widget widget =
            Row(children: <Widget>[Expanded(child: Text(m.animeTitle)), icon]);
        widget = Padding(padding: EdgeInsets.all(8), child: widget);
        widget =
            _createBox(widget, EdgeInsets.only(left: 15, right: 5, top: 5));

        widget = Parent(
            parent: widget,
            childList: _creatEpisode(m),
            isSelected: selected,
            callback: (selected) {
              setState(() {
                this._selectedAnimateMap[animeId] = selected;
              });
            });

        childrenWidget.add(widget);
      }
    }

    return ChildList(children: childrenWidget);
  }

  void _onTap(BuildContext content, SearchEpisode model) {
    Tools.getDanmaku(widget.mediaId,
        episodeId: model.episodeId, title: model.episodeTitle);
  }
}
