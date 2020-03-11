

abstract class FileMatchProtocol {
  String get matchFileName {
    return "";
  }

  Future<String> get matchFileHash async {
    return "";
  }

  Future<int> get matchFileSize async {
    return 0;
  }

}
