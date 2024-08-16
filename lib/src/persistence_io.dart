import 'dart:io';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:simple_json_persistence/src/persistence_base.dart';

final _logger = Logger('persistence_io');

const _subDirName = 'json';

//typedef BaseDirectoryBuilder = Future<String> Function();

class StoreBackendIo extends StoreBackend {
  StoreBackendIo._({
    required this.documentsDirBuilder,
  });

  @visibleForTesting
  static BaseDirectoryBuilder defaultBaseDirectoryBuilder = () =>
      // TODO we should probably also use getLibraryDirectory on iOS?
      (Platform.isWindows
              ? getLibraryDirectory()
              : getApplicationDocumentsDirectory())
          .then((dir) => p.join(dir.path, _subDirName));

  final BaseDirectoryBuilder documentsDirBuilder;

  Future<File> _init(String name) async {
    final file = File(p.join(await documentsDirBuilder(), '$name.json'));
    await file.parent.create(recursive: true);
    return file;
  }

  @override
  Future<Store> storeForFile(String name) async => StoreIo(await _init(name));
}

StoreBackend createStoreBackend([BaseDirectoryBuilder? baseDirectoryBuilder]) =>
    StoreBackendIo._(
        documentsDirBuilder: baseDirectoryBuilder ??
            StoreBackend.defaultBaseDirectoryBuilder ??
            StoreBackendIo.defaultBaseDirectoryBuilder);

class StoreIo extends Store {
  StoreIo(this._file) {
    _logger.fine('Writing into $_file');
  }

  final File _file;

  @override
  Future<void> delete() async {
    if (!_file.existsSync()) {
      return;
    }
    await _file.delete();
  }

  @override
  Future<bool> exists() async {
    return _file.existsSync();
  }

  @override
  Future<String> load() async {
    return _file.readAsString();
  }

  @override
  Future<void> save(String data) async {
    await _file.writeAsString(data, flush: true);
  }
}
