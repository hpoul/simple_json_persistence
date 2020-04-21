typedef BaseDirectoryBuilder = Future<String> Function();

abstract class StoreBackend {
  Future<Store> storeForFile(String name);
}

abstract class Store {
  Future<bool> exists();
  Future<String> load();
  Future<void> save(String data);

  Future<void> delete();
}
