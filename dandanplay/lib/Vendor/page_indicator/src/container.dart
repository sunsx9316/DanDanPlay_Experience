import 'package:flutter/material.dart';

import 'indicator.dart';
import 'shape.dart';

enum IndicatorAlign {
  top,
  center,
  bottom,
  topLeft,
  topRight,
}

class PageIndicatorContainer extends StatefulWidget {
  final Widget child;

  final int length;

  final EdgeInsets padding;

  final IndicatorAlign align;

  final IndicatorShape shape;

  final Color indicatorColor;

  final Color indicatorSelectorColor;

  final double indicatorSpace;

  const PageIndicatorContainer({
    Key key,
    @required this.child,
    @required this.length,
    this.padding = const EdgeInsets.only(bottom: 10.0, top: 10.0),
    this.align = IndicatorAlign.bottom,
    this.indicatorColor = Colors.white,
    this.indicatorSelectorColor = Colors.grey,
    this.indicatorSpace = 8.0,
    this.shape = IndicatorShape.defaultCircle
  }) : super(key: key);

  @override
  PageContainerState createState() => PageContainerState();
}

class PageContainerState extends State<PageIndicatorContainer> {
  double currentPage;

  @override
  Widget build(BuildContext context) {
    if (widget.child is! PageView) {
      return widget.child;
    }

    double height = widget.shape.height;

    final initPage = pageView?.controller?.initialPage ?? 0.0;

    final currentPage = this.currentPage ?? initPage.toDouble();

    Widget indicator = PageIndicator(
      length: widget.length,
      color: widget.indicatorColor,
      selectedColor: widget.indicatorSelectorColor,
      indicatorSpace: widget.indicatorSpace,
      indicatorShape: widget.shape,
      align: widget.align,
      reverse: pageView.reverse,
      currentPage: currentPage,
      initialPage: initPage.toDouble(),
    );

    var align = widget.align;

    if (align == IndicatorAlign.bottom) {
      indicator = Positioned(
        left: 0.0,
        right: 0.0,
        bottom: widget.padding.bottom,
        height: height,
        child: indicator,
      );
    } else if (align == IndicatorAlign.top) {
      indicator = Positioned(
        left: 0.0,
        right: 0.0,
        top: widget.padding.top,
        height: height,
        child: indicator,
      );
    } else if (align == IndicatorAlign.center) {
      indicator = Center(
        child: Container(
          child: indicator,
          height: height,
        ),
      );
    } else if (align == IndicatorAlign.topLeft) {
      indicator = Positioned(
        left: widget.padding.left,
        top: widget.padding.top,
        height: height,
        child: indicator,
      );
    } else if (align == IndicatorAlign.topRight) {
      indicator = Positioned(
        right: widget.padding.right,
        top: widget.padding.top,
        height: height,
        child: indicator,
      );
    }

    return Stack(
      children: <Widget>[
        NotificationListener<ScrollNotification>(
          child: pageView,
          onNotification: _onScroll,
        ),
        indicator,
      ],
    );
  }

  PageView get pageView => widget.child;

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final PageMetrics metrics = notification.metrics;
      currentPage = metrics.page;
      setState(() {});
    }
    return false;
  }

  void forceRefreshState() {
    this.setState(() {});
  }
}
