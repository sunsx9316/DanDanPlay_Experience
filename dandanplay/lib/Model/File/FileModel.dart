
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dandanplay/Protocol/FileMatchProtocol.dart';
import 'package:path/path.dart';

class FileModel extends FileMatchProtocol {

  final File file;
  String _fileName;
  String _fileHash;
  int _fileSize;

  @override
  Future<int> get matchFileSize async {
    if (_fileSize == null) {
      _fileSize = await file.length();
    }
    return _fileSize;
  }

  @override
  String get matchFileName {
    if (_fileName == null) {
      _fileName = basenameWithoutExtension(file.path);
    }
    return _fileName;
  }

  @override
  Future<String> get matchFileHash async {
    if (_fileHash == null) {
      final fileSize = await file.length();
      final readSize = fileSize > 16777216 ? 16777216 : fileSize;
      final stream = file.openRead(0, readSize);
      final data = await stream.toList();
      var allData = List<int>();
      for (List<int>a in data) {
        allData.addAll(a);
      }
      final md5String = md5.convert(allData);
      _fileHash = "$md5String";
    }
    return _fileHash;
  }

  FileModel(this.file);

}