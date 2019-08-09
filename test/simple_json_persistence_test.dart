import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_json_persistence/simple_json_persistence.dart';

import 'test_util.dart';

void main() {
  setUpAll(() async {
    await TestUtil.mockPathProvider();
  });
  setUp(() async {
    final store = SimpleJsonPersistence.forType(Dummy.fromJson);
    await store.delete();
    await store.dispose();
  });
  const objValue = Dummy(stringTest: 'blubb', intTest: 1);
  test('Test Simple Storage', () async {
    {
      final store = SimpleJsonPersistence.forType(Dummy.fromJson);
      expect(await store.load(), isNull);
      await store.save(objValue);
      // getting store a second time should get the same instance.
      expect(SimpleJsonPersistence.forType(Dummy.fromJson), same(store));
      await store.dispose();
      expect(SimpleJsonPersistence.forType(Dummy.fromJson), notSame(store));
    }

    final store = SimpleJsonPersistence.forType(Dummy.fromJson);
    expect(await store.load(), objValue);
    expect(await store.load(), notSame(objValue));
  });
  test('Default Creator', () async {
    const defaultValue = Dummy(stringTest: 'default', intTest: 9);
    final store = SimpleJsonPersistence.forType(Dummy.fromJson,
        defaultCreator: () => defaultValue);
    expect(await store.loadOrDefault(), defaultValue);
  });
  test('change stream', () async {
    final store = SimpleJsonPersistence.forType(Dummy.fromJson);
    expect(
        store.onValueChanged,
        emitsInOrder(<dynamic>[
          objValue,
          emitsDone,
        ]));
    await store.save(objValue);
    await store.dispose();
  });
  test('change stream with default', () async {
    const defaultValue = Dummy(stringTest: 'default');
    final store = SimpleJsonPersistence.forType(Dummy.fromJson,
        defaultCreator: () => defaultValue);
    expect(
        store.onValueChangedAndLoad,
        emitsInOrder(<dynamic>[
          defaultValue,
          objValue,
          emitsDone,
        ]));
    // we have to call `load` here, so that we wait for the default value
    // to be created before calling `save`.
    await store.load();
    await store.save(objValue);
    await store.dispose();
  });
}

class Dummy implements HasToJson {
  const Dummy({@required this.stringTest, this.intTest = 1});

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
      other is Dummy &&
          runtimeType == other.runtimeType &&
          stringTest == other.stringTest &&
          intTest == other.intTest;

  @override
  int get hashCode => stringTest.hashCode ^ intTest.hashCode;

  @override
  String toString() => json.encode(toJson());
}
