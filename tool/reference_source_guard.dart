// Validates: Requirements 15.1, 15.2, 15.4, 15.5
//
// Reference_Source guard.
//
// This Dart command-line script enforces that the gitignored Reference_Source
// folder (named "UI" + " Improvement" + " Suggestion") never enters the
// Flutter build. It walks the tracked Flutter sources and fails the run if it
// finds any Dart import/export/part directive, runtime string literal, or
// pubspec/asset entry that resolves into that folder.
//
// Scope of the walk:
//   1. `lib/**/*.dart`            (AST walk via package:analyzer)
//   2. `tool/**/*.dart`           (AST walk; this script's own file skipped)
//   3. `pubspec.yaml`             (text scan — covers `flutter.assets` paths)
//   4. `pubspec.lock`             (text scan)
//   5. `analysis_options.yaml`    (text scan)
//
// Exit codes:
//   0 — no leaks
//   1 — one or more leaks found
//   2 — internal error (could not parse a Dart file, missing project root)
//
// The guard exempts its own file by absolute path so that the literal
// `_needle` constant below does not flag itself. The needle is also assembled
// from adjacent string parts so a plain text grep over the script source does
// not surface a contiguous match either; the AST-level check below would
// nonetheless detect a real leak from any other file.

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;

/// Substring that, if found anywhere in a tracked source, indicates a leak.
/// Built from adjacent literals so this very file does not contain the needle
/// as a contiguous substring at the source level.
const String _needle = 'UI Improvement'
    ' '
    'Suggestion';

/// One detected leak.
class _Leak {
  _Leak(this.file, this.line, this.description);

  final String file;
  final int? line;
  final String description;

  @override
  String toString() {
    final String loc = line == null ? file : '$file:$line';
    return '$loc — $description';
  }
}

/// Locates the package root by walking up from CWD until a `pubspec.yaml`
/// is found.
String _packageRoot() {
  Directory dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
      return dir.path;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      stderr.writeln(
        'Reference_Source guard ERROR: could not locate pubspec.yaml '
        'starting from ${Directory.current.path}',
      );
      exit(2);
    }
    dir = parent;
  }
}

Future<void> main(List<String> args) async {
  final String root = _packageRoot();
  final String selfPath = _resolveSelfPath();
  final List<_Leak> leaks = <_Leak>[];

  // 1. Text scan: pubspec.yaml, pubspec.lock, analysis_options.yaml.
  final List<String> textPaths = <String>[
    p.join(root, 'pubspec.yaml'),
    p.join(root, 'pubspec.lock'),
    p.join(root, 'analysis_options.yaml'),
  ];
  for (final String path in textPaths) {
    final File f = File(path);
    if (f.existsSync()) {
      _scanText(f, leaks);
    }
  }

  // 2. AST scan: every .dart file under lib/.
  final Directory libDir = Directory(p.join(root, 'lib'));
  if (libDir.existsSync()) {
    for (final FileSystemEntity entity
        in libDir.listSync(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        _scanDart(entity, leaks);
      }
    }
  }

  // 3. AST scan: every .dart file under tool/, except this guard itself.
  final Directory toolDir = Directory(p.join(root, 'tool'));
  if (toolDir.existsSync()) {
    for (final FileSystemEntity entity
        in toolDir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String abs = p.normalize(p.absolute(entity.path));
      if (abs == selfPath) {
        continue;
      }
      _scanDart(entity, leaks);
    }
  }

  if (leaks.isNotEmpty) {
    stderr.writeln(
        'Reference_Source guard FAILED: ${leaks.length} leak(s):');
    for (final _Leak leak in leaks) {
      stderr.writeln('  $leak');
    }
    exit(1);
  }
  stdout.writeln('Reference_Source guard PASSED: no leaks found.');
}

/// Resolves the absolute path of this script for self-exemption.
String _resolveSelfPath() {
  try {
    final Uri uri = Platform.script;
    if (uri.scheme == 'file') {
      return p.normalize(p.absolute(uri.toFilePath()));
    }
  } catch (_) {
    // Fall through to the conventional location.
  }
  return p.normalize(
    p.absolute(p.join(_packageRoot(), 'tool', 'reference_source_guard.dart')),
  );
}

/// Scans a text file (yaml, lock) line-by-line for the needle.
void _scanText(File file, List<_Leak> leaks) {
  final List<String> lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains(_needle)) {
      leaks.add(_Leak(
        file.path,
        i + 1,
        'literal Reference_Source path found in text: "${lines[i].trim()}"',
      ));
    }
  }
}

/// Parses a Dart source via `package:analyzer` and inspects its AST for any
/// directive URI or string literal that contains the needle.
void _scanDart(File file, List<_Leak> leaks) {
  late final ParseStringResult result;
  try {
    result = parseFile(
      path: file.absolute.path,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
  } catch (e) {
    stderr.writeln(
        'Reference_Source guard ERROR: failed to parse ${file.path}: $e');
    exit(2);
  }

  final LineInfo lineInfo = result.lineInfo;

  // Inspect every URI-bearing directive: import / export / part.
  for (final Directive directive in result.unit.directives) {
    StringLiteral? uriLiteral;
    String? kind;
    if (directive is ImportDirective) {
      uriLiteral = directive.uri;
      kind = 'import';
    } else if (directive is ExportDirective) {
      uriLiteral = directive.uri;
      kind = 'export';
    } else if (directive is PartDirective) {
      uriLiteral = directive.uri;
      kind = 'part';
    }
    if (uriLiteral == null || kind == null) {
      continue;
    }
    final String? uriValue = uriLiteral.stringValue;
    if (uriValue != null && uriValue.contains(_needle)) {
      final CharacterLocation loc =
          lineInfo.getLocation(uriLiteral.offset);
      leaks.add(_Leak(
        file.path,
        loc.lineNumber,
        '$kind directive URI resolves into Reference_Source: "$uriValue"',
      ));
    }
  }

  // Visit every string literal (covers asset paths flowing into
  // rootBundle.load, File(...), Image.asset(...), etc.).
  result.unit.accept(_StringLiteralVisitor(file.path, lineInfo, leaks));
}

/// Recursively walks the AST and reports any string literal whose evaluated
/// value contains the needle. Covers simple literals, adjacent strings, and
/// interpolations whose static parts alone form the needle.
class _StringLiteralVisitor extends RecursiveAstVisitor<void> {
  _StringLiteralVisitor(this.filePath, this.lineInfo, this.leaks);

  final String filePath;
  final LineInfo lineInfo;
  final List<_Leak> leaks;

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    final String? value = node.stringValue;
    if (value != null && value.contains(_needle)) {
      final CharacterLocation loc = lineInfo.getLocation(node.offset);
      leaks.add(_Leak(
        filePath,
        loc.lineNumber,
        'string literal references Reference_Source: "$value"',
      ));
    }
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    final String? value = node.stringValue;
    if (value != null && value.contains(_needle)) {
      final CharacterLocation loc = lineInfo.getLocation(node.offset);
      leaks.add(_Leak(
        filePath,
        loc.lineNumber,
        'adjacent string literals reference Reference_Source: "$value"',
      ));
    }
    super.visitAdjacentStrings(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    // Concatenate only the static parts; if the needle is fully contained in
    // those, it is a leak regardless of the interpolation expressions.
    final StringBuffer staticParts = StringBuffer();
    for (final InterpolationElement element in node.elements) {
      if (element is InterpolationString) {
        staticParts.write(element.value);
      }
    }
    if (staticParts.toString().contains(_needle)) {
      final CharacterLocation loc = lineInfo.getLocation(node.offset);
      leaks.add(_Leak(
        filePath,
        loc.lineNumber,
        'interpolated string references Reference_Source',
      ));
    }
    super.visitStringInterpolation(node);
  }
}
