
import 'package:flutter/material.dart';

class BaseNavigation extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget titleBar;

  BaseNavigation({Key key, this.body, this.title, this.titleBar}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: this.titleBar ?? Text(title ?? ""),
      ),
      body: body
    );
  }
}