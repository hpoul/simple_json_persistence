# simple_json_persistence

Flutter data storage based on simple json files. The main advantage to using
for example the shared preference plugin is that:

1. It is completely written in dart, so no communication with native ios/android code.
2. It is possible to have multiple storages for different base types.
   While the shared preferences load the whole data into memory at once,
   this allows you to split it up into multiple json storage.
   (e.g. one small storage for app data/config which needs to be loaded on startup
   and a larger json storage with larger application data).

It is still not suitable for large datasets, since all data will be kept
in memory and written into the json file at once, but it's a good 
middle ground between shared preferences and complicated database.

## Getting Started

To make use of `SimpleJsonPersistence` you have to create your
data models to serialize to and from json. I personally prefer to use
[built_value](https://github.com/google/built_value.dart) with it's
serialization, or [json_serializable](https://github.com/dart-lang/json_serializable).

Anyway, it is recommended that persistence models are immutable.

```dart
import 'package:simple_json_persistence/simple_json_persistence.dart';

@JsonSerializable(nullable: false)
class MyModel {
  MyModel({this.property,});
  factory MyModel.fromJson(Map<String, dynamic> json) => _$MyModelFromJson(json);
  Map<String, dynamic> toJson() => _$MyModelToJson(this);
  
  final String property;
}

void doSomething() async {
  final store = SimpleJsonPersistence.forType((json) => MyModel.fromJson(json));
  await store.save(MyModel(property: 'foo'));
  final foo = await store.load();

  // since every SimpleJsonPersistence for the same type/name is the same instance
  // you can also subscribe to changes.
  store.onValueChanged.listen((newValue) {
    print('got a new value $newValue');
  });
}

```
