
enum FileMatchMode {
  hashAndFileName,
  fileNameOnly,
  hashOnly,
}

enum AnimateType {
  tvSeries,
  tvSpecial,
  ova,
  movie,
  musicVideo,
  web,
  other,
  jpMovie,
  jpDrama,
  unknown
}

enum PlayerMode {
  notRepeat,
  repeatCurrentItem,
  repeatAllItem,
}

enum DanmakuMode {
  normal,
  top,
  bottom,
}

enum FileDataMediaType {
  localFile,
  webDav,
}

extension FileDataMediaTypeConvenience on FileDataMediaType {
  int get rawValue {
    switch (this) {
      case FileDataMediaType.localFile: {
        return 0;
      }
      break;
      case FileDataMediaType.webDav: {
        return 1;
      }
      break;
      default: {
        return 0;
      }
      break;
    }
  }

  static FileDataMediaType mediaTypeWithRawValue(int rawValue) {
    if (rawValue == 1) {
      return FileDataMediaType.webDav;
    }
    return FileDataMediaType.localFile;
  }
}

int danmakuModeRawValueWithEnum(DanmakuMode mode) {
  switch (mode) {
    case DanmakuMode.normal:
      return 1;
    case DanmakuMode.top:
      return 4;
    case DanmakuMode.bottom:
      return 5;
    default:
      return 1;
  }
}

DanmakuMode danmakuModeTypeWithRawValue(int danmakuModeRawValue) {
  if (danmakuModeRawValue == 4) {
    return DanmakuMode.top;
  } else if (danmakuModeRawValue == 5) {
    return DanmakuMode.bottom;
  } else {
    return DanmakuMode.normal;
  }
}


PlayerMode playerModeTypeWithRawValue(int playerModeRawValue) {
  final values = PlayerMode.values;

  if (playerModeRawValue >= 0 && playerModeRawValue < values.length) {
    return values[playerModeRawValue];
  }

  return PlayerMode.notRepeat;
}

int playerModeRawValueWithEnum(PlayerMode mode) {
  return mode.index;
}

AnimateType animateTypeWithString(String typeRawValue) {
  switch (typeRawValue) {
    case "tvseries":
      return AnimateType.tvSeries;
    case "ova":
      return AnimateType.ova;
    case "movie":
      return AnimateType.movie;
    case "musicvideo":
      return AnimateType.musicVideo;
    case "web":
      return AnimateType.web;
    case "other":
      return AnimateType.other;
    case "jpmovie":
      return AnimateType.jpMovie;
    case "jpdrama":
      return AnimateType.jpDrama;
    default:
      return AnimateType.unknown;
  }
}