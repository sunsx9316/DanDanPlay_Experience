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