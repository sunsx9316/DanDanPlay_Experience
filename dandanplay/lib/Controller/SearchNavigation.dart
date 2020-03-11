import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loader_search_bar/loader_search_bar.dart';

class SearchNavigation extends StatelessWidget {
  final Widget body;

  SearchNavigation({Key key, this.body}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: SearchBar(
            iconified: false,
            defaultBar: AppBar(
          title: Text("Search"),
        )),
        body: body);
  }
}
