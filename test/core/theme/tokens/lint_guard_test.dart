// Validates: Requirements 1.9, 1.12
//
// Lint guard: walk the AST of every token .dart file under
// `lib/core/theme/tokens/` (excluding the barrel) and assert that every
// class-level field carries the `static` and `const` modifiers. This locks
// in the design contract that token surfaces are compile-time only and that
// no token can be reassigned at runtime.
//
// The walk uses `package:analyzer` rather than reflection because Dart's
// runtime mirrors are unavailable in test environments and would not catch
// a future field added without `static const` (which would still compile
// today). The AST check rejects any non-`static const` field.

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Result of analysing a single token .dart file.
class _TokenFileReport {
  _TokenFileReport(this.file);

  final File file;

  /// All `ClassDeclaration` names discovered in the file.
  final List<String> classes = <String>[];

  /// Class-level fields that violate the `static const` rule. Each entry is
  /// `<ClassName>.<fieldName>: <reason>`.
  final List<String> violations = <String>[];

  /// Total class-level fields walked. Used to assert the walker actually
  /// visited fields and isn't a no-op due to a misconfigured AST.
  int fieldCount = 0;
}

/// Locates the package root from the current working directory by walking up
/// until a `pubspec.yaml` is found. The Flutter test runner invokes tests
/// with the CWD set to the package root, so this typically returns
/// immediately.
String _packageRoot() {
  Directory dir = Directory.current;
  while (true) {
    final File pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      return dir.path;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
          'Could not locate pubspec.yaml from ${Directory.current.path}');
    }
    dir = parent;
  }
}

_TokenFileReport _analyze(File file) {
  final _TokenFileReport report = _TokenFileReport(file);
  final ParseStringResult result = parseFile(
    path: file.absolute.path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );

  // Surface any parse errors before we walk; a parse error means the AST
  // walk below is unsound.
  expect(
    result.errors,
    isEmpty,
    reason: 'Parse errors in ${file.path}: ${result.errors}',
  );

  for (final CompilationUnitMember member in result.unit.declarations) {
    if (member is! ClassDeclaration) {
      continue;
    }
    final String className = member.namePart.typeName.lexeme;
    report.classes.add(className);

    final ClassBody classBody = member.body;
    if (classBody is! BlockClassBody) {
      // No `{}` body means no fields to inspect; skip.
      continue;
    }

    for (final ClassMember classMember in classBody.members) {
      if (classMember is! FieldDeclaration) {
        // Constructors, methods, getters, setters are unrelated to the
        // `static const` field rule.
        continue;
      }

      // `staticKeyword` is non-null when `static` is present.
      // `fields.isConst` is true when the variable list carries `const`.
      // The combination is exactly what `static const` means.
      final bool isStatic = classMember.isStatic;
      final bool isConst = classMember.fields.isConst;

      for (final VariableDeclaration variable in classMember.fields.variables) {
        report.fieldCount += 1;
        if (!isStatic || !isConst) {
          final List<String> missing = <String>[];
          if (!isStatic) missing.add('static');
          if (!isConst) missing.add('const');
          report.violations.add(
            '$className.${variable.name.lexeme} is missing '
            '${missing.join(' + ')} (must be `static const`)',
          );
        }
      }
    }
  }
  return report;
}

void main() {
  // Resolve the absolute path to the tokens directory so the test is
  // independent of the launcher's working directory.
  final String tokensDir =
      p.join(_packageRoot(), 'lib', 'core', 'theme', 'tokens');

  // Source files under audit. The barrel (`tokens.dart`) only contains
  // `export` directives and has no class declarations, so it is excluded
  // from the field-level AST walk. We still assert it exists so a refactor
  // that drops the barrel is caught here.
  final List<String> tokenFileNames = <String>[
    'app_colors.dart',
    'app_spacing.dart',
    'app_radii.dart',
    'app_typography.dart',
    'app_shadows.dart',
    'app_motion.dart',
  ];

  group('Lint guard: token classes only declare `static const` fields '
      '(Requirements 1.9, 1.12)', () {
    setUpAll(() {
      // Sanity: the tokens directory and barrel both exist.
      expect(Directory(tokensDir).existsSync(), isTrue,
          reason: 'tokens directory missing at $tokensDir');
      expect(File(p.join(tokensDir, 'tokens.dart')).existsSync(), isTrue,
          reason: 'tokens.dart barrel missing');
    });

    for (final String name in tokenFileNames) {
      test('$name declares only `static const` class fields', () {
        final File file = File(p.join(tokensDir, name));
        expect(file.existsSync(), isTrue,
            reason: 'token file missing: ${file.path}');

        final _TokenFileReport report = _analyze(file);

        // Every token file must declare at least one class, otherwise the
        // walker would silently pass for an empty file.
        expect(report.classes, isNotEmpty,
            reason: '$name must declare at least one class');

        // Every class must declare at least one field, otherwise the
        // walker wouldn't have anything to validate.
        expect(report.fieldCount, greaterThan(0),
            reason: '$name must declare at least one class field');

        // Final contract: no field may violate the `static const` rule.
        expect(
          report.violations,
          isEmpty,
          reason: 'Non-static-const fields detected in $name:\n  '
              '${report.violations.join('\n  ')}',
        );
      });
    }

    test('every token class has a private (non-public) constructor', () {
      // `static const`-only token surfaces should not be instantiable. The
      // existing convention in the module is `const ClassName._()`. This
      // assertion catches a regression that adds a public constructor and
      // re-introduces runtime allocation paths.
      for (final String name in tokenFileNames) {
        final File file = File(p.join(tokensDir, name));
        final ParseStringResult result = parseFile(
          path: file.absolute.path,
          featureSet: FeatureSet.latestLanguageVersion(),
          throwIfDiagnostics: false,
        );

        for (final CompilationUnitMember member
            in result.unit.declarations) {
          if (member is! ClassDeclaration) {
            continue;
          }
          final String className = member.namePart.typeName.lexeme;
          final ClassBody classBody = member.body;
          if (classBody is! BlockClassBody) {
            continue;
          }
          for (final ClassMember classMember in classBody.members) {
            if (classMember is! ConstructorDeclaration) {
              continue;
            }
            final String? ctorName = classMember.name?.lexeme;
            // An unnamed constructor (`null` ctorName) is implicitly public,
            // which would violate the no-instantiation contract. Named
            // constructors must be private (start with `_`).
            expect(ctorName, isNotNull,
                reason: '$className in $name has a public unnamed '
                    'constructor; expected a private named constructor '
                    'like `ClassName._()`');
            expect(ctorName!.startsWith('_'), isTrue,
                reason: '$className.$ctorName in $name must be private '
                    '(start with `_`)');
          }
        }
      }
    });
  });
}
