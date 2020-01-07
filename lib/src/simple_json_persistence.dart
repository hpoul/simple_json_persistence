import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rxdart/rxdart.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final _logger = Logger('simple_json_persistence');

const _SUB_DIR_NAME = 'json';
const _EXCEPTION_FORCE_DEFAULT = 'forceDefault';

abstract class HasToJson {
  Map<String, dynamic> toJson();
}

typedef FromJson<T> = T Function(Map<String, dynamic> json);
typedef BaseDirectoryBuilder = Future<Directory> Function();

/// Simple storage for any objects which can be serialized to json.
///
/// Right now for each type (name) it should only be used by one application
/// in one isolate at the same time, otherwise they would overwrite
/// their changes.
///
/// Each type has one instance of this persistence class
/// ie. calling [SimpleJsonPersistence.forType] multiple times for
/// the same type will return the same instance.
/// Once [load] has been called it will be cached/kept in memory forever.
class SimpleJsonPersistence<T extends HasToJson> {
  SimpleJsonPersistence._({
    @required this.fromJson,
    @required this.documentsDir,
    @required this.name,
    this.defaultCreator,
  })  : assert(fromJson != null),
        assert(documentsDir != null),
        assert(name != null) {
    _logger.finer('storing into: $file');
  }

  factory SimpleJsonPersistence.forType(FromJson<T> fromJson,
      {T Function() defaultCreator, String customName}) {
    return getForTypeSync(fromJson,
        defaultCreator: defaultCreator, customName: customName);
  }

  @visibleForTesting
  static BaseDirectoryBuilder defaultBaseDirectoryBuilder = () =>
      getApplicationDocumentsDirectory()
          .then((dir) => Directory(p.join(dir.path, _SUB_DIR_NAME)));

  /// Name of the store (used as file name for the .json file)
  final String name;
  FromJson<T> fromJson;
  final T Function() defaultCreator;
  final Future<Directory> documentsDir;
  Future<File> _file;

  @visibleForTesting
  Future<File> get file => _file ??= _init();

  Future<File> _init() => documentsDir
      .then((documentsDir) => File(p.join(documentsDir.path, '$name.json')));

  final PublishSubject<T> _onValueChanged = PublishSubject<T>();

  /// Stream which will receive a new notification on every [save] call.
  Stream<T> get onValueChanged => _onValueChanged.stream;

  /// Stream with the current value as first event,
  /// concatenated with [onValueChanged].
  Stream<T> get onValueChangedAndLoad =>
      Stream.fromFuture(load()).concatWith([onValueChanged]);

  Stream<T> onValueChangedOrDefault(Future<T> defaultValue) =>
      Rx.concat<T>([
        Stream.fromFuture(_cachedValueOrLoading ?? defaultValue),
        onValueChanged,
      ]);
  Future<T> _cachedValueLoadingFuture;

  Future<T> get _cachedValueOrLoading => _cachedValue != null
      ? Future.value(_cachedValue)
      : _cachedValueLoadingFuture;
  T _cachedValue;

  /// Useful for using as `initialValue` in [StreamBuilder].
  T get cachedValue => _cachedValue;

  static final Map<String, SimpleJsonPersistence<dynamic>> _storageSingletons =
      {};

  @Deprecated('Use constructor instead.')
  static Future<SimpleJsonPersistence<T>> getForType<T extends HasToJson>(
    FromJson<T> fromJson, {
    T Function() defaultCreator,
  }) =>
      Future.value(getForTypeSync(
        fromJson,
        defaultCreator: defaultCreator,
      ));

  static SimpleJsonPersistence<T> getForTypeSync<T extends HasToJson>(
    FromJson<T> fromJson, {
    T Function() defaultCreator,
    String customName,
    BaseDirectoryBuilder baseDirectoryBuilder,
  }) {
    baseDirectoryBuilder ??= defaultBaseDirectoryBuilder;
    final name =
        customName == null ? T.toString() : '${T.toString()}.$customName';
    final storage = _storageSingletons[name];
    if (storage != null) {
      return storage as SimpleJsonPersistence<
          T>; //Future.value(storage as SimpleJsonPersistence<T>);
    }

    return _storageSingletons[name] = SimpleJsonPersistence<T>._(
      fromJson: fromJson,
      documentsDir:
          baseDirectoryBuilder().then((dir) => dir.create(recursive: true)),
      name: name,
      defaultCreator: defaultCreator,
    );
  }

  /// Loads and deserializes data from storage. It is safe to be called
  /// multiple times.
  /// Subsequent calls will return the same future. If loaded, the cached
  /// value will be returned. ([cachedValue]).
  /// If file does not exist the default value ([defaultCreator]) will be
  /// returned.
  Future<T> load() async => await _load() ?? _createDefault();

  Future<T> _load() async {
    final f = await file;
    if (!f.existsSync()) {
      return Future.value(_createDefault());
    }
    if (_cachedValueLoadingFuture != null) {
      return _cachedValueLoadingFuture;
    }
    _logger.fine('Deserializing $name');
//    file.readAsString().then((data) => _logger.finest('Loading: $data'));

    return _cachedValueLoadingFuture = f
        .readAsString()
        .then((data) {
          try {
            return json.decode(data) as Map<String, dynamic>;
          } on FormatException catch (e, stackTrace) {
            if (data == null || data.isEmpty) {
              _logger.shout(
                  '$name: json file is compltely empty. for some reason corrupted? (${data?.length})',
                  e,
                  stackTrace);
              throw _EXCEPTION_FORCE_DEFAULT;
            }
            _logger.severe(
                '$name: Persisted json file was corrupted.', e, stackTrace);
            _logger.severe('Contents of json file: $data');
            rethrow;
          }
        })
        .then((json) => fromJson(json))
        .catchError((dynamic error, StackTrace stackTrace) {
          _logger.fine(
              'forcing using of default value for $name', error, stackTrace);
          return _createDefault();
        }, test: (error) => error == _EXCEPTION_FORCE_DEFAULT)
        .then((value) => _updateValue(value))
        .catchError((dynamic error, StackTrace stackTrace) {
          _logger.severe('Error while loading data', error, stackTrace);
          return Future<T>.error(error, stackTrace);
        });
  }

  Future<File> save(T value) {
    _cachedValue = value;
    _cachedValueLoadingFuture = Future.value(value);
    _onValueChanged.add(value);
    return file.then(
        (file) => file.writeAsString(json.encode(value.toJson()), flush: true));
  }

  T _createDefault() => defaultCreator == null ? null : defaultCreator();

  Future<void> delete() async {
    final f = await file;
    if (f.existsSync()) {
      await f.delete();
    }
    _onValueChanged.add(_createDefault());
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

  T _updateValue(T value) {
    _logger.finest('$name updating value.');
    _onValueChanged.add(value);
    _cachedValueLoadingFuture = Future.value(value);
    _cachedValue = value;
    return value;
  }
}
