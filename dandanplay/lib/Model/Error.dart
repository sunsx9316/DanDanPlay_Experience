
abstract class Error {
  String message;
  num code;
}

class HttpError extends Error {
  String message;
  num code;

  HttpError(this.code, this.message);

  @override
  String toString() {
    return "errorCode: $code, message: $message";
  }
}

class MessageChannelError extends Error {
  String message;
  num code;

  MessageChannelError(this.code, this.message);

  @override
  String toString() {
    return "errorCode: $code, message: $message";
  }
}