import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';
import 'package:simple_json_persistence/simple_json_persistence.dart';
import 'package:simple_json_persistence/src/persistence_base.dart';
import 'package:string_literal_finder_annotations/string_literal_finder_annotations.dart';
import 'package:synchronized/synchronized.dart';

final _logger = Logger('simple_json_persistence');

abstract class HasToJson {
  Map<String, dynamic> toJson();
}

typedef FromJson<T> = T Function(Map<String, dynamic> json);

class SimpleJsonPersistenceWithDefault<T extends HasToJson>
    extends SimpleJsonPersistence<T> {
  SimpleJsonPersistenceWithDefault._({
    required FromJson<T> fromJson,
    required String name,
    required T Function() defaultCreator,
    required StoreBackend storeBackend,
  }) : super._(
          fromJson: fromJson,
          name: name,
          defaultCreator: defaultCreator,
          storeBackend: storeBackend,
        );

  @override
  Future<T> load() async {
    return (await super.load())!;
  }

  @override
  Stream<T> get onValueChanged => super.onValueChanged.cast<T>();

  @override
  Stream<T> get onValueChangedAndLoad =>
      Stream.fromFuture(load()).concatWith([onValueChanged]);

  @override
  Future<T> update(T Function(T data) updater) async {
    return super.update((data) => updater(data!));
  }
}

/// Simple storage for any objects which can be serialized to json.
///
/// Right now for each type (name) it should only be used by one application
/// in one isolate at the same time, otherwise they would overwrite
/// their changes.
///
/// Each type has one instance of this persistence class
/// ie. calling [SimpleJsonPersistence.getForTypeSync] multiple times for
/// the same type will return the same instance.
/// Once [load] has been called it will be cached/kept in memory forever.
class SimpleJsonPersistence<T extends HasToJson> {
  SimpleJsonPersistence._({
    required this.fromJson,
    required this.name,
    this.defaultCreator,
    required this.storeBackend,
  });

//  factory SimpleJsonPersistence.forType(FromJson<T> fromJson,
//      {T Function() defaultCreator, String customName}) {
//    return getForTypeSync(fromJson,
//        defaultCreator: defaultCreator, customName: customName);
//  }

  /// Name of the store (used as file name for the .json file)
  final String name;
  FromJson<T> fromJson;
  final T Function()? defaultCreator;
  final PublishSubject<T?> _onValueChanged = PublishSubject<T?>();
  final StoreBackend storeBackend;

  late final Future<Store> _store = storeBackend.storeForFile(name);

  /// Stream which will receive a new notification on every [save] call.
  Stream<T?> get onValueChanged => _onValueChanged.stream;

  /// Stream with the current value as first event,
  /// concatenated with [onValueChanged].
  Stream<T?> get onValueChangedAndLoad =>
      Stream.fromFuture(load()).concatWith([onValueChanged]);

  Stream<T?> onValueChangedOrDefault(Future<T> defaultValue) => Rx.concat<T?>([
        Stream.fromFuture(_cachedValueOrLoading ?? defaultValue),
        onValueChanged,
      ]);
  Future<T?>? _cachedValueLoadingFuture;

  Future<T?>? get _cachedValueOrLoading => _cachedValue != null
      ? Future.value(_cachedValue)
      : _cachedValueLoadingFuture;
  T? _cachedValue;

  /// Useful for using as `initialValue` in [StreamBuilder].
  T? get cachedValue => _cachedValue;

  static final Map<String, SimpleJsonPersistence<dynamic>> _storageSingletons =
      {};

  /// Creates a new persistence store for the given type.
  /// The json file location can be customized by passing in a custom
  /// [storeBackend] and create it using [StoreBackend.create].
  ///
  /// Note: For Flutter Web/JavaScript make sure to pass a non-null `name`,
  /// because otherwise it will be the minified version which will change on
  /// every build.
  static SimpleJsonPersistence<T> getForTypeSync<T extends HasToJson>(
    FromJson<T> fromJson, {
    T Function()? defaultCreator,
    @NonNls required String? name,
    @NonNls String? customName,
    StoreBackend? storeBackend,
  }) {
    name ??= T.toString();
    name = customName == null ? name : '$name.$customName';
    final storage = _storageSingletons[name];
    if (storage != null) {
      return storage as SimpleJsonPersistence<
          T>; //Future.value(storage as SimpleJsonPersistence<T>);
    }

    return _storageSingletons[name] = defaultCreator == null
        ? SimpleJsonPersistence<T>._(
            fromJson: fromJson,
            name: name,
            storeBackend: storeBackend ?? StoreBackend.create(),
          )
        : SimpleJsonPersistenceWithDefault<T>._(
            fromJson: fromJson,
            name: name,
            defaultCreator: defaultCreator,
            storeBackend: storeBackend ?? StoreBackend.create(),
          );
  }

  static SimpleJsonPersistenceWithDefault<T>
      getForTypeWithDefault<T extends HasToJson>(
    FromJson<T> fromJson, {
    required T Function() defaultCreator,
    @NonNls required String? name,
    @NonNls String? customName,
    StoreBackend? storeBackend,
  }) {
    return getForTypeSync(
      fromJson,
      defaultCreator: defaultCreator,
      name: name,
      customName: customName,
      storeBackend: storeBackend,
    ) as SimpleJsonPersistenceWithDefault<T>;
  }

  /// Loads and deserializes data from storage. It is safe to be called
  /// multiple times.
  /// Subsequent calls will return the same future. If loaded, the cached
  /// value will be returned. ([cachedValue]).
  /// If file does not exist the default value ([defaultCreator]) will be
  /// returned.
  Future<T?> load() async => await _load() ?? _createDefault();

  Future<T?>? _load() async {
    if (_cachedValueLoadingFuture != null) {
      return _cachedValueLoadingFuture;
    }
    _logger.fine('Deserializing $name');
//    file.readAsString().then((data) => _logger.finest('Loading: $data'));

    return _cachedValueLoadingFuture = (() async {
      final store = await _store;
      if (!await store.exists()) {
        return _createDefault();
      }
      final data = await store.load();
      try {
        final jsonData = json.decode(data) as Map<String, dynamic>?;
        if (jsonData == null) {
          throw const FormatException('data was empty.');
        }
        final ret = fromJson(jsonData);
        return _updateValue(ret);
      } on FormatException catch (e, stackTrace) {
        if (data.isEmpty) {
          _logger.shout(
              '$name: json file is completely empty. '
              'for some reason corrupted? (${data.length})'
              'Using default value.',
              e,
              stackTrace);
          return _updateValue(_createDefault());
        }
        _logger.severe(
            '$name: Persisted json file was corrupted.', e, stackTrace);
        _logger.severe('Contents of json file: $data');
        rethrow;
      } catch (e, stackTrace) {
        _logger.severe('Error while loading data', e, stackTrace);
        rethrow;
      }
    })();
  }

  Future<void> save(T value) async {
    _cachedValue = value;
    _cachedValueLoadingFuture = Future.value(value);
    _onValueChanged.add(value);
    return (await _store).save(json.encode(value.toJson()));
  }

  T? _createDefault() => defaultCreator == null ? null : defaultCreator!();

  Future<void> delete() async {
    await (await _store).delete();
    _updateValue(_createDefault());
  }

  /// Removes this store from memory. Probably not really useful in a
  /// real world app and should not be used outside of testing.
  @visibleForTesting
  Future<void> dispose() async {
    final removed = _storageSingletons.remove(name);
    assert(removed == this);
    await _onValueChanged.close();
    _cachedValue = null;
    _cachedValueLoadingFuture = null;
  }

  T? _updateValue(T? value) {
    _logger.finest('$name updating value.');
    _onValueChanged.add(value);
    _cachedValueLoadingFuture = Future.value(value);
    _cachedValue = value;
    return value;
  }

  final _updateLock = Lock();

  /// Convenience method which allows simple updating of data.
  /// The [updater] gets the current value as parameter and is expected
  /// to return a copy with the new values which will be persisted afterwards.
  Future<T> update(T Function(T? data) updater) async {
    return _updateLock.synchronized(() async {
      final newData = updater(await load());
      await save(newData);
      return newData;
    });
  }
}
