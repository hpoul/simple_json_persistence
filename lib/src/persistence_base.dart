import 'package:simple_json_persistence/src/persistence_noop.dart'
    if (dart.library.io) 'package:simple_json_persistence/src/persistence_io.dart'
    if (dart.library.html) 'package:simple_json_persistence/src/persistence_html.dart';

typedef BaseDirectoryBuilder = Future<String> Function();

abstract class StoreBackend {
  /// Allows overwriting the default mechanism for fetching the base
  /// directory for storage (When not explicitly passed into
  /// [create])
  static BaseDirectoryBuilder? defaultBaseDirectoryBuilder;

  /// Creates a new store backend instance depending on either
  /// dart:io or dart:html.
  /// With dart:io the given [baseDirectoryBuilder] is used to determine
  /// the file system location store json files. Otherwise
  /// [defaultBaseDirectoryBuilder] is used.
  static StoreBackend create([BaseDirectoryBuilder? baseDirectoryBuilder]) =>
      createStoreBackend(baseDirectoryBuilder);

  Future<Store> storeForFile(String name);
}

abstract class Store {
  Future<bool> exists();

  /// Throws StateError if [exists] returns false.
  Future<String> load();
  Future<void> save(String data);

  Future<void> delete();
}
