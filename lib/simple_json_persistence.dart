library simple_json_persistence;

export 'src/persistence_base.dart';
export 'src/persistence_noop.dart'
    if (dart.library.io) 'src/persistence_io.dart'
    if (dart.library.js_interop) 'src/persistence_html.dart';
export 'src/simple_json_persistence.dart';
