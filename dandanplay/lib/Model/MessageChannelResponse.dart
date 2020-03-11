
import 'package:dandanplay/Model/BaseResponse.dart';
import 'package:dandanplay/Model/Error.dart';

class MessageChannelResponse extends BaseResponse {
  MessageChannelResponse(dynamic data) {
    this.data = data;
    if (data is Map<String, dynamic>) {
      if (data["success"] is bool) {
        this.success = data["success"] as bool;

        if (!success) {
          var code = -999;
          var errorMessage = "未知错误";

          if (data["errorCode"] is int) {
            code = data["errorCode"] as int;
          }

          if (data["errorMessage"] is String) {
            errorMessage = data["errorMessage"] as String;
          }

          this.error = MessageChannelError(code, errorMessage);
        }
      }
    }
  }
}