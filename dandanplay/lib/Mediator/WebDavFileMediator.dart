import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Mediator/FileMediator.dart';
import 'package:dandanplay/Model/File/FileProtocol.dart';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart';
import 'package:dandanplay/Model/File/WebDavFile+Extension.dart';

class WebDavFileMediator extends FileMediator {
  Client _client;

  WebDavFileMediator({Auth auth, @required String url}) {
    _client = newClient(url, user: auth.user, password: auth.pwd);
  }

  @override
  Future<List<FileProtocol>> contentOfPath(String path) {
    final _items = _client.readDir(path);

    final result = _items.then((value) {
      List<FileProtocol> mapValue = value.map((e) {
        return e.fileModelObj(parentPath: _client.uri, auth: _client.auth);
      }).toList();

      return mapValue;
    });
    return result;
  }

  @override
  String get mediatorTitle => "WedDav";
}
