import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_json_persistence/simple_json_persistence.dart';

import 'test_util.dart';

void main() {
  setUpAll(() async {
    await TestUtil.mockPathProvider();
  });
  test('Test Simple Storage', () async {
    const objValue = Dummy(stringTest: 'blubb', intTest: 1);
    final store = SimpleJsonPersistence.forType(Dummy.fromJson);
    expect(await store.load(), isNull);
    await store.save(objValue);
    // getting store a second time should get the same instance.
    expect(SimpleJsonPersistence.forType(Dummy.fromJson), same(store));
    await store.dispose();
    expect(SimpleJsonPersistence.forType(Dummy.fromJson), notSame(store));
    expect(await store.load(), objValue);
    expect(await store.load(), notSame(objValue));
  });
}

class Dummy implements HasToJson {
  const Dummy({@required this.stringTest, @required this.intTest});

  final String stringTest;
  final int intTest;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'stringTest': stringTest,
        'intTest': intTest,
      };

  static Dummy fromJson(Map<String, dynamic> json) => Dummy(
        stringTest: json['stringTest'] as String,
        intTest: json['intTest'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Dummy && runtimeType == other.runtimeType && stringTest == other.stringTest && intTest == other.intTest;

  @override
  int get hashCode => stringTest.hashCode ^ intTest.hashCode;

  @override
  String toString() => json.encode(toJson());
}
