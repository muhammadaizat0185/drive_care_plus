// Feature: figma-ui-redesign, Property 17: positive-decimal input filter
//
// Validates: Requirements 9.2
//
// ===========================================================================
// Property statement
// ===========================================================================
//
// For any string `s`, when typed into a field configured with the
// `PositiveDecimalFormatter`, the resulting controller text matches
// the regex `^[0-9]*\.?[0-9]*$` exactly. Equivalently, the formatter
// rejects any keystroke whose proposed `newValue.text` does not match
// the regex by reverting to the prior value, leaving the controller
// text in a state where the predicate is invariant across every
// keystroke sequence the formatter sees.
//
// This pins Requirement 9.2 ("accept positive decimal numeric input
// only") so a regression that allows letters, signs, multiple dots,
// or whitespace in any of the three numeric fields cannot quietly
// pass.
//
// ===========================================================================
// Note on PBT shape
// ===========================================================================
//
// The figma-ui-redesign tasks file flags this case as `[PBT]`. The
// underlying property is a pure `TextInputFormatter.formatEditUpdate`
// contract: given any prior value and any proposed new value, the
// returned `TextEditingValue.text` must match the regex.
//
// Glados-style pure-function property tests work here because the
// formatter is itself a pure function over `(oldValue, newValue)`. We
// generate any pair of arbitrary strings, cast them as `oldValue` and
// `newValue` text values, run the formatter, and assert the regex
// holds on the result.
//
// The 200-run configuration below comfortably exceeds the
// 100-iteration minimum required by the tasks file.

import 'package:drive_care_plus/screens/refuel/_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the symbols re-exported from `package:test` that collide with
// the matcher symbols re-exported by `package:flutter_test`.
import 'package:glados/glados.dart'
    hide
        expect,
        equals,
        isFalse,
        isTrue,
        isNotNull,
        isNull,
        isEmpty,
        inInclusiveRange,
        test,
        group,
        setUp,
        tearDown,
        setUpAll,
        tearDownAll,
        addTearDown;

/// Build a `TextEditingValue` from arbitrary text. Selection is held
/// at the end of the text — the formatter contract under test here
/// is purely about the `text` field, not selection / composing
/// ranges, so a fixed selection is fine and reduces shrinking noise.
TextEditingValue _value(String text) =>
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));

/// Generator of arbitrary text inputs. Covers digits, the decimal
/// point, the negative sign, letters, whitespace, and a few
/// punctuation chars so the formatter is exercised across both the
/// "matches the regex" and "does not match the regex" branches.
const String _inputCharset = '0123456789.-+eEabcXYZ \t\n,;%/\\';

Generator<String> get _input => any.stringOf(_inputCharset);

void main() {
  // ---------------------------------------------------------------------
  // Property 17 — Glados-driven property test over arbitrary
  // (priorText, newText) pairs.
  // ---------------------------------------------------------------------
  Glados2<String, String>(
    _input,
    _input,
    ExploreConfig(numRuns: 200),
  ).test(
    'PositiveDecimalFormatter never produces controller text that '
    'fails the positive-decimal regex',
    (String priorText, String newText) {
      const PositiveDecimalFormatter formatter = PositiveDecimalFormatter();
      final TextEditingValue result = formatter.formatEditUpdate(
        _value(priorText),
        _value(newText),
      );

      // Headline property: the result text always matches the regex.
      // The formatter has two branches:
      //   * If `newText` matches → result == newValue (text matches).
      //   * If `newText` does NOT match → result == oldValue (and the
      //     prior text must also match because the prior value was
      //     itself produced by the formatter, or it's the empty
      //     string from a fresh controller).
      //
      // For the property to hold across the second branch we must
      // assume the prior text is valid. The PBT therefore restricts
      // the prior text to values the regex accepts; anything else
      // would be unreachable in production because the formatter is
      // applied to every keystroke from a clean field.
      if (PositiveDecimalFormatter.pattern.hasMatch(priorText)) {
        expect(
          PositiveDecimalFormatter.pattern.hasMatch(result.text),
          isTrue,
          reason: 'PositiveDecimalFormatter must return controller text '
              'that matches ^[0-9]*\\.?[0-9]*\$. Got: "${result.text}" from '
              'prior "$priorText" + new "$newText".',
        );
      }
    },
  );

  // ---------------------------------------------------------------------
  // Special-case unit tests — pin the boundary inputs the property
  // generator can already reach, but where a named test surfaces
  // regressions more clearly than a generated counterexample.
  // ---------------------------------------------------------------------
  group('PositiveDecimalFormatter special cases', () {
    const PositiveDecimalFormatter formatter = PositiveDecimalFormatter();

    test('accepts empty string', () {
      final TextEditingValue r =
          formatter.formatEditUpdate(_value(''), _value(''));
      expect(r.text, equals(''));
    });

    test('accepts plain digits', () {
      final TextEditingValue r =
          formatter.formatEditUpdate(_value(''), _value('12345'));
      expect(r.text, equals('12345'));
    });

    test('accepts single decimal point with digits', () {
      final TextEditingValue r =
          formatter.formatEditUpdate(_value(''), _value('12.34'));
      expect(r.text, equals('12.34'));
    });

    test('accepts trailing decimal point', () {
      final TextEditingValue r =
          formatter.formatEditUpdate(_value(''), _value('12.'));
      expect(r.text, equals('12.'));
    });

    test('accepts leading decimal point', () {
      final TextEditingValue r =
          formatter.formatEditUpdate(_value(''), _value('.5'));
      expect(r.text, equals('.5'));
    });

    test('rejects negative sign by reverting', () {
      final TextEditingValue r =
          formatter.formatEditUpdate(_value(''), _value('-5'));
      expect(r.text, equals(''));
    });

    test('rejects letters by reverting', () {
      final TextEditingValue r =
          formatter.formatEditUpdate(_value('1'), _value('1a'));
      expect(r.text, equals('1'));
    });

    test('rejects multiple decimal points by reverting', () {
      final TextEditingValue r =
          formatter.formatEditUpdate(_value('1.2'), _value('1.2.3'));
      expect(r.text, equals('1.2'));
    });

    test('rejects whitespace by reverting', () {
      final TextEditingValue r =
          formatter.formatEditUpdate(_value(''), _value(' 1'));
      expect(r.text, equals(''));
    });
  });
}
