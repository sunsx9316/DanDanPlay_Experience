import 'Error.dart';

abstract class BaseResponse {
  bool success;
  Error error;
  dynamic data;
}
