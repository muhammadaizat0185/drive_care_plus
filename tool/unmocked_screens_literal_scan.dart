// Validates: Requirements 12.1, 3.11.
//
// Static literal scanner for the eight unmocked-screen sweep (Task 14.9).
//
// Walks a list of Dart source files and flags any literal that the
// figma-ui-redesign sweep should have routed through a token reference:
//
//   * Hex colors written via `Color(0xFF…)` / `Color(0x…)` calls — every
//     such literal is reported, regardless of whether the value matches a
//     known token, because token colors are addressed via
//     `AppColors.<name>` or via `AppColorsExt` extensions instead.
//   * `IntegerLiteral` / `DoubleLiteral` numeric literals whose value
//     matches a known `AppSpacing.*` or `AppRadii.*` value — these should
//     be addressed via the token symbols / `AppSpacingExt` / `AppRadiiExt`
//     instead.
//   * `TextStyle(...)` constructor calls — typography is owned by the
//     `AppTypography` Token_Set, so the redesigned screens compose
//     `typography.<role>.copyWith(color: ...)` rather than constructing
//     fresh `TextStyle`s.
//   * `BorderRadius.circular(<n>)` calls where `n` is a non-zero numeric
//     literal that matches a known radius token — these must read off
//     `AppRadiiExt` instead.
//
// Exit codes:
//   0 — no findings
//   1 — one or more findings
//   2 — internal error (bad path, parse failure)
//
// Usage:
//   dart run tool/unmocked_screens_literal_scan.dart
//   dart run tool/unmocked_screens_literal_scan.dart <file1> <file2> ...
//
// When invoked with no arguments the scanner walks the canonical eight
// unmocked-screen paths (and any extracted helper modules under their
// per-screen subfolders). When invoked with explicit file arguments the
// scanner walks exactly those files — useful for `pre-commit`-style hooks
// that operate on the changed-files set.

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;

/// Default targets — the eight unmocked screens plus any per-screen helper
/// modules under `lib/screens/<name>/_widgets.dart`. Resolved relative to
/// the package root located by walking up from `Directory.current`.
const List<String> _defaultTargets = <String>[
  'lib/screens/booking_screen.dart',
  'lib/screens/booking/_widgets.dart',
  'lib/screens/journey_log_screen.dart',
  'lib/screens/maintenance_screen.dart',
  'lib/screens/notifications_screen.dart',
  'lib/screens/splash_screen.dart',
  'lib/screens/toyyibpay_webview_screen.dart',
  'lib/screens/trip_planner_screen.dart',
  'lib/screens/trip_planner/_widgets.dart',
  'lib/screens/trip_tracking_screen.dart',
];

/// Spacing values from `AppSpacing` (xs..xxxxl). Sourced from
/// `lib/core/theme/tokens/app_spacing.dart`.
final Set<double> _spacingValues = <double>{
  4.0, 8.0, 12.0, 16.0, 24.0, 32.0, 40.0, 48.0,
};

/// Radius values from `AppRadii` (small..xLarge). Sourced from
/// `lib/core/theme/tokens/app_radii.dart`.
final Set<double> _radiiValues = <double>{12.0, 16.0, 24.0, 32.0};

/// Combined token-numeric values. Spacing and radii share the values 12,
/// 16, 24, 32 — so a numeric literal of `16` reported by the scanner is
/// flagged whether the author meant spacing or radius. The remediation in
/// either case is the same: route through the matching token extension.
final Set<double> _tokenNumericValues = <double>{
  ..._spacingValues,
  ..._radiiValues,
};

/// One finding emitted by the scanner.
class LiteralFinding {
  LiteralFinding({
    required this.file,
    required this.line,
    required this.snippet,
    required this.reason,
  });

  final String file;
  final int line;
  final String snippet;
  final String reason;

  @override
  String toString() => '$file:$line — $reason — $snippet';
}

/// Locate the package root by walking up from CWD until a `pubspec.yaml`
/// is found. Mirrors the helper used by `tool/reference_source_guard.dart`.
String _packageRoot() {
  Directory dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
      return dir.path;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      stderr.writeln(
        'Unmocked screens literal scan ERROR: could not locate '
        'pubspec.yaml from ${Directory.current.path}',
      );
      exit(2);
    }
    dir = parent;
  }
}

Future<void> main(List<String> args) async {
  final String root = _packageRoot();

  // Resolve target file paths. With no args, fall back to the canonical
  // eight unmocked-screen paths plus their per-screen helper modules.
  final List<String> targets = args.isEmpty
      ? _defaultTargets.map((rel) => p.join(root, rel)).toList()
      : args.map(p.normalize).toList();

  final List<LiteralFinding> findings = <LiteralFinding>[];

  for (final String target in targets) {
    final File file = File(target);
    if (!file.existsSync()) {
      // Missing helper modules under `lib/screens/<name>/_widgets.dart` are
      // not a hard failure — those files only exist when the matching
      // screen sweep needed an extracted module. Skip silently.
      continue;
    }
    try {
      _scanDart(file, findings);
    } catch (e) {
      stderr.writeln(
        'Unmocked screens literal scan ERROR: failed to parse ${file.path}: '
        '$e',
      );
      exit(2);
    }
  }

  if (findings.isNotEmpty) {
    stderr.writeln(
      'Unmocked screens literal scan FAILED: ${findings.length} finding(s):',
    );
    for (final LiteralFinding finding in findings) {
      stderr.writeln('  $finding');
    }
    exit(1);
  }
  stdout.writeln(
    'Unmocked screens literal scan PASSED: no findings.',
  );
}

/// Scans a single Dart file for token-leaky literals and appends every
/// finding to [findings]. Public so the unit test under
/// `test/tool/unmocked_screens_literal_scan_test.dart` can call it with
/// arbitrary paths.
void scanFileForFindings(File file, List<LiteralFinding> findings) {
  _scanDart(file, findings);
}

void _scanDart(File file, List<LiteralFinding> findings) {
  final ParseStringResult result = parseFile(
    path: file.absolute.path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final LineInfo lineInfo = result.lineInfo;
  result.unit.accept(_LiteralVisitor(file.path, lineInfo, findings));
}

/// AST visitor that flags hex colors, token-equivalent numerics,
/// `TextStyle(...)` calls, and `BorderRadius.circular(<n>)` calls where
/// `n` matches a radius token.
class _LiteralVisitor extends RecursiveAstVisitor<void> {
  _LiteralVisitor(this.filePath, this.lineInfo, this.findings);

  final String filePath;
  final LineInfo lineInfo;
  final List<LiteralFinding> findings;

  /// Tracks whether we are currently inside an instance-creation expression
  /// for `Color(...)` so the numeric inside `Color(0xFF10B981)` is reported
  /// once (as a hex color) instead of twice (also as an integer literal).
  int _insideColorCallDepth = 0;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String typeName = node.constructorName.type.toSource();

    if (typeName == 'Color') {
      // Any `Color(0x...)` call is flagged. Token colors must be addressed
      // via `AppColors.<name>` or via `AppColorsExt` extensions instead.
      final List<Expression> args = node.argumentList.arguments;
      final String argSnippet =
          args.map((Expression a) => a.toSource()).join(', ');
      _emit(node, 'Color(0x...) literal — use AppColors / AppColorsExt',
          'Color($argSnippet)');

      _insideColorCallDepth++;
      super.visitInstanceCreationExpression(node);
      _insideColorCallDepth--;
      return;
    }

    if (typeName == 'TextStyle') {
      // `TextStyle(...)` constructor calls are reported in full because
      // typography is owned by the `AppTypography` Token_Set.
      _emit(
        node,
        'TextStyle(...) literal — use AppTypography / AppTypographyExt',
        node.toSource(),
      );
    }

    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Detect `BorderRadius.circular(<n>)` where `n` is a non-zero numeric
    // literal whose value matches a known radius token. The remediation is
    // `BorderRadius.circular(radii.<role>)` — i.e. read the radius from
    // the `AppRadiiExt` extension on `Theme.of(context)`.
    final String? targetSource = node.target?.toSource();
    if (targetSource == 'BorderRadius' &&
        node.methodName.name == 'circular' &&
        node.argumentList.arguments.length == 1) {
      final Expression arg = node.argumentList.arguments.first;
      final double? value = _literalAsDouble(arg);
      if (value != null && value != 0.0 && _radiiValues.contains(value)) {
        _emit(
          node,
          'BorderRadius.circular(<radius-token>) — use AppRadiiExt',
          node.toSource(),
        );
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    if (_insideColorCallDepth == 0) {
      _maybeFlagNumeric(node, node.value?.toDouble());
    }
    super.visitIntegerLiteral(node);
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    if (_insideColorCallDepth == 0) {
      _maybeFlagNumeric(node, node.value);
    }
    super.visitDoubleLiteral(node);
  }

  /// Returns the literal value of [expr] when it is a `+`/`-`-free numeric
  /// literal, otherwise `null`. Used to inspect arguments to
  /// `BorderRadius.circular(...)`.
  static double? _literalAsDouble(Expression expr) {
    if (expr is IntegerLiteral) {
      return expr.value?.toDouble();
    }
    if (expr is DoubleLiteral) {
      return expr.value;
    }
    return null;
  }

  /// Reports a numeric literal when its value matches a known token
  /// (spacing or radii). The 0.0 / 0 literals are silently ignored — they
  /// are routinely used for `Offset(0, 0)`, `EdgeInsets.zero`, and similar
  /// non-token positions.
  void _maybeFlagNumeric(AstNode node, double? value) {
    if (value == null || value == 0.0) {
      return;
    }
    if (_tokenNumericValues.contains(value)) {
      _emit(
        node,
        'numeric literal $value matches AppSpacing/AppRadii — use the matching token',
        node.toSource(),
      );
    }
  }

  void _emit(AstNode node, String reason, String snippet) {
    final CharacterLocation loc = lineInfo.getLocation(node.offset);
    findings.add(
      LiteralFinding(
        file: filePath,
        line: loc.lineNumber,
        snippet: snippet,
        reason: reason,
      ),
    );
  }
}
