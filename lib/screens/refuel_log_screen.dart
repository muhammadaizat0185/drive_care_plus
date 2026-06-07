// Redesigned Refuel Log screen for the figma-ui-redesign
// (Tasks 11.1 – 11.14 — Requirements 9.1 – 9.10).
//
// The body is composed from the modular widgets in
// `lib/screens/refuel/_widgets.dart`:
//
//   * LogTab       — Distance / liters / price-per-liter fields with
//                    positive-decimal filter, fuel-type chip row,
//                    Save Refuel CTA, validation, and DB-failure
//                    handling (Tasks 11.2 – 11.6, 11.9).
//   * HistoryTab   — `AppCard` per saved entry, descending date order,
//                    efficiency km/L (Tasks 11.10, 11.12).
//   * InsightsTab  — Existing FuelChart wrapped in `AppCard`
//                    (Tasks 11.13, 11.14).
//
// The screen owns the live list of entries fetched from the existing
// `users/{uid}/refuel_logs` Firestore collection and pipes them into
// the History and Insights tabs. The Log tab persists through a
// [RefuelLogStore] (production: [FirestoreRefuelLogStore]) so widget
// tests can inject an [InMemoryRefuelLogStore] without dragging
// Firebase into the flutter_test process.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/tokens/tokens.dart';
import 'refuel/_widgets.dart';

class RefuelLogScreen extends StatefulWidget {
  const RefuelLogScreen({
    super.key,
    this.store,
    this.entriesOverride,
  });

  static const String routeName = '/refuel-log';

  /// Optional persistence binding for tests. In production the screen
  /// constructs a [FirestoreRefuelLogStore] internally; widget tests
  /// inject an [InMemoryRefuelLogStore] so Firebase isn't required.
  final RefuelLogStore? store;

  /// Optional immediate entry list for tests / previews. When
  /// non-null the screen skips its Firestore stream and renders the
  /// supplied list verbatim. Production callers leave this null.
  final List<RefuelEntry>? entriesOverride;

  @override
  State<RefuelLogScreen> createState() => _RefuelLogScreenState();
}

class _RefuelLogScreenState extends State<RefuelLogScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final RefuelLogStore _store;

  /// Locally-tracked entries used by the History and Insights tabs.
  /// When [RefuelLogScreen.entriesOverride] is non-null this list is
  /// initialised from the override; otherwise it is populated from the
  /// Firestore stream and grown by [_onSaved] callbacks from the Log
  /// tab.
  late List<RefuelEntry> _entries;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _store = widget.store ?? FirestoreRefuelLogStore();
    _entries = widget.entriesOverride == null
        ? <RefuelEntry>[]
        : List<RefuelEntry>.of(widget.entriesOverride!);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSaved(RefuelEntry entry) {
    setState(() {
      _entries = <RefuelEntry>[entry, ..._entries];
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Refuel',
          style: typography.headline.copyWith(color: colors.foreground),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48 + spacing.sm),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.sm,
            ),
            child: TabBar(
              controller: _tabController,
              labelStyle: typography.title,
              labelColor: colors.emerald500,
              unselectedLabelColor: colors.foreground
                  .withValues(alpha: colors.surfaceProminent),
              indicatorColor: colors.emerald500,
              tabs: const <Widget>[
                Tab(text: 'Log'),
                Tab(text: 'History'),
                Tab(text: 'Insights'),
              ],
            ),
          ),
        ),
      ),
      body: widget.entriesOverride != null
          ? _buildTabs(_entries)
          : _buildStreamingTabs(),
    );
  }

  /// Stream-driven body used in production. Subscribes to the user's
  /// `refuel_logs` collection ordered by `date` descending and pipes
  /// the result into the History and Insights tabs. The Log tab
  /// always renders regardless of stream state because saving does
  /// not require the stream snapshot.
  Widget _buildStreamingTabs() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // No signed-in user → render with an empty list so the empty
      // state surfaces and the Log tab still allows saving.
      return _buildTabs(_entries);
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('refuel_logs')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        final List<RefuelEntry> remoteEntries = snapshot.hasData
            ? snapshot.data!.docs
                .map(_entryFromDoc)
                .whereType<RefuelEntry>()
                .toList(growable: false)
            : const <RefuelEntry>[];
        // Merge in-memory optimistic entries with remote ones — the
        // optimistic entry will be replaced by the remote copy on
        // the next stream tick.
        final List<RefuelEntry> all = <RefuelEntry>[
          ..._entries,
          ...remoteEntries,
        ];
        return _buildTabs(all);
      },
    );
  }

  Widget _buildTabs(List<RefuelEntry> entries) {
    return TabBarView(
      controller: _tabController,
      children: <Widget>[
        LogTab(store: _store, onSaved: _onSaved),
        HistoryTab(entries: entries),
        InsightsTab(entries: entries),
      ],
    );
  }

  /// Map a Firestore doc into a typed [RefuelEntry]. Returns `null`
  /// when the doc is malformed so the streaming branch silently
  /// drops bad rows rather than crashing the screen.
  static RefuelEntry? _entryFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();
    final num? distance = data['distanceKm'] as num?;
    final num? liters = data['liters'] as num?;
    final num? price = data['pricePerLiter'] as num?;
    final String? fuelType = data['fuelType'] as String?;
    if (distance == null ||
        liters == null ||
        price == null ||
        fuelType == null) {
      return null;
    }
    DateTime date;
    final Timestamp? ts = data['date'] as Timestamp?;
    if (ts != null) {
      date = ts.toDate();
    } else {
      final Timestamp? legacyTs = data['timestamp'] as Timestamp?;
      if (legacyTs != null) {
        date = legacyTs.toDate();
      } else {
        return null;
      }
    }
    return RefuelEntry(
      date: date,
      distanceKm: distance.toDouble(),
      liters: liters.toDouble(),
      pricePerLiter: price.toDouble(),
      fuelType: fuelType,
      station: data['station'] as String?,
    );
  }
}
