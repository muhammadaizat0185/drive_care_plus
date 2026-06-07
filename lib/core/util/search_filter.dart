/// Pure search/category filter helper used by the workshops list and the
/// document vault.
///
/// The shared filter rule from the design (Workshops + Document Vault
/// sections) is:
///
/// ```
/// keep e iff
///   nameOf(e).toLowerCase().contains(query.toLowerCase())
///   AND
///   (category == 'All' OR categoryOf(e) == category)
/// ```
///
/// while preserving the relative order from the input list.
///
/// The concrete `filterWorkshops` wrapper added in Task 9.4 delegates to
/// [filterByQueryAndCategory] with `Workshop.name` as `nameOf` and
/// `Workshop.category.name` as `categoryOf` so the locked predicate stays
/// in one place and the property test in Task 3.8 covers both wrappers.
/// The `filterDocuments` wrapper added in Task 12.2 follows the same
/// pattern with `VaultDocument.title` and `VaultDocument.category`.
///
/// Pure: no IO, no side effects, deterministic for any input.
///
/// See: figma-ui-redesign Requirements 7.3, 10.1; Property 12.
library;

import '../../models/workshop.dart';
import '../../screens/document_vault/_widgets.dart';

/// Case-insensitive substring predicate.
///
/// Returns `true` iff [haystack] contains [needle] when both are compared
/// case-insensitively. An empty [needle] matches any [haystack] (including
/// the empty string), matching `String.contains('')` semantics.
///
/// Pure: no IO, no side effects.
bool matchesQuery(String haystack, String needle) {
  return haystack.toLowerCase().contains(needle.toLowerCase());
}

/// Returns `true` iff [category] is the sentinel value that disables the
/// per-element category check.
///
/// The design uses the literal `'All'`; we accept any case-variant of that
/// word so callers do not need to canonicalize the value at every call site.
bool _isAllCategory(String category) {
  return category.toLowerCase() == 'all';
}

/// Generic case-insensitive substring AND category-match filter.
///
/// Returns the elements of [all] whose:
///
/// * name (extracted via [nameOf]) contains [query] case-insensitively, AND
/// * category (extracted via [categoryOf]) equals [category].
///
/// When [category] equals `'All'` (case-insensitive) the category check is
/// skipped and only the substring predicate is applied.
///
/// The relative order of kept elements matches their order in [all].
///
/// This is the single source of truth for the filter rule shared by the
/// workshops browse list (Requirement 7.3) and the document vault list
/// (Requirement 10.1). Concrete `filterWorkshops` and `filterDocuments`
/// wrappers added later delegate here so the predicate is locked once.
///
/// Pure: no IO, no side effects, deterministic for any input.
List<T> filterByQueryAndCategory<T>(
  List<T> all,
  String query,
  String category, {
  required String Function(T) nameOf,
  required String Function(T) categoryOf,
}) {
  final bool skipCategory = _isAllCategory(category);
  final String loweredQuery = query.toLowerCase();

  return all.where((T element) {
    final bool nameMatches =
        nameOf(element).toLowerCase().contains(loweredQuery);
    if (!nameMatches) {
      return false;
    }
    if (skipCategory) {
      return true;
    }
    return categoryOf(element) == category;
  }).toList(growable: false);
}

/// Concrete `Workshop` wrapper around [filterByQueryAndCategory] used by
/// the redesigned `workshop_map_screen.dart` Browse tab (Task 9.4).
///
/// Maps `Workshop.name` to `nameOf` and `Workshop.category.name` (e.g.
/// `'all'`, `'repair'`, `'carWash'`, `'parts'`) to `categoryOf` so the
/// generic predicate locks both the substring search and the category
/// match without duplicating logic. The chip row's "All" pill must pass
/// `'all'` (case-insensitive) as the [category] argument so the category
/// check is short-circuited.
///
/// Pure: no IO, no side effects, deterministic for any input.
///
/// See: figma-ui-redesign Requirements 7.3, Task 9.4; Property 12.
List<Workshop> filterWorkshops(
  List<Workshop> all,
  String query,
  String category,
) {
  return filterByQueryAndCategory<Workshop>(
    all,
    query,
    category,
    nameOf: (Workshop w) => w.name,
    categoryOf: (Workshop w) => w.category.name,
  );
}

/// Concrete `VaultDocument` wrapper around [filterByQueryAndCategory]
/// used by the redesigned `document_vault_screen.dart` (Task 12.2).
///
/// Maps `VaultDocument.title` to `nameOf` and `VaultDocument.category`
/// (one of `Insurance / Tax / Receipt / Warranty`) to `categoryOf` so
/// the same predicate that powers the workshops Browse tab lights the
/// vault list as well. The chip row's "All" pill must pass `'All'`
/// (case-insensitive) as the [category] argument so the category check
/// is short-circuited.
///
/// Pure: no IO, no side effects, deterministic for any input.
///
/// See: figma-ui-redesign Requirements 10.1, Task 12.2; Property 12.
List<VaultDocument> filterDocuments(
  List<VaultDocument> all,
  String query,
  String category,
) {
  return filterByQueryAndCategory<VaultDocument>(
    all,
    query,
    category,
    nameOf: (VaultDocument d) => d.title,
    categoryOf: (VaultDocument d) => d.category,
  );
}
