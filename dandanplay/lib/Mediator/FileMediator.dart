
import 'package:dandanplay/Model/File/FileProtocol.dart';

abstract class FileMediator {
  Future<List<FileProtocol>> contentOfPath(String path);
  String get mediatorTitle;
}