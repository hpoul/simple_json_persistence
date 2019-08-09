import 'package:json_annotation/json_annotation.dart';
import 'package:simple_json_persistence/simple_json_persistence.dart';

part 'model.g.dart';

@JsonSerializable(nullable: false)
class AppData implements HasToJson {
  AppData({
    this.counter,
  });
  factory AppData.fromJson(Map<String, dynamic> json) => _$AppDataFromJson(json);
  @override
  Map<String, dynamic> toJson() => _$AppDataToJson(this);

  final int counter;
}
