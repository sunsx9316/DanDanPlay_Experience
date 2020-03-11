import 'dart:async';
import 'package:dandanplay/Model/HomePage/HomePage.dart';
import 'package:dandanplay/Model/HomePage/HomePageBanner.dart';
import 'package:dandanplay/NetworkManager/HomePageNetworkManager.dart';
import 'package:dandanplay/Tools/Utility.dart';
import 'package:dandanplay/Vendor/page_indicator/page_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePageWidget extends StatefulWidget {
  @override
  _HomePageWidgetState createState() {
    return _HomePageWidgetState();
  }
}

class _HomePageWidgetState extends State<HomePageWidget> {
  HomePage _homePageModel;

  @override
  void initState() {
    super.initState();

    _requestHomePage();
  }

  @override
  Widget build(BuildContext context) {
      return BannerGridView(this._homePageModel?.banners ?? []);
  }

  void _requestHomePage() async {
    try {
      final res = await HomePageNetworkManager.getHomepage();
      setState(() {
        this._homePageModel = res.data;
      });
    } catch (e) {
      print(e);
    }
  }
}

class BannerGridView extends StatefulWidget {
  final List<HomePageBanner> _banner;

  BannerGridView(this._banner);

  @override
  _BannerGridViewState createState() => _BannerGridViewState();
}

class _BannerGridViewState extends State<BannerGridView> {
  List<HomePageBanner> get _banner {
    return this.widget?._banner ?? [];
  }

  Timer _timer;

  @override
  void dispose() {
    this._timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageView = PageView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _banner.length,
        itemBuilder: (context, index) {
          final model = _banner[index];
          final stack = Stack(fit: StackFit.loose, children: <Widget>[
            Positioned.fill(
                child: CachedNetworkImage(
                    imageUrl: model.imageUrl,
                    placeholder: _loader,
                    errorWidget: _error,
                    fit: BoxFit.cover)),
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                    padding: EdgeInsets.all(5.0),
                    decoration: BoxDecoration(color: Colors.black45),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(model.title,
                              style: TextStyle(color: Colors.white)),
                          Text(model.description,
                              style: TextStyle(color: Colors.white))
                        ])))
          ]);

          return GestureDetector(
              child: stack,
              onTap: () {
                _openURL(model.url);
//                FilePicker.getFile(type: FileType.AUDIO).then((file){
//                  print(file);
//                });

              });

        });

    this._timer?.cancel();
    this._timer = Timer.periodic(Duration(seconds: 5), (aTimer) {
      final total = this._banner.length;
      final nextPage = (pageView.controller.page + 1).toInt();
      if (total > 0) {
        if (nextPage < total) {
          pageView.controller.animateToPage(nextPage,
              duration: Duration(milliseconds: 500), curve: Curves.ease);
        } else {
          pageView.controller.animateToPage(0,
              duration: Duration(milliseconds: 500), curve: Curves.ease);
        }
      }
    });

    return PageIndicatorContainer(
      child: pageView,
      length: this._banner.length,
      indicatorSelectorColor: GlobalConfig.mainColor,
      shape: IndicatorShape.circle(size: 6),
      align: IndicatorAlign.topRight,
      padding: EdgeInsets.only(top: 10, right: 50),
    );
  }

  Widget _loader(BuildContext context, String url) => Center(
        child: CircularProgressIndicator(),
      );

  Widget _error(BuildContext context, String url, Object error) {
    print(error);
    return Center(child: const Icon(Icons.error));
  }

  _openURL(String url) async {
    if (url != null && await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
