// Feature: figma-ui-redesign, Property 12: filter correctness
//
// Validates: Requirements 7.3, 10.1
//
// `filterByQueryAndCategory<T>(all, query, category, {nameOf, categoryOf})`
// is the pure source-of-truth filter used by both the workshops browse list
// (Requirement 7.3) and the document vault list (Requirement 10.1). It
// implements the case-insensitive substring AND category-match predicate:
//
//   keep e iff
//     nameOf(e).toLowerCase().contains(query.toLowerCase())
//     AND
//     (category equals 'All' (case-insensitive) OR categoryOf(e) == category)
//
// while preserving the relative order of kept elements from `all`.
//
// The property body asserts three independently-derived invariants:
//   1. Every returned element satisfies the predicate (kept items are
//      genuinely matches).
//   2. Every excluded element fails the predicate (no real match was
//      dropped).
//   3. Order preservation: the filtered output appears in the same relative
//      order as in `all`, i.e. the indices of the kept elements are
//      strictly increasing in the original list.
//
// Generators:
//   - `items: List<_Item>` via `any.list(_itemGenerator)`. The list
//     generator produces lists of any non-negative length, including the
//     empty list. Each `_Item` carries:
//       * a name drawn from a tiny charset (`abcAB123 `) so `toLowerCase`
//         and substring containment exercise both case folding and
//         multi-occurrence matches without exploding the input space;
//       * a category drawn from a fixed pool that mixes the workshop
//         categories (`All / Repair / CarWash / Parts`), the document
//         vault categories (`Insurance / Tax / Receipt / Warranty`), and
//         two synthetic out-of-set values (`X / Y`) to exercise the
//         "category does not match" branch.
//   - `query: String` via `any.stringOf('abc123 ')`. Sharing characters
//     with the item-name charset is important — using disjoint pools would
//     bias the predicate toward "no match" and starve the kept-items
//     branch of coverage. The empty string is also produced (an empty
//     query matches every name, which exercises the "all kept" branch).
//   - `category: String` via `any.choose([...])` from a fixed list that
//     includes the wildcard `'All'`, every category that can appear on an
//     item, and one value (`Z`) that no item ever carries — so the
//     "wildcard kept", "category match kept", and "category mismatch
//     dropped" branches are all exercised.
//
// Glados is configured for 200 runs to comfortably exceed the 100-iteration
// minimum required by the task.

import 'package:drive_care_plus/core/util/search_filter.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide the symbols re-exported from `package:test` that collide with the
// matcher symbols re-exported by `package:flutter_test`. Mirrors the pattern
// used by `test/core/util/greeting_test.dart`,
// `test/core/util/format_bytes_test.dart`, and
// `test/core/util/expiry_test.dart`.
import 'package:glados/glados.dart'
    hide
        expect,
        equals,
        isFalse,
        isTrue,
        isNotNull,
        inInclusiveRange,
        test,
        group,
        setUp,
        tearDown,
        setUpAll,
        tearDownAll,
        addTearDown;

/// Inline test record used to exercise the generic helper without depending
/// on the production `Workshop` or `Document` models. Keeping the type
/// minimal — just the two fields the predicate consults — makes the test's
/// input space identical to the helper's contract surface.
class _Item {
  final String name;
  final String category;
  const _Item(this.name, this.category);

  @override
  String toString() => '_Item(name: "$name", category: "$category")';
}

/// Character pool fed to `any.stringOf(...)` for both item names and the
/// `query` argument. Mixing case (`abcAB`), digits (`123`), and a space
/// ensures the case-insensitive substring predicate is exercised against
/// realistic mixed-case content while keeping the input space tiny.
const String _nameCharset = 'abcAB123 ';

/// Fixed pool of category values an `_Item` can carry. Combines the
/// workshops categories (`All / Repair / CarWash / Parts`), the document
/// vault categories (`Insurance / Tax / Receipt / Warranty`), and two
/// synthetic values (`X / Y`) that have no match in either screen so the
/// "category mismatch" branch is exercised.
const List<String> _itemCategoryPool = [
  'All',
  'Repair',
  'CarWash',
  'Parts',
  'Insurance',
  'Tax',
  'Receipt',
  'Warranty',
  'X',
  'Y',
];

/// Fixed pool of `category` argument values passed to the helper. Includes
/// the wildcard `'All'`, every `_itemCategoryPool` value, and one value
/// (`Z`) that no item ever carries — so we cover the wildcard branch, the
/// equal-category branch, and the never-matches branch.
const List<String> _filterCategoryPool = [
  'All',
  'Repair',
  'CarWash',
  'Parts',
  'Insurance',
  'Tax',
  'Receipt',
  'Warranty',
  'X',
  'Y',
  'Z',
];

/// Reference implementation of the predicate. Mirrors the branch logic in
/// [filterByQueryAndCategory] exactly so the property body asserts equality
/// of two independently-derived values.
bool _expectedKeep(_Item item, String query, String category) {
  final bool nameMatches =
      item.name.toLowerCase().contains(query.toLowerCase());
  if (!nameMatches) return false;
  if (category.toLowerCase() == 'all') return true;
  return item.category == category;
}

void main() {
  // Generator for a single `_Item`: combines a name and category. `combine2`
  // is preferred over chained `.map` for readability and so shrinking can
  // shrink each field independently.
  final Generator<_Item> itemGenerator = any.combine2<String, String, _Item>(
    any.stringOf(_nameCharset),
    any.choose<String>(_itemCategoryPool),
    (name, category) => _Item(name, category),
  );

  Glados3<List<_Item>, String, String>(
    any.list<_Item>(itemGenerator),
    any.stringOf(_nameCharset),
    any.choose<String>(_filterCategoryPool),
    ExploreConfig(numRuns: 200),
  ).test(
    'filterByQueryAndCategory(items, query, category): every returned '
    'element matches the predicate, every excluded element fails it, and '
    'the relative order of kept elements is preserved',
    (items, query, category) {
      final List<_Item> filtered = filterByQueryAndCategory<_Item>(
        items,
        query,
        category,
        nameOf: (i) => i.name,
        categoryOf: (i) => i.category,
      );

      // Property 12 — soundness: every returned element satisfies the
      // predicate.
      for (final _Item kept in filtered) {
        expect(
          _expectedKeep(kept, query, category),
          isTrue,
          reason:
              'filterByQueryAndCategory returned $kept which should NOT '
              'satisfy the predicate for query="$query", category="$category"',
        );
      }

      // Property 12 — completeness: every excluded element fails the
      // predicate. Build the kept set by reference identity (same `_Item`
      // instances, no equals/hashCode override required) so duplicates in
      // the input list are handled correctly.
      final Set<_Item> keptSet = Set<_Item>.identity()..addAll(filtered);
      for (final _Item original in items) {
        if (keptSet.contains(original)) continue;
        expect(
          _expectedKeep(original, query, category),
          isFalse,
          reason:
              'filterByQueryAndCategory excluded $original which DOES '
              'satisfy the predicate for query="$query", category="$category"',
        );
      }

      // Property 12 — order preservation: the filtered list is a
      // subsequence of `items`, i.e. each kept element's first
      // not-yet-consumed occurrence in `items` appears at a strictly
      // increasing index. We walk `items` once with a moving cursor and
      // confirm we can find every filtered element in order.
      int cursor = 0;
      for (final _Item kept in filtered) {
        bool found = false;
        while (cursor < items.length) {
          if (identical(items[cursor], kept)) {
            found = true;
            cursor++;
            break;
          }
          cursor++;
        }
        expect(
          found,
          isTrue,
          reason:
              'filterByQueryAndCategory output is not a subsequence of '
              'items: $kept appears in the filtered list but cannot be '
              'matched in order against the input '
              '(items=$items, filtered=$filtered, '
              'query="$query", category="$category")',
        );
      }

      // Length sanity: filtered cannot be longer than the input.
      expect(
        filtered.length <= items.length,
        isTrue,
        reason:
            'filterByQueryAndCategory returned ${filtered.length} items '
            'from a ${items.length}-element input — the filter must never '
            'add elements',
      );
    },
  );
}
