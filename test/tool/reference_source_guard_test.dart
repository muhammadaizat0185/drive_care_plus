// Validates: Requirements 15.6
//
// Negative-path test for `tool/reference_source_guard.dart`.
//
// The guard exits 0 on a clean tree and exits non-zero whenever a Dart import,
// pubspec asset entry, or runtime string literal under `lib/`, `tool/`, or
// the root pubspec/analysis files resolves into the gitignored
// Reference_Source folder.
//
// Two cases are exercised by spawning the guard as a child Dart process via
// `Process.runSync`:
//
//   1. Positive path: run the guard against the current project state; the
//      exit code MUST be 0 (no leaks).
//
//   2. Negative path: drop a temporary `lib/__leak_probe_temp.dart` whose
//      contents contain the Reference_Source needle as a contiguous string
//      literal, run the guard, and assert the exit code is non-zero. The
//      file is removed in `finally` so the project stays clean even if the
//      assertion fails.
//
// The needle is assembled from adjacent string parts so this test file
// itself never contains the contiguous substring at the source level. This
// keeps the test robust if the guard's scan ever extends to the `test/` tree.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The Reference_Source needle, assembled from adjacent string parts so this
/// file does not embed the contiguous substring at the source level.
const String _needle = 'UI Improvement'
    ' '
    'Suggestion';

void main() {
  late String projectRoot;
  late File leakFile;

  setUpAll(() {
    projectRoot = _findPackageRoot();
    leakFile = File(p.join(projectRoot, 'lib', '__leak_probe_temp.dart'));
  });

  tearDown(() {
    // Defensive cleanup in case a test bailed before its own finally.
    if (leakFile.existsSync()) {
      leakFile.deleteSync();
    }
  });

  group('reference_source_guard', () {
    test('exits 0 on the current clean project state', () {
      final ProcessResult result = Process.runSync(
        'dart',
        <String>['run', 'tool/reference_source_guard.dart'],
        workingDirectory: projectRoot,
        runInShell: true,
      );

      expect(
        result.exitCode,
        0,
        reason:
            'The reference_source guard should pass on a clean tree.\n'
            'stdout: ${result.stdout}\n'
            'stderr: ${result.stderr}',
      );
    });

    test('exits non-zero when a leak file is present under lib/', () {
      // Build the leak file contents so the contiguous needle lands on disk
      // (the guard's AST visitor will see a SimpleStringLiteral whose value
      // contains the needle).
      final String leakContent =
          '// Temporary leak probe written by reference_source_guard_test.\n'
          '// Deleted automatically by the test in a finally block.\n'
          "const String __leakProbe = '$_needle';\n";

      try {
        leakFile.writeAsStringSync(leakContent);

        final ProcessResult result = Process.runSync(
          'dart',
          <String>['run', 'tool/reference_source_guard.dart'],
          workingDirectory: projectRoot,
          runInShell: true,
        );

        expect(
          result.exitCode,
          isNot(0),
          reason:
              'The reference_source guard should fail when a lib/ file '
              'contains a string literal that resolves into the '
              'Reference_Source folder.\n'
              'stdout: ${result.stdout}\n'
              'stderr: ${result.stderr}',
        );
      } finally {
        if (leakFile.existsSync()) {
          leakFile.deleteSync();
        }
      }
    });
  });
}

/// Walks up from the test's working directory until a `pubspec.yaml` is found
/// and returns that directory. `flutter test` runs with the project root as
/// CWD, but this fallback keeps the test resilient against runner changes.
String _findPackageRoot() {
  Directory dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
      return dir.path;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Could not locate pubspec.yaml starting from '
        '${Directory.current.path}',
      );
    }
    dir = parent;
  }
}
