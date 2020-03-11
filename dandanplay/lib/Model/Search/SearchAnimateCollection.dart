
import 'package:dandanplay/Model/BaseModel.dart';
import 'package:dandanplay/Model/Search/SearchAnimate.dart';
import 'package:json_annotation/json_annotation.dart';

part 'SearchAnimateCollection.g.dart';

@JsonSerializable()
class SearchAnimateCollection extends BaseModelCollection {
  bool hasMore;
  List<SearchAnimate> animes;

  SearchAnimateCollection(this.hasMore, this.animes);

  factory SearchAnimateCollection.fromJson(Map<String, dynamic> map) {
    return _$SearchAnimateCollectionFromJson(map);
  }

  Map<String, dynamic> toJson() {
    return _$SearchAnimateCollectionToJson(this);
  }
}