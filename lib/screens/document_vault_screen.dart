// Redesigned Document Vault screen for the figma-ui-redesign
// (Tasks 12.1 – 12.7 — Requirements 10.1 – 10.7).
//
// The body is composed from the modular widgets in
// `lib/screens/document_vault/_widgets.dart`:
//
//   * VaultDocument            — typed value class around the legacy
//                                Map<String, dynamic> rows.
//   * VaultDocumentStore       — persistence boundary; production binds
//                                to VehicleInsights + Firestore, tests
//                                inject an in-memory store.
//   * VaultDocumentCard        — single-card surface with category
//                                badge, expiry indicator, and file size.
//   * AddVaultDocumentSheet    — bottom-sheet body for the add/edit
//                                form (Tasks 12.5, 12.6).
//   * VaultViewModeToggle      — list/grid mode toggle (Task 12.3).
//
// Live documents are pulled from `VehicleInsights.instance.documents`
// (the legacy Map-based API) and converted to `VaultDocument` via
// [VaultDocument.fromMap] so the filter helper, the card widget, and
// the tests can share a typed shape while persistence stays untouched.

import 'package:flutter/material.dart';

import '../core/theme/tokens/tokens.dart';
import '../core/util/search_filter.dart';
import '../core/util/single_select_controller.dart';
import '../services/vehicle_insights.dart';
import '../widgets/ui/ui.dart';
import 'document_vault/_widgets.dart';

class DocumentVaultScreen extends StatefulWidget {
  const DocumentVaultScreen({
    super.key,
    this.store,
    this.documentsOverride,
    this.now,
  });

  /// Stable route name. Preserved verbatim from the legacy
  /// implementation so existing navigation calls continue to resolve.
  static const String routeName = '/document-vault';

  /// Optional persistence binding for tests. In production the screen
  /// constructs a [VehicleInsightsVaultDocumentStore] internally; widget
  /// tests inject an [InMemoryVaultDocumentStore] so Firebase isn't
  /// required.
  final VaultDocumentStore? store;

  /// Optional immediate document list for tests / previews. When
  /// non-null the screen skips the [VehicleInsights] subscription and
  /// renders the supplied list verbatim. Production callers leave this
  /// `null`.
  final List<VaultDocument>? documentsOverride;

  /// Optional clock injection for deterministic widget tests. Defaults
  /// to `DateTime.now`.
  final DateTime Function()? now;

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final SingleSelectController<String> _categoryController;
  late final VaultDocumentStore _store;
  VaultViewMode _viewMode = VaultViewMode.list;

  @override
  void initState() {
    super.initState();
    _categoryController = SingleSelectController<String>(
      values: kVaultCategoryLabels,
      initial: kVaultCategoryLabels.first,
    );
    _categoryController.addListener(_onChange);
    _searchController.addListener(_onChange);
    _store = widget.store ?? VehicleInsightsVaultDocumentStore();
  }

  @override
  void dispose() {
    _categoryController.removeListener(_onChange);
    _searchController.removeListener(_onChange);
    _categoryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  DateTime _resolveNow() => (widget.now ?? DateTime.now)();

  Future<void> _showAddDocumentSheet() async {
    await AppBottomSheet.show<bool>(
      context,
      initialHeightFraction: 0.9,
      builder: (BuildContext sheetContext) =>
          AddVaultDocumentSheet(store: _store),
    );
    // The sheet closes itself on success; the screen rebuilds on the
    // next [VehicleInsights] notification.
  }

  List<VaultDocument> _resolveDocuments(List<VaultDocument>? overridden) {
    if (overridden != null) return overridden;
    return VehicleInsights.instance.documents
        .map<VaultDocument>(
          (Map<String, dynamic> raw) => VaultDocument.fromMap(raw),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final Widget body = ListenableBuilder(
      listenable: VehicleInsights.instance,
      builder: (BuildContext context, _) {
        final List<VaultDocument> all =
            _resolveDocuments(widget.documentsOverride);
        final List<VaultDocument> filtered = filterDocuments(
          all,
          _searchController.text,
          _categoryController.selected ?? kVaultCategoryLabels.first,
        );
        return _buildBody(filtered, spacing);
      },
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Document Vault',
          style: typography.headline.copyWith(color: colors.foreground),
        ),
      ),
      body: SafeArea(child: body),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey<String>('vault_add_button'),
        onPressed: _showAddDocumentSheet,
        backgroundColor: colors.emerald500,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody(List<VaultDocument> filtered, AppSpacingExt spacing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.md,
            spacing.lg,
            spacing.sm,
          ),
          child: AppTextField(
            key: const ValueKey<String>('vault_search_field'),
            controller: _searchController,
            hintText: 'Search documents',
            prefixIcon: Icons.search,
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: spacing.lg),
            itemCount: kVaultCategoryLabels.length,
            separatorBuilder: (BuildContext _, int _) =>
                SizedBox(width: spacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final String label = kVaultCategoryLabels[index];
              return AppCategoryChip(
                key: ValueKey<String>('vault_category_chip_$label'),
                label: label,
                selected: _categoryController.selected == label,
                onTap: () => _categoryController.select(label),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              VaultViewModeToggle(
                mode: _viewMode,
                onChanged: (VaultViewMode mode) {
                  setState(() => _viewMode = mode);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const AppEmptyState(
                  key: ValueKey<String>('vault_empty_state'),
                  icon: Icons.folder_open_outlined,
                  title: 'No documents found',
                  message:
                      'Try a different search term or category, or add a document.',
                )
              : _viewMode == VaultViewMode.list
                  ? _buildList(filtered, spacing)
                  : _buildGrid(filtered, spacing),
        ),
      ],
    );
  }

  Widget _buildList(List<VaultDocument> docs, AppSpacingExt spacing) {
    final DateTime now = _resolveNow();
    return ListView.separated(
      key: const ValueKey<String>('vault_list_view'),
      padding: EdgeInsets.all(spacing.lg),
      itemCount: docs.length,
      separatorBuilder: (BuildContext _, int _) =>
          SizedBox(height: spacing.md),
      itemBuilder: (BuildContext context, int index) {
        return VaultDocumentCard(
          key: ValueKey<String>('vault_card_${docs[index].title}_$index'),
          document: docs[index],
          now: now,
          isGrid: false,
        );
      },
    );
  }

  Widget _buildGrid(List<VaultDocument> docs, AppSpacingExt spacing) {
    final DateTime now = _resolveNow();
    return GridView.builder(
      key: const ValueKey<String>('vault_grid_view'),
      padding: EdgeInsets.all(spacing.lg),
      itemCount: docs.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: spacing.md,
        crossAxisSpacing: spacing.md,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (BuildContext context, int index) {
        return VaultDocumentCard(
          key: ValueKey<String>('vault_card_${docs[index].title}_$index'),
          document: docs[index],
          now: now,
          isGrid: true,
        );
      },
    );
  }
}
