
import 'package:dandanplay/Config/Constant.dart';
import 'package:dandanplay/Model/Message/Send/LoadFilesMessage.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart';

abstract class FileProtocol extends FileDataProtocol {
  FileType get fileType;
  String get path;

  String get name {
    return basename(this.path);
  }
  
  bool get isVideoFile {
    final mime = lookupMimeType(this.path);
    return mime.startsWith("video");
  }

  bool get isDanmakuFile {
    final extensionType = extension(this.path);
    return extensionType.toLowerCase() == "xml";
  }

  bool get isSubtitleFile {
    final mime = lookupMimeType(this.path);
    return mime.contains("text");
  }
  
}