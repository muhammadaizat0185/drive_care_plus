// Modular building blocks for the redesigned Refuel Log screen
// (`lib/screens/refuel_log_screen.dart`).
//
// This module hosts the typed value classes, store abstraction,
// validation helpers, formatters, and the three primary tab bodies of
// the redesigned screen (Tasks 11.1 – 11.14):
//
//   * [RefuelEntry]            — Value type for a single saved refuel
//                                row carrying date, distance, liters,
//                                price/L, fuel type, and optional
//                                station.
//   * [FuelTypePreset]         — Fuel-type chip configuration with
//                                preset price per liter (Task 11.4).
//   * [kFuelTypePresets]       — `Budi95 / RON95 / RON97 / Diesel`
//                                preset list rendered by the Log tab.
//   * [PositiveDecimalFormatter] — Input formatter accepting only
//                                strings matching `^[0-9]*\.?[0-9]*$`
//                                (Task 11.2 / Property 17).
//   * [RefuelLogStore]         — Persistence interface; the
//                                production binding writes to
//                                Firestore, the test binding stays
//                                in-memory.
//   * [FirestoreRefuelLogStore]— Default Firestore-backed store used
//                                by the screen in production.
//   * [InMemoryRefuelLogStore] — Test store exposing `savedEntries`
//                                and a `failNext` switch for
//                                exercising the DB-failure branch.
//   * [validateRefuelInput]    — Pure input validator returning
//                                per-field error messages used by the
//                                Log tab and Property 19.
//   * [sortRefuelEntriesDescending] — Pure sort helper used by the
//                                History tab and Property 20.
//   * [formatEfficiency]       — Pure efficiency formatter rendering
//                                two-decimal `km/L` strings or a
//                                `–` placeholder when liters ≤ 0.
//   * [LogTab]                 — Log-tab body wiring fields, chips,
//                                save flow, validation banners, and
//                                DB-failure handling (Tasks 11.2,
//                                11.4, 11.5, 11.6, 11.9).
//   * [HistoryTab]             — History-tab body rendering one
//                                `AppCard` per saved entry in
//                                descending date order, with the
//                                empty state placeholder
//                                (Tasks 11.10, 11.12).
//   * [InsightsTab]            — Insights-tab body wrapping the
//                                existing `FuelChart` in an `AppCard`
//                                with the empty state placeholder
//                                (Tasks 11.13, 11.14).
//
// Visual constants flow from the design-token extensions on
// `Theme.of(context)`; no hex colors, spacing, radii, or typography
// literals from the Token_Sets are inlined (Requirement 3.11).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens/tokens.dart';
import '../../core/util/refuel_math.dart';
import '../../widgets/fuel_chart.dart';
import '../../widgets/ui/ui.dart';

// ===========================================================================
// RefuelEntry
// ===========================================================================

/// Single saved refuel entry. Two entries are equal iff every field
/// matches, which makes lists comparable in tests without identity
/// tracking.
@immutable
class RefuelEntry {
  /// Date the refuel was logged.
  final DateTime date;

  /// Kilometers travelled since the previous fill-up.
  final double distanceKm;

  /// Volume of fuel added at this fill-up.
  final double liters;

  /// Price per liter charged at the pump (in ringgit).
  final double pricePerLiter;

  /// Selected fuel type. One of [kFuelTypePresets]'s `label` values
  /// (the production presets are `Budi95`, `RON95`, `RON97`, `Diesel`).
  final String fuelType;

  /// Optional station name, surfaced on the History card when present.
  final String? station;

  const RefuelEntry({
    required this.date,
    required this.distanceKm,
    required this.liters,
    required this.pricePerLiter,
    required this.fuelType,
    this.station,
  });

  /// Convenience accessor for the displayed total cost on the
  /// History card. Computed from the persisted `liters` and
  /// `pricePerLiter` so the card never desyncs with the inputs that
  /// produced it.
  double get totalCost => liters * pricePerLiter;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RefuelEntry &&
        other.date == date &&
        other.distanceKm == distanceKm &&
        other.liters == liters &&
        other.pricePerLiter == pricePerLiter &&
        other.fuelType == fuelType &&
        other.station == station;
  }

  @override
  int get hashCode => Object.hash(
        date,
        distanceKm,
        liters,
        pricePerLiter,
        fuelType,
        station,
      );

  @override
  String toString() => 'RefuelEntry('
      'date: $date, '
      'distanceKm: $distanceKm, '
      'liters: $liters, '
      'pricePerLiter: $pricePerLiter, '
      'fuelType: $fuelType, '
      'station: $station)';
}

// ===========================================================================
// FuelTypePreset
// ===========================================================================

/// Fuel-type chip configuration. Each preset carries a label rendered
/// on the chip and a default price-per-liter pre-filled into the
/// price-per-liter input on selection (Tasks 11.4, 11.5).
@immutable
class FuelTypePreset {
  final String label;
  final double presetPricePerLiter;

  const FuelTypePreset({
    required this.label,
    required this.presetPricePerLiter,
  });
}

/// Fuel-type chip presets rendered by the Log tab in the order
/// `Budi95 / RON95 / RON97 / Diesel` per Requirement 9.2. Prices are
/// reasonable Malaysian retail snapshots; callers are expected to
/// override the price field after selection if pumps differ.
const List<FuelTypePreset> kFuelTypePresets = <FuelTypePreset>[
  FuelTypePreset(label: 'Budi95', presetPricePerLiter: 1.99),
  FuelTypePreset(label: 'RON95', presetPricePerLiter: 2.05),
  FuelTypePreset(label: 'RON97', presetPricePerLiter: 3.47),
  FuelTypePreset(label: 'Diesel', presetPricePerLiter: 2.15),
];

// ===========================================================================
// PositiveDecimalFormatter
// ===========================================================================

/// Text-input formatter that accepts only strings matching the
/// positive-decimal pattern `^[0-9]*\.?[0-9]*$` (Requirement 9.2,
/// Property 17). Empty strings, plain digits (`0`, `42`, `123`), a
/// trailing decimal point (`12.`), a leading decimal point (`.5`), and
/// a single decimal point with digits on both sides (`12.34`) are all
/// permitted; anything else (letters, signs, multiple dots,
/// whitespace) is rejected by reverting to the prior value.
///
/// The pattern intentionally allows the bare string `"."`. That is
/// not numerically valid on its own, but rejecting it during typing
/// would break a user typing `0.5` who briefly leaves the field at
/// `.` between keystrokes. Numeric validity is enforced separately by
/// [validateRefuelInput] when the user taps `Save Refuel`.
class PositiveDecimalFormatter extends TextInputFormatter {
  /// The exact regex from Requirement 9.2 / Property 17 that the
  /// final controller text must match after every keystroke.
  static final RegExp pattern = RegExp(r'^[0-9]*\.?[0-9]*$');

  const PositiveDecimalFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (pattern.hasMatch(newValue.text)) {
      return newValue;
    }
    // Reject the keystroke by reverting to the prior value. The
    // platform IME ignores the rejection and the controller stays
    // unchanged.
    return oldValue;
  }
}

// ===========================================================================
// RefuelLogStore
// ===========================================================================

/// Persistence boundary for refuel entries. The screen depends on this
/// abstraction (instead of Firestore directly) so widget tests can
/// inject an in-memory binding without dragging Firebase into the
/// flutter_test process.
abstract class RefuelLogStore {
  /// Persist [entry] to the underlying store.
  ///
  /// Throws when persistence fails so callers can branch into the
  /// error banner path required by Requirement 9.6.
  Future<void> save(RefuelEntry entry);
}

/// Default production binding writing each entry to the
/// `users/{uid}/refuel_logs` Firestore collection. Mirrors the
/// pre-redesign call shape so existing data is untouched
/// (Requirement 9.4).
class FirestoreRefuelLogStore implements RefuelLogStore {
  /// Optional explicit auth + firestore handles for tests; in
  /// production both default to the singleton instances.
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  FirestoreRefuelLogStore({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> save(RefuelEntry entry) async {
    final User? user = auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to save a refuel entry.');
    }
    await firestore
        .collection('users')
        .doc(user.uid)
        .collection('refuel_logs')
        .add(<String, Object?>{
      'distanceKm': entry.distanceKm,
      'liters': entry.liters,
      'pricePerLiter': entry.pricePerLiter,
      'fuelType': entry.fuelType,
      'station': entry.station,
      'date': Timestamp.fromDate(entry.date),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

/// In-memory binding used by the widget tests and PBTs. Captures
/// every successful `save` call into [savedEntries] and supports a
/// one-shot [failNext] switch that throws on the next `save` to
/// exercise the DB-failure branch (Requirement 9.6).
class InMemoryRefuelLogStore implements RefuelLogStore {
  /// Successfully-persisted entries in insertion order.
  final List<RefuelEntry> savedEntries = <RefuelEntry>[];

  /// When `true`, the next `save` call throws and the flag flips back
  /// to `false`. Used by the DB-failure widget test to drive the
  /// error banner without permanently breaking the store.
  bool failNext = false;

  @override
  Future<void> save(RefuelEntry entry) async {
    if (failNext) {
      failNext = false;
      throw StateError('Forced failure for DB-error widget test.');
    }
    savedEntries.add(entry);
  }
}

// ===========================================================================
// validateRefuelInput
// ===========================================================================

/// Per-field error messages produced by [validateRefuelInput].
///
/// Every field is `null` when valid and a non-empty error string when
/// invalid. The Log tab passes each error through to the matching
/// `AppTextField.errorText` so the user sees inline validation
/// indicators (Requirement 9.5).
@immutable
class RefuelValidationErrors {
  final String? distance;
  final String? liters;
  final String? price;
  final String? fuelType;

  const RefuelValidationErrors({
    this.distance,
    this.liters,
    this.price,
    this.fuelType,
  });

  /// Whether every field passed validation.
  bool get isValid =>
      distance == null &&
      liters == null &&
      price == null &&
      fuelType == null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RefuelValidationErrors &&
        other.distance == distance &&
        other.liters == liters &&
        other.price == price &&
        other.fuelType == fuelType;
  }

  @override
  int get hashCode => Object.hash(distance, liters, price, fuelType);
}

/// Pure validator used by the Log tab and Property 19.
///
/// Returns a [RefuelValidationErrors] whose every field is `null`
/// when the inputs satisfy Requirement 9.4 (distance, liters, price
/// all parse to a finite positive double, and a fuel-type chip is
/// selected). Otherwise the matching field carries a short error
/// message describing the failure and the others stay `null` /
/// carry their own messages (each field is checked independently).
RefuelValidationErrors validateRefuelInput({
  required String distanceText,
  required String litersText,
  required String priceText,
  required String? fuelType,
}) {
  return RefuelValidationErrors(
    distance: _validatePositive(distanceText, 'Distance'),
    liters: _validatePositive(litersText, 'Liters'),
    price: _validatePositive(priceText, 'Price'),
    fuelType: (fuelType == null || fuelType.trim().isEmpty)
        ? 'Select a fuel type'
        : null,
  );
}

String? _validatePositive(String text, String fieldLabel) {
  if (text.trim().isEmpty) return '$fieldLabel is required';
  final double? parsed = double.tryParse(text);
  if (parsed == null || !parsed.isFinite) return '$fieldLabel is invalid';
  if (parsed <= 0) return '$fieldLabel must be greater than zero';
  return null;
}

// ===========================================================================
// sortRefuelEntriesDescending
// ===========================================================================

/// Pure helper returning a new list containing the same entries as
/// [entries] sorted by `date` in descending order (most-recent-first).
///
/// The input list is not mutated. Two entries with the same `date`
/// keep their relative order (stable sort). The screen uses this
/// helper to satisfy Requirement 9.7 ("ordered from most recent to
/// oldest") and the PBT in
/// `test/screens/refuel_history_sort_pbt_test.dart` (Task 11.11)
/// drives the same helper to assert the property holds for any input
/// list.
List<RefuelEntry> sortRefuelEntriesDescending(List<RefuelEntry> entries) {
  final List<RefuelEntry> sorted = List<RefuelEntry>.of(entries);
  sorted.sort((RefuelEntry a, RefuelEntry b) => b.date.compareTo(a.date));
  return sorted;
}

// ===========================================================================
// formatEfficiency
// ===========================================================================

/// Pure efficiency formatter used by the History card. Returns
/// `<value> km/L` rounded to two decimals when the inputs produce a
/// finite positive value, or the `–` placeholder when the underlying
/// `kmPerLiter` falls back to `0.0` (liters ≤ 0) or yields a
/// non-finite result.
///
/// Guarantees the screen never renders a misleading `0.00 km/L` for a
/// degenerate input — the placeholder makes the absence explicit.
String formatEfficiency(double distanceKm, double liters) {
  final double kpl = kmPerLiter(distanceKm, liters);
  if (!kpl.isFinite || kpl <= 0) return '– km/L';
  return '${kpl.toStringAsFixed(2)} km/L';
}

// ===========================================================================
// LogTab
// ===========================================================================

/// Log-tab body for the redesigned Refuel screen.
///
/// Renders the three numeric `AppTextField`s (distance, liters,
/// price/L), the fuel-type chip row with preset prices, and the
/// `Save Refuel` `AppGradientButton`. Validation runs through
/// [validateRefuelInput]; on failure the matching `errorText` slot
/// surfaces the message and no DB call is issued (Requirement 9.5).
/// On success the entry is persisted via [store] and the form is
/// reset (Requirement 9.4). Persistence failures surface an
/// `AppFeedbackBanner` with the entered values retained so the user
/// can retry (Requirement 9.6).
class LogTab extends StatefulWidget {
  /// Persistence binding. Production callers pass a
  /// [FirestoreRefuelLogStore]; the widget tests inject an
  /// [InMemoryRefuelLogStore] so Firebase isn't required.
  final RefuelLogStore store;

  /// Optional callback invoked after a successful save with the
  /// persisted entry. The screen uses this to refresh the History
  /// tab; the widget tests inspect the captured entry directly via
  /// the in-memory store.
  final ValueChanged<RefuelEntry>? onSaved;

  /// Optional clock injection for deterministic widget tests.
  /// Defaults to `DateTime.now`.
  final DateTime Function()? now;

  const LogTab({
    super.key,
    required this.store,
    this.onSaved,
    this.now,
  });

  @override
  State<LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<LogTab> {
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _litersController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  /// Currently-selected fuel-type chip label, or `null` when none is
  /// selected. Tracked directly in state (rather than through
  /// `SingleSelectController`) because the Save flow needs to clear
  /// the selection on success — a capability outside the
  /// `SingleSelectController` contract.
  String? _selectedFuelType;

  RefuelValidationErrors _errors = const RefuelValidationErrors();

  /// `true` while a `save` future is in flight so the
  /// `AppGradientButton` shows its loading state and rejects extra
  /// taps (Requirement 5.7-style in-flight gate, applied to refuel
  /// per the spec's "no double-save" guard).
  bool _saving = false;

  /// Last persistence error. When non-null, the inline
  /// `AppFeedbackBanner` of kind `error` is rendered above the form
  /// (Requirement 9.6).
  String? _persistenceError;

  @override
  void dispose() {
    _distanceController.dispose();
    _litersController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onChipSelected(String label) {
    final FuelTypePreset preset =
        kFuelTypePresets.firstWhere((FuelTypePreset p) => p.label == label);
    setState(() {
      _selectedFuelType = label;
      // Per Requirement 9.3 the chip pre-fills the price field with
      // the preset value, overwriting any prior value (the field
      // remains editable; the user can override after selection).
      _priceController.text = preset.presetPricePerLiter.toStringAsFixed(2);
    });
  }

  Future<void> _onSave() async {
    if (_saving) return; // In-flight gate.
    final RefuelValidationErrors errors = validateRefuelInput(
      distanceText: _distanceController.text,
      litersText: _litersController.text,
      priceText: _priceController.text,
      fuelType: _selectedFuelType,
    );
    setState(() {
      _errors = errors;
    });
    if (!errors.isValid) {
      // Validation failed → no DB call (Requirement 9.5).
      return;
    }

    final RefuelEntry entry = RefuelEntry(
      date: (widget.now ?? DateTime.now)(),
      distanceKm: double.parse(_distanceController.text),
      liters: double.parse(_litersController.text),
      pricePerLiter: double.parse(_priceController.text),
      fuelType: _selectedFuelType!,
    );

    setState(() {
      _saving = true;
      _persistenceError = null;
    });
    try {
      await widget.store.save(entry);
      if (!mounted) return;
      // Reset the form to its initial empty state on success
      // (Requirement 9.4).
      setState(() {
        _distanceController.clear();
        _litersController.clear();
        _priceController.clear();
        _selectedFuelType = null;
        _errors = const RefuelValidationErrors();
        _saving = false;
      });
      widget.onSaved?.call(entry);
    } catch (e) {
      if (!mounted) return;
      // DB failure → error banner, retain field values (Requirement
      // 9.6).
      setState(() {
        _saving = false;
        _persistenceError = 'Could not save refuel entry. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    return ListView(
      padding: EdgeInsets.all(spacing.lg),
      children: <Widget>[
        if (_persistenceError != null) ...<Widget>[
          AppFeedbackBanner(
            key: const ValueKey<String>('refuel_log_error_banner'),
            kind: FeedbackKind.error,
            message: _persistenceError!,
            onDismiss: () => setState(() => _persistenceError = null),
          ),
          SizedBox(height: spacing.md),
        ],
        AppTextField(
          key: const ValueKey<String>('refuel_log_distance_field'),
          controller: _distanceController,
          label: 'Distance (km)',
          prefixIcon: Icons.route_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const <TextInputFormatter>[
            PositiveDecimalFormatter(),
          ],
          errorText: _errors.distance,
        ),
        SizedBox(height: spacing.md),
        AppTextField(
          key: const ValueKey<String>('refuel_log_liters_field'),
          controller: _litersController,
          label: 'Liters',
          prefixIcon: Icons.local_gas_station_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const <TextInputFormatter>[
            PositiveDecimalFormatter(),
          ],
          errorText: _errors.liters,
        ),
        SizedBox(height: spacing.md),
        AppTextField(
          key: const ValueKey<String>('refuel_log_price_field'),
          controller: _priceController,
          label: 'Price per liter (RM)',
          prefixIcon: Icons.payments_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const <TextInputFormatter>[
            PositiveDecimalFormatter(),
          ],
          errorText: _errors.price,
        ),
        SizedBox(height: spacing.lg),
        const AppSectionHeader(label: 'Fuel type'),
        SizedBox(height: spacing.sm),
        _FuelTypeChipRow(
          presets: kFuelTypePresets,
          selectedLabel: _selectedFuelType,
          onSelected: _onChipSelected,
        ),
        if (_errors.fuelType != null) ...<Widget>[
          SizedBox(height: spacing.sm),
          AppFeedbackBanner(
            key: const ValueKey<String>('refuel_log_fuel_type_error'),
            kind: FeedbackKind.error,
            message: _errors.fuelType!,
          ),
        ],
        SizedBox(height: spacing.xl),
        AppGradientButton(
          key: const ValueKey<String>('refuel_log_save_button'),
          label: 'Save Refuel',
          isLoading: _saving,
          onPressed: _saving ? null : _onSave,
        ),
      ],
    );
  }
}

/// Horizontal row of fuel-type `AppCategoryChip`s with preset prices.
class _FuelTypeChipRow extends StatelessWidget {
  final List<FuelTypePreset> presets;
  final String? selectedLabel;
  final ValueChanged<String> onSelected;

  const _FuelTypeChipRow({
    required this.presets,
    required this.selectedLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: spacing.lg),
        itemCount: presets.length,
        separatorBuilder: (BuildContext _, int _) =>
            SizedBox(width: spacing.sm),
        itemBuilder: (BuildContext context, int index) {
          final FuelTypePreset preset = presets[index];
          return AppCategoryChip(
            key: ValueKey<String>('refuel_fuel_chip_${preset.label}'),
            label: preset.label,
            selected: selectedLabel == preset.label,
            trailingPriceText:
                'RM ${preset.presetPricePerLiter.toStringAsFixed(2)}/L',
            onTap: () => onSelected(preset.label),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// HistoryTab
// ===========================================================================

/// History-tab body for the redesigned Refuel screen.
///
/// Renders [entries] as a column of `AppCard`s ordered most-recent-first
/// (Requirement 9.7). Each card surfaces date, distance, liters,
/// fuel-type chip, efficiency km/L (via [formatEfficiency]), total cost,
/// and station when available. Empty input renders an `AppEmptyState`
/// placeholder (Requirement 9.8).
class HistoryTab extends StatelessWidget {
  final List<RefuelEntry> entries;

  const HistoryTab({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    if (entries.isEmpty) {
      return const AppEmptyState(
        icon: Icons.local_gas_station_outlined,
        title: 'No refuel entries yet',
        message: 'Logged refuels will appear here once saved.',
      );
    }

    final List<RefuelEntry> sorted = sortRefuelEntriesDescending(entries);

    return ListView.separated(
      padding: EdgeInsets.all(spacing.lg),
      itemCount: sorted.length,
      separatorBuilder: (BuildContext _, int _) =>
          SizedBox(height: spacing.md),
      itemBuilder: (BuildContext context, int index) {
        return RefuelHistoryCard(entry: sorted[index]);
      },
    );
  }
}

/// Single History-tab card. Extracted as a top-level widget so the
/// efficiency-rendering predicate behind Property 20 can be exercised
/// in isolation by the property test in Task 11.11 without mounting
/// the full tab.
class RefuelHistoryCard extends StatelessWidget {
  final RefuelEntry entry;

  const RefuelHistoryCard({super.key, required this.entry});

  /// Format a date as `DD/MM/YYYY`. Mirrors the formatter on the
  /// vehicle-screen maintenance list so the two screens read the
  /// same way.
  static String _formatDate(DateTime date) {
    final String d = date.day.toString().padLeft(2, '0');
    final String m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    final String efficiencyText =
        formatEfficiency(entry.distanceKm, entry.liters);

    return AppCard(
      key: ValueKey<String>(
          'refuel_history_card_${entry.date.toIso8601String()}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header row: date + fuel type chip.
          Row(
            children: <Widget>[
              Icon(
                Icons.calendar_today,
                size: typography.body.fontSize,
                color: colors.foreground
                    .withValues(alpha: colors.surfaceProminent),
              ),
              SizedBox(width: spacing.xs),
              Text(
                _formatDate(entry.date),
                style: typography.body.copyWith(color: colors.foreground),
              ),
              SizedBox(width: spacing.sm),
              AppBadge(text: entry.fuelType, kind: BadgeKind.brand),
              const Spacer(),
              Text(
                'RM ${entry.totalCost.toStringAsFixed(2)}',
                style: typography.title.copyWith(
                  color: colors.foreground,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          // Stats row: distance / liters / efficiency.
          Row(
            children: <Widget>[
              Expanded(
                child: _Stat(
                  label: 'Distance',
                  value: '${entry.distanceKm.toStringAsFixed(0)} km',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Liters',
                  value: '${entry.liters.toStringAsFixed(1)} L',
                ),
              ),
              Expanded(
                child: _Stat(
                  key: const ValueKey<String>('refuel_history_efficiency'),
                  label: 'Efficiency',
                  value: efficiencyText,
                ),
              ),
            ],
          ),
          if (entry.station != null && entry.station!.trim().isNotEmpty) ...<Widget>[
            SizedBox(height: spacing.sm),
            Row(
              children: <Widget>[
                Icon(
                  Icons.location_on_outlined,
                  size: typography.body.fontSize,
                  color: colors.foreground
                      .withValues(alpha: colors.surfaceProminent),
                ),
                SizedBox(width: spacing.xs),
                Expanded(
                  child: Text(
                    entry.station!,
                    style: typography.body.copyWith(color: colors.foreground),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Small statistic block used inside [RefuelHistoryCard] for the
/// distance / liters / efficiency triplet.
class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: typography.label.copyWith(
            color: colors.foreground
                .withValues(alpha: colors.surfaceProminent),
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          value,
          style: typography.title.copyWith(color: colors.foreground),
        ),
      ],
    );
  }
}

// ===========================================================================
// InsightsTab
// ===========================================================================

/// Insights-tab body for the redesigned Refuel screen.
///
/// Wraps the existing [FuelChart] in an `AppCard` with the redesigned
/// typography and spacing, preserving the chart's data source and
/// computations (Requirement 9.9). When [entries] is empty, an
/// `AppEmptyState` is rendered in place of the chart (Requirement
/// 9.10).
class InsightsTab extends StatelessWidget {
  final List<RefuelEntry> entries;

  const InsightsTab({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;

    if (entries.isEmpty) {
      return const AppEmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'No insights yet',
        message: 'Insights will appear here once you log refuels.',
      );
    }

    // Compute km/L per entry and feed the existing FuelChart. The
    // chart expects the most-recent point last, so we sort ascending
    // here (the History tab sorts descending elsewhere).
    final List<RefuelEntry> sorted = List<RefuelEntry>.of(entries)
      ..sort((RefuelEntry a, RefuelEntry b) => a.date.compareTo(b.date));
    final List<double> series = sorted
        .map((RefuelEntry e) => kmPerLiter(e.distanceKm, e.liters))
        .toList(growable: false);

    return ListView(
      padding: EdgeInsets.all(spacing.lg),
      children: <Widget>[
        AppCard(
          child: FuelChart(dataPoints: series),
        ),
      ],
    );
  }
}
