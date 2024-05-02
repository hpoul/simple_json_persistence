import 'package:simple_json_persistence/src/persistence_base.dart';
import 'package:web/web.dart' as web;

class StoreBackendHtml extends StoreBackend {
  @override
  Future<Store> storeForFile(String name) async {
    return StoreHtml(web.window.localStorage, name);
  }
}

StoreBackend createStoreBackend([BaseDirectoryBuilder? baseDirectoryBuilder]) =>
    StoreBackendHtml();

class StoreHtml extends Store {
  StoreHtml(this._storage, this._name);

  final web.Storage _storage;
  final String _name;

  @override
  Future<void> delete() async {
    _storage.removeItem(_name);
  }

  @override
  Future<bool> exists() async {
    return _storage.getItem(_name) != null;
  }

  @override
  Future<String> load() async {
    final ret = _storage[_name];
    if (ret == null) {
      throw StateError('Store $_name does not yet exist.');
    }
    return ret;
  }

  @override
  Future<void> save(String data) async {
    _storage[_name] = data;
  }
}
