import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:simple_json_persistence/simple_json_persistence.dart';
import 'package:simple_json_persistence/src/persistence_io.dart';

import 'test_util.dart';

final _logger = Logger('simple_json_persistence_test');

class DummyStoreBackend extends StoreBackend {
  final _store = DummyStore();

  @override
  Future<Store> storeForFile(String name) async => _store;
}

class DummyStore extends Store {
  String? value;

  @override
  Future<void> delete() async => value = null;

  @override
  Future<bool> exists() async => value != null;

  @override
  Future<String> load() async =>
      Future.delayed(const Duration(milliseconds: 1), () => value!);

  @override
  Future<void> save(String data) async =>
      Future.delayed(const Duration(milliseconds: 1), () => value = data);
}

void main() {
  PrintAppender.setupLogging();
  setUpAll(() async {
    StoreBackendIo.defaultBaseDirectoryBuilder =
        await TestUtil.baseDirectoryBuilder();
  });
  setUp(() async {
    PrintAppender.setupLogging();
    final store = SimpleJsonPersistence.getForTypeSync(
      Dummy.fromJson,
      name: null,
    );
    await store.delete();
    await store.dispose();
  });
  const objValue = Dummy(stringTest: 'blubb', intTest: 1);
  test('Test Simple Storage', () async {
    {
      final store = SimpleJsonPersistence.getForTypeSync(
        Dummy.fromJson,
        name: null,
      );
      expect(await store.load(), isNull);
      await store.save(objValue);
      // getting store a second time should get the same instance.
      expect(
          SimpleJsonPersistence.getForTypeSync(
            Dummy.fromJson,
            name: null,
          ),
          same(store));
      await store.dispose();
      expect(
          SimpleJsonPersistence.getForTypeSync(
            Dummy.fromJson,
            name: null,
          ),
          notSame(store));
    }

    final store = SimpleJsonPersistence.getForTypeSync(
      Dummy.fromJson,
      name: null,
    );
    expect(await store.load(), objValue);
    expect(await store.load(), notSame(objValue));
  });
  test('Default Creator', () async {
    const defaultValue = Dummy(stringTest: 'default', intTest: 9);
    final store = SimpleJsonPersistence.getForTypeSync(
      Dummy.fromJson,
      defaultCreator: () => defaultValue,
      name: null,
    );
    expect(await store.load(), defaultValue);
  });
  test('change stream', () async {
    final store = SimpleJsonPersistence.getForTypeSync(
      Dummy.fromJson,
      name: null,
    );
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
    final store = SimpleJsonPersistence.getForTypeSync(
      Dummy.fromJson,
      defaultCreator: () => defaultValue,
      name: null,
    );
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
  test('change stream with default class', () async {
    const defaultValue = Dummy(stringTest: 'default');
    final store = SimpleJsonPersistence.getForTypeWithDefault(
      Dummy.fromJson,
      defaultCreator: () => defaultValue,
      name: null,
    );
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
  test('corrupted empty file', () async {
    // when file was emptied, we expect default value to be created.
    {
      final storeBackend = DummyStoreBackend();
      const defaultValue = Dummy(stringTest: 'default');
      final store = SimpleJsonPersistence.getForTypeSync(
        Dummy.fromJson,
        defaultCreator: () => defaultValue,
        storeBackend: storeBackend,
        name: null,
      );
      await store.save(objValue);
      await store.dispose();

      final f = storeBackend._store;

      expect(f.value, isNotNull);
      expect(f.value, hasLength(greaterThan(0)));
      f.value = '';
    }
    {
      const defaultValue = Dummy(stringTest: 'default');
      final store = SimpleJsonPersistence.getForTypeSync(
        Dummy.fromJson,
        defaultCreator: () => defaultValue,
        name: null,
      );
      expect(await store.load(), defaultValue);
    }
  });
  test('corrupted, invalid json file', () async {
    // when file contains corrupted content, we expect an exception.
    final storeBackend = DummyStoreBackend();
    final store = SimpleJsonPersistence.getForTypeSync(
      Dummy.fromJson,
      storeBackend: storeBackend,
      name: null,
    );
    final f = storeBackend._store;
    f.value = 'invalid';
    expect(store.load(), throwsFormatException);
  });
  test('race condition in update()', () {
    fakeAsync((async) {
      final storeBackend = DummyStoreBackend();
      final store = SimpleJsonPersistence.getForTypeSync(
        Dummy.fromJson,
        defaultCreator: () => const Dummy(stringTest: 'first', intTest: 1),
        storeBackend: storeBackend,
        name: null,
      );
//      final f = storeBackend._store;
//      final result = store
//          .save(Dummy(stringTest: 'first', intTest: 1))
//          .then((saved) => _logger.finest('saved'));
      _logger.finest('Flushing timers.');
      async.flushTimers();
      _logger.finest('starting update...');
      store.update((data) {
        _logger.finest('1 Updating $data');
        return Dummy(stringTest: data!.stringTest, intTest: 2);
      }).then((value) => _logger.finest('1 Updated $value'));
      store.update((data) {
        _logger.finest('2. Updating $data');
        return Dummy(stringTest: 'third', intTest: data!.intTest);
      }).then((value) => _logger.finest('2 Updated $value'));
      async.elapse(const Duration(milliseconds: 250));
      _logger.finest('elapsed.');
      expect(store.load(),
          completion(const Dummy(stringTest: 'third', intTest: 2)));
      async.flushTimers();
      _logger.finest('all done.');
    });
  });
  test('delete should clear cached value', () async {
    final storeBackend = DummyStoreBackend();
    const defaultValue = Dummy(stringTest: 'default');
    final store = SimpleJsonPersistence.getForTypeSync(
      Dummy.fromJson,
      defaultCreator: () => defaultValue,
      storeBackend: storeBackend,
      name: null,
    );
    await store.save(objValue);

    final data = await store.load();
    expect(data, objValue);

    await store.delete();

    final after = await store.load();
    expect(after, defaultValue);
  });
}

class Dummy implements HasToJson {
  const Dummy({required this.stringTest, this.intTest = 1});

  final String? stringTest;
  final int? intTest;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'stringTest': stringTest,
        'intTest': intTest,
      };

  static Dummy fromJson(Map<String, dynamic>? json) => Dummy(
        stringTest: json!['stringTest'] as String?,
        intTest: json['intTest'] as int?,
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
