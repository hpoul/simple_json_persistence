import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:simple_json_persistence/simple_json_persistence.dart';

final _logger = Logger('test_util');

Matcher notSame<T>(T expected) => predicate<T>(
    (actual) => !identical(actual, expected), 'NOT same instance as $expected');

class TestUtil {
  static Future<BaseDirectoryBuilder> baseDirectoryBuilder() async {
    final directory = await Directory.systemTemp
        .createTemp('flutter_simple_json_persistence_test');
    return () async => directory.path;
  }

  static Future<void> mockPathProvider() async {
    // Create a temporary directory.
    final directory = await Directory.systemTemp
        .createTemp('flutter_simple_json_persistence_test');

    // Mock out the MethodChannel for the path_provider plugin.
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      // If you're getting the apps documents directory, return the path to the
      // temp directory on the test environment instead.
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        _logger.info('Using app directory $directory');
        return directory.path;
      }
      return null;
    });
  }
}
