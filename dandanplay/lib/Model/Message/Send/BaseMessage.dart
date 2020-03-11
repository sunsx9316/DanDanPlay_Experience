
import 'package:dandanplay/Model/BaseModel.dart';

abstract class BaseMessage<T> extends BaseModel {
  String get name;
  T get data;
}