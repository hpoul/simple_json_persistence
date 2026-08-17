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

  /// Replaces the file, and is never observable half-written.
  ///
  /// **Writing in place is the failure this avoids.** `writeAsString` truncates
  /// the file and then fills it, so a crash, a kill or a flat battery between
  /// those two leaves a perfectly valid file containing half a document — which
  /// reads back as corruption rather than as the previous version. For a store
  /// holding the only copy of something the window is small and the consequence
  /// is total.
  ///
  /// Writing beside and renaming over closes it: `rename` is atomic on a single
  /// filesystem, so a reader sees either the whole old file or the whole new
  /// one and never a prefix of either.
  ///
  /// **The temporary sits next to the target rather than in a temp directory**,
  /// and that is the load-bearing detail: across filesystems `rename` degrades
  /// to copy-and-delete, which is exactly the non-atomic write this replaces,
  /// and it would degrade silently.
  ///
  /// A `.writing` left behind by a killed process is harmless — nothing loads
  /// it, and the next save overwrites it.
  @override
  Future<void> save(String data) async {
    final pending = File('${_file.path}.writing');
    await pending.writeAsString(data, flush: true);
    await pending.rename(_file.path);
  }
}
