// Modular building blocks for the redesigned Document Vault screen
// (`lib/screens/document_vault_screen.dart`).
//
// This module hosts the typed value class, store abstraction,
// validation helper, and the primary widget primitives of the
// redesigned vault (Tasks 12.1 – 12.7):
//
//   * [VaultDocument]              — Value type for a single saved
//                                    vault document carrying title,
//                                    category, note, expiry date, and
//                                    optional file-size metadata.
//   * [kVaultCategoryLabels]       — `All / Insurance / Tax / Receipt
//                                    / Warranty` chip row labels.
//   * [kVaultEditableCategories]   — Category options exposed in the
//                                    add/edit form (every label except
//                                    `All`, which is the chip-row
//                                    sentinel).
//   * [VaultDocumentStore]         — Persistence interface; the
//                                    production binding writes to
//                                    both `VehicleInsights` and
//                                    Firestore, the test binding stays
//                                    in-memory.
//   * [VehicleInsightsVaultDocumentStore]
//                                  — Default production binding that
//                                    persists through `VehicleInsights`
//                                    and writes a Firestore mirror to
//                                    the legacy `users/{uid}/documents`
//                                    collection.
//   * [InMemoryVaultDocumentStore] — Test store exposing `savedDocuments`
//                                    and a `failNext` switch to drive
//                                    the persistence-failure branch
//                                    (Requirement 10.7).
//   * [validateVaultDocumentInput] — Pure validator returning a
//                                    per-field error map used by the
//                                    add-document form.
//   * [VaultDocumentCard]          — Document card surface with title,
//                                    category badge, expiry status
//                                    indicator, and file-size copy
//                                    (Tasks 12.3, 12.4 / Requirements
//                                    10.3 – 10.5).
//   * [AddVaultDocumentSheet]      — Bottom-sheet body containing the
//                                    add-document form bound to a
//                                    [VaultDocumentStore] (Tasks 12.5,
//                                    12.6 / Requirements 10.6, 10.7).
//
// Visual constants flow from the design-token extensions on
// `Theme.of(context)`; no hex colors, spacing, radii, or typography
// literals from the Token_Sets are inlined (Requirement 3.11).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';
import '../../core/util/expiry.dart';
import '../../core/util/format_bytes.dart';
import '../../services/vehicle_insights.dart';
import '../../widgets/ui/ui.dart';

// ===========================================================================
// VaultDocument
// ===========================================================================

/// Single saved vault document.
///
/// The legacy `VehicleInsights.documents` API is `Map<String, dynamic>`
/// based, so [fromMap] and [toMap] are provided so the redesigned card,
/// the filter helper, and the tests can share one typed shape while the
/// underlying persistence stays untouched (Task 12.4 scope: "expose a
/// small typed value class ... so the filter helper, the card widget,
/// and the tests share one type").
@immutable
class VaultDocument {
  /// Display title rendered on the card with ellipsis on overflow.
  final String title;

  /// Category label. One of [kVaultEditableCategories]
  /// (`Insurance / Tax / Receipt / Warranty`).
  final String category;

  /// Optional free-form note.
  final String note;

  /// Expiry date when the underlying document carries one. `null` when
  /// the user has not picked a date — the card renders "No expiry" in
  /// that branch (Requirement 10.3).
  final DateTime? expiryDate;

  /// Optional raw file size in bytes for the attached photo. `null`
  /// when the legacy seed data did not capture it; the card hides the
  /// file-size row in that case.
  final int? fileSizeBytes;

  const VaultDocument({
    required this.title,
    required this.category,
    this.note = '',
    this.expiryDate,
    this.fileSizeBytes,
  });

  /// Parse a `Map<String, dynamic>` produced by the legacy
  /// `VehicleInsights.documents` API into a [VaultDocument]. Tolerates
  /// missing fields by falling back to safe defaults; the legacy seed
  /// data uses string keys with no schema versioning.
  factory VaultDocument.fromMap(Map<String, dynamic> map) {
    return VaultDocument(
      title: (map['title'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'Receipt',
      note: () {
        final String? raw = map['note'] as String?;
        if (raw == null || raw == 'No notes') return '';
        return raw;
      }(),
      expiryDate: _parseLegacyDate(map['expiryDate'] as String? ?? ''),
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt(),
    );
  }

  /// Serialise back into the legacy Map shape so writes flow through
  /// the existing `VehicleInsights.addDocument` /
  /// `VehicleInsights.updateDocument` API without a schema migration.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'category': category,
      'note': note.isEmpty ? 'No notes' : note,
      'expiryDate': expiryDate == null
          ? ''
          : '${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}',
      if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
    };
  }

  /// Parse the legacy `DD/MM/YYYY` expiry-date string into a
  /// [DateTime], returning `null` for empty / malformed values.
  static DateTime? _parseLegacyDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      final List<String> parts = dateStr.split('/');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VaultDocument &&
        other.title == title &&
        other.category == category &&
        other.note == note &&
        other.expiryDate == expiryDate &&
        other.fileSizeBytes == fileSizeBytes;
  }

  @override
  int get hashCode =>
      Object.hash(title, category, note, expiryDate, fileSizeBytes);

  @override
  String toString() =>
      'VaultDocument(title: "$title", category: "$category", '
      'expiryDate: $expiryDate, fileSizeBytes: $fileSizeBytes)';
}

// ===========================================================================
// Category labels
// ===========================================================================

/// Chip-row labels rendered above the document list. The first entry
/// is the `All` sentinel that disables the per-document category check
/// inside `filterDocuments`; the remaining four match the design's
/// document categories exactly (Requirement 10.1).
const List<String> kVaultCategoryLabels = <String>[
  'All',
  'Insurance',
  'Tax',
  'Receipt',
  'Warranty',
];

/// Categories selectable from the add/edit form. Mirrors
/// [kVaultCategoryLabels] minus the `All` sentinel.
const List<String> kVaultEditableCategories = <String>[
  'Insurance',
  'Tax',
  'Receipt',
  'Warranty',
];

// ===========================================================================
// VaultDocumentStore
// ===========================================================================

/// Persistence boundary for vault documents. The screen depends on
/// this abstraction (instead of `VehicleInsights` and Firestore
/// directly) so widget tests can inject an in-memory binding without
/// dragging Firebase into the flutter_test process.
abstract class VaultDocumentStore {
  /// Persist [doc] to the underlying store.
  ///
  /// Throws when persistence fails so callers can branch into the
  /// error banner path required by Requirement 10.7.
  Future<void> save(VaultDocument doc);
}

/// Production binding that persists each document through both
/// `VehicleInsights.instance.addDocument` (which mirrors to
/// SharedPreferences) and the legacy
/// `users/{uid}/documents` Firestore collection. Keeps the call shape
/// of the pre-redesign add flow intact (Requirement 10.6) while
/// surfacing any Firestore failure to the caller through a thrown
/// exception so the error banner can render.
class VehicleInsightsVaultDocumentStore implements VaultDocumentStore {
  /// Optional explicit auth + firestore handles for tests; in
  /// production both default to the singleton instances.
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final VehicleInsights insights;

  VehicleInsightsVaultDocumentStore({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    VehicleInsights? insights,
  })  : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance,
        insights = insights ?? VehicleInsights.instance;

  @override
  Future<void> save(VaultDocument doc) async {
    // 1. Persist to the existing `VehicleInsights` store so the
    //    document appears in the local list immediately.
    await insights.addDocument(doc.toMap());

    // 2. Mirror to Firestore at `users/{uid}/documents` exactly as
    //    the pre-redesign code did, so cloud sync is preserved.
    final User? user = auth.currentUser;
    if (user == null) {
      // No signed-in user → local persistence is enough; not a
      // failure for the redesigned screen.
      return;
    }
    await firestore
        .collection('users')
        .doc(user.uid)
        .collection('documents')
        .add(<String, Object?>{
      'title': doc.title,
      'category': doc.category,
      'note': doc.note,
      'expiryDate': doc.expiryDate == null
          ? ''
          : '${doc.expiryDate!.day}/${doc.expiryDate!.month}/${doc.expiryDate!.year}',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

/// In-memory binding used by widget tests and PBTs. Captures every
/// successful `save` call into [savedDocuments] and supports a one-shot
/// [failNext] switch that throws on the next `save` to exercise the
/// persistence-failure branch (Requirement 10.7).
class InMemoryVaultDocumentStore implements VaultDocumentStore {
  /// Successfully-persisted documents in insertion order.
  final List<VaultDocument> savedDocuments = <VaultDocument>[];

  /// When `true`, the next `save` call throws and the flag flips back
  /// to `false`. Used by the persistence-failure widget test to drive
  /// the error banner without permanently breaking the store.
  bool failNext = false;

  @override
  Future<void> save(VaultDocument doc) async {
    if (failNext) {
      failNext = false;
      throw StateError('Forced failure for vault widget test.');
    }
    savedDocuments.add(doc);
  }
}

// ===========================================================================
// validateVaultDocumentInput
// ===========================================================================

/// Per-field error messages produced by [validateVaultDocumentInput].
///
/// Every field is `null` when valid and a non-empty error string when
/// invalid. The add form passes [title] through to
/// `AppTextField.errorText`; [category] is rendered as a banner above
/// the form because the category picker is not an `AppTextField`.
@immutable
class VaultValidationErrors {
  final String? title;
  final String? category;

  const VaultValidationErrors({this.title, this.category});

  /// Whether every field passed validation.
  bool get isValid => title == null && category == null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VaultValidationErrors &&
        other.title == title &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(title, category);
}

/// Pure validator used by the add form.
///
/// Returns a [VaultValidationErrors] whose every field is `null` when
/// the inputs satisfy Requirement 10.6 (title is non-empty after
/// trimming, category is one of [kVaultEditableCategories]). Otherwise
/// the matching field carries a short error message describing the
/// failure.
VaultValidationErrors validateVaultDocumentInput({
  required String titleText,
  required String? category,
}) {
  return VaultValidationErrors(
    title: titleText.trim().isEmpty ? 'Document title is required' : null,
    category: (category == null ||
            !kVaultEditableCategories.contains(category))
        ? 'Select a document category'
        : null,
  );
}

// ===========================================================================
// VaultDocumentCard
// ===========================================================================

/// Document card for the redesigned vault screen.
///
/// Renders [document] in an [AppCard] with:
///
///   * the [VaultDocument.title] truncated with an ellipsis when the
///     single-line width is exceeded (Requirement 10.3);
///   * an [AppBadge] showing the [VaultDocument.category];
///   * the expiry date formatted as `Expires DD/MM/YYYY` or the literal
///     `No expiry` when [VaultDocument.expiryDate] is `null`;
///   * the file size formatted via [formatBytes] when
///     [VaultDocument.fileSizeBytes] is non-null;
///   * an expiry-status indicator whose color is driven by
///     [expiryStatusOf] mapped through [_ExpiryIndicatorPalette]
///     (Requirements 10.4, 10.5).
///
/// Optional [onTap] / [onEdit] / [onDelete] callbacks expose the
/// edit / delete actions preserved from the legacy screen so existing
/// user-invocable actions remain reachable (Requirement 14.8).
class VaultDocumentCard extends StatelessWidget {
  final VaultDocument document;
  final DateTime now;
  final bool isGrid;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const VaultDocumentCard({
    super.key,
    required this.document,
    required this.now,
    this.isGrid = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final ExpiryStatus status = expiryStatusOf(document.expiryDate, now);
    final _ExpiryIndicatorPalette palette =
        _ExpiryIndicatorPalette.forStatus(status, colors);

    final String expiryText = document.expiryDate == null
        ? 'No expiry'
        : 'Expires ${document.expiryDate!.day.toString().padLeft(2, '0')}/'
            '${document.expiryDate!.month.toString().padLeft(2, '0')}/'
            '${document.expiryDate!.year}';

    final String? sizeText = document.fileSizeBytes == null
        ? null
        : formatBytes(document.fileSizeBytes!);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: title + category badge.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  document.title,
                  key: const ValueKey<String>('vault_document_card_title'),
                  style: typography.title.copyWith(color: colors.foreground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: spacing.sm),
              AppBadge(
                key: const ValueKey<String>('vault_document_card_category'),
                text: document.category,
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          // Expiry status row: colored dot + expiry copy.
          Row(
            children: <Widget>[
              Container(
                key: const ValueKey<String>('vault_document_card_status_dot'),
                width: typography.body.fontSize ?? 12,
                height: typography.body.fontSize ?? 12,
                decoration: BoxDecoration(
                  color: palette.color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  expiryText,
                  key: const ValueKey<String>('vault_document_card_expiry'),
                  style: typography.body.copyWith(color: palette.color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (sizeText != null) ...<Widget>[
            SizedBox(height: spacing.xs),
            Text(
              sizeText,
              key: const ValueKey<String>('vault_document_card_size'),
              style: typography.body.copyWith(
                color: colors.foreground
                    .withValues(alpha: colors.surfaceProminent),
              ),
            ),
          ],
          if (onEdit != null || onDelete != null) ...<Widget>[
            SizedBox(height: spacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (onEdit != null)
                  AppIconButton(
                    icon: Icons.edit_outlined,
                    onPressed: onEdit,
                    semanticsLabel: 'Edit document',
                  ),
                if (onDelete != null)
                  AppIconButton(
                    icon: Icons.delete_outline,
                    onPressed: onDelete,
                    semanticsLabel: 'Delete document',
                    color: colors.error,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Resolved color for the expiry indicator dot, mapped from the
/// pure [ExpiryStatus] classification onto the design tokens.
@immutable
class _ExpiryIndicatorPalette {
  final Color color;

  const _ExpiryIndicatorPalette({required this.color});

  factory _ExpiryIndicatorPalette.forStatus(
    ExpiryStatus status,
    AppColorsExt colors,
  ) {
    switch (status) {
      case ExpiryStatus.ok:
        return _ExpiryIndicatorPalette(color: colors.success);
      case ExpiryStatus.warning:
        return _ExpiryIndicatorPalette(color: colors.warning);
      case ExpiryStatus.error:
        return _ExpiryIndicatorPalette(color: colors.error);
      case ExpiryStatus.noExpiry:
        return _ExpiryIndicatorPalette(color: colors.info);
    }
  }
}

// ===========================================================================
// AddVaultDocumentSheet
// ===========================================================================

/// Bottom-sheet body for the add-document form (Tasks 12.5, 12.6).
///
/// Renders a form bound to [store]. On a valid submission the document
/// is persisted via `store.save` and the sheet pops with `true`. On a
/// validation failure or a `store.save` exception the sheet stays
/// open, the entered values are retained, and an `AppFeedbackBanner`
/// of kind `error` surfaces the cause (Requirement 10.7).
class AddVaultDocumentSheet extends StatefulWidget {
  final VaultDocumentStore store;

  /// Optional initial values used by the edit flow (preserved from the
  /// legacy screen). When `null`, the sheet starts empty.
  final VaultDocument? initial;

  const AddVaultDocumentSheet({
    super.key,
    required this.store,
    this.initial,
  });

  @override
  State<AddVaultDocumentSheet> createState() => _AddVaultDocumentSheetState();
}

class _AddVaultDocumentSheetState extends State<AddVaultDocumentSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  String? _category;
  DateTime? _expiryDate;
  VaultValidationErrors _errors = const VaultValidationErrors();
  bool _saving = false;
  String? _persistenceError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial?.title ?? '');
    _noteController = TextEditingController(text: widget.initial?.note ?? '');
    _category = widget.initial?.category ?? kVaultEditableCategories.first;
    _expiryDate = widget.initial?.expiryDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_saving) return;
    final VaultValidationErrors errors = validateVaultDocumentInput(
      titleText: _titleController.text,
      category: _category,
    );
    setState(() {
      _errors = errors;
    });
    if (!errors.isValid) {
      // Validation failure → keep sheet open, retain values, banner.
      setState(() {
        _persistenceError = errors.title ?? errors.category;
      });
      return;
    }

    final VaultDocument doc = VaultDocument(
      title: _titleController.text.trim(),
      category: _category!,
      note: _noteController.text.trim(),
      expiryDate: _expiryDate,
      fileSizeBytes: widget.initial?.fileSizeBytes,
    );

    setState(() {
      _saving = true;
      _persistenceError = null;
    });
    try {
      await widget.store.save(doc);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _persistenceError =
            'Could not save document. Please check your connection and try again.';
      });
    }
  }

  Future<void> _pickExpiryDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final String expiryLabel = _expiryDate == null
        ? 'Select expiry date (optional)'
        : 'Expires ${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.initial == null ? 'Add document' : 'Edit document',
            style: typography.headline.copyWith(color: colors.foreground),
          ),
          SizedBox(height: spacing.md),
          if (_persistenceError != null) ...<Widget>[
            AppFeedbackBanner(
              key: const ValueKey<String>('vault_add_error_banner'),
              kind: FeedbackKind.error,
              message: _persistenceError!,
              onDismiss: () => setState(() => _persistenceError = null),
            ),
            SizedBox(height: spacing.md),
          ],
          AppTextField(
            key: const ValueKey<String>('vault_add_title_field'),
            controller: _titleController,
            label: 'Document title',
            prefixIcon: Icons.title,
            errorText: _errors.title,
          ),
          SizedBox(height: spacing.md),
          // Category picker rendered as a chip row so the sheet stays
          // styled with the same Component_Library used elsewhere.
          Text(
            'Category',
            style: typography.label.copyWith(
              color: colors.foreground
                  .withValues(alpha: colors.surfaceProminent),
            ),
          ),
          SizedBox(height: spacing.sm),
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: <Widget>[
              for (final String label in kVaultEditableCategories)
                AppCategoryChip(
                  key: ValueKey<String>('vault_add_category_chip_$label'),
                  label: label,
                  selected: _category == label,
                  onTap: () => setState(() => _category = label),
                ),
            ],
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            key: const ValueKey<String>('vault_add_note_field'),
            controller: _noteController,
            label: 'Note',
            prefixIcon: Icons.notes_outlined,
          ),
          SizedBox(height: spacing.md),
          AppSecondaryButton(
            key: const ValueKey<String>('vault_add_expiry_button'),
            label: expiryLabel,
            icon: Icons.calendar_today_outlined,
            onPressed: _pickExpiryDate,
          ),
          SizedBox(height: spacing.lg),
          AppGradientButton(
            key: const ValueKey<String>('vault_add_save_button'),
            label: widget.initial == null ? 'Add document' : 'Save changes',
            isLoading: _saving,
            onPressed: _saving ? null : _onSave,
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Vault list/grid view-mode toggle
// ===========================================================================

/// Visual mode for the document list area: a vertical [list] of cards
/// or a two-column [grid]. Default is [list] per Requirement 10.2.
enum VaultViewMode { list, grid }

/// list/grid toggle used at the top of the vault screen. Mirrors the
/// browse-tab toggle in `lib/screens/workshops/_browse_tab.dart` so
/// the two screens share their visual language.
class VaultViewModeToggle extends StatelessWidget {
  final VaultViewMode mode;
  final ValueChanged<VaultViewMode> onChanged;

  const VaultViewModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;
    final Color activeColor = colors.emerald500;
    final Color inactiveColor =
        colors.foreground.withValues(alpha: colors.surfaceProminent);

    return Container(
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(radii.medium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppIconButton(
            key: const ValueKey<String>('vault_view_mode_list_button'),
            icon: Icons.view_list,
            onPressed: () => onChanged(VaultViewMode.list),
            semanticsLabel: 'List view',
            color: mode == VaultViewMode.list ? activeColor : inactiveColor,
          ),
          AppIconButton(
            key: const ValueKey<String>('vault_view_mode_grid_button'),
            icon: Icons.grid_view,
            onPressed: () => onChanged(VaultViewMode.grid),
            semanticsLabel: 'Grid view',
            color: mode == VaultViewMode.grid ? activeColor : inactiveColor,
          ),
        ],
      ),
    );
  }
}
