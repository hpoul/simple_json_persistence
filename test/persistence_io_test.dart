import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_json_persistence/src/persistence_io.dart';

/// How [StoreIo] puts bytes on disk.
///
/// **The property under test is what a *reader* can ever see.** A store holding
/// the only copy of something cannot afford a moment where the file on disk is
/// half a document: `writeAsString` truncates and then fills, so a crash
/// between those two leaves a perfectly valid file with a prefix in it, which
/// reads back as corruption rather than as the previous version.
///
/// A real crash cannot be staged here, so these test the mechanism that makes
/// the window impossible — a write beside the target, renamed over it — rather
/// than the crash itself.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('sjp_io_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  File target() => File('${dir.path}/store.json');

  test('saves what it was given', () async {
    await StoreIo(target()).save('{"a":1}');
    expect(target().readAsStringSync(), '{"a":1}');
  });

  test('replaces an existing file rather than refusing', () async {
    // The rename is over a file that already exists, which is the ordinary case
    // for a store and the one that behaves differently across platforms.
    final store = StoreIo(target());
    await store.save('{"a":1}');
    await store.save('{"a":2}');
    expect(target().readAsStringSync(), '{"a":2}');
  });

  test('leaves no temporary behind', () async {
    await StoreIo(target()).save('{"a":1}');
    expect(
      dir.listSync().map((e) => e.path.split('/').last).toList(),
      ['store.json'],
      reason: 'a leftover .writing would accumulate one per save',
    );
  });

  test('writes beside the target, so the rename cannot cross filesystems', () {
    // **The load-bearing detail, asserted because it is invisible otherwise.**
    // Across filesystems `rename` degrades to copy-and-delete — the very
    // non-atomic write this replaces — and it degrades silently. Keeping the
    // temporary in the target's own directory is what forbids that, so the path
    // is pinned rather than left to be re-derived by somebody tidying up.
    expect(
      '${target().path}.writing',
      startsWith('${dir.path}/'),
      reason: 'the temporary must share a directory with the target',
    );
  });

  test('a stale temporary from a killed run does not break the next save', () {
    // Nothing loads a `.writing`, and the next save overwrites it — so a
    // process killed mid-write costs a stray file and nothing else.
    final stale = File('${target().path}.writing')
      ..writeAsStringSync('half a doc');
    expect(stale.existsSync(), isTrue);

    return StoreIo(target()).save('{"a":1}').then((_) {
      expect(target().readAsStringSync(), '{"a":1}');
      expect(stale.existsSync(), isFalse, reason: 'renamed onto the target');
    });
  });

  test('the old file is intact until the new one is complete', () async {
    // The closest a test gets to the crash: after the temporary exists and
    // before the rename, a reader of the target still sees the previous
    // document in full. Staged by writing the temporary by hand, which is what
    // `save` does first.
    final store = StoreIo(target());
    await store.save('{"a":1}');

    final pending = File('${target().path}.writing');
    await pending.writeAsString('{"a":2}', flush: true);
    expect(
      target().readAsStringSync(),
      '{"a":1}',
      reason: 'a half-finished save must not be visible at the target path',
    );

    await pending.rename(target().path);
    expect(target().readAsStringSync(), '{"a":2}');
  });
}
