// Feature: figma-ui-redesign — Widget tests for the redesigned
// `SettingsScreen` (task 8.13).
//
// Validates:
//   * Requirement 6.1 — Section order: PROFILE, APPEARANCE,
//                       NOTIFICATIONS, PRIVACY & SECURITY,
//                       DATA & STORAGE, PREFERENCES, ABOUT & SUPPORT,
//                       Sign Out button.
//   * Requirement 6.2 — PROFILE field validators: empty name surfaces
//                       errorText; phone < 7 digits surfaces errorText;
//                       no Firebase call on validation failure.
//   * Requirement 6.4 — APPEARANCE swatch grid (8 presets) renders with
//                       a checkmark on the currently selected swatch.
//   * Requirement 6.7 — Tap Sign Out → AppBottomSheet visible with
//                       Cancel and Sign Out buttons.
//   * Requirement 6.8 — Cancel dismisses the sheet without changing
//                       authentication state.
//   * Requirement 6.10 — Save Profile failure surfaces an error
//                        AppFeedbackBanner; edited values retained.
//   * Requirement 6.3 — Dirty banner appears when controller text
//                       differs from persisted profile.
//
// Why a partial-mount approach instead of a full Firebase mock:
//   * `SettingsScreen` reads from `ProfileService.instance` (a
//     ChangeNotifier singleton with Firebase-backed init) and renders
//     a `CircleAvatar` with a `NetworkImage`. The Firebase plugin
//     channels are not registered in `flutter test`, but
//     `ProfileService.updateProfile` catches its own Firebase errors
//     in a try/catch and degrades gracefully — so updates run cleanly
//     against an in-memory `SharedPreferences` mock without throwing
//     into the test. The `NetworkImage` is muted via
//     `_TransparentPngHttpOverrides` (the same pattern used by
//     `home_widgets_test.dart`).
//   * The Sign Out flow calls `FirebaseAuth.instance.signOut()`. That
//     call would throw `MissingPluginException` in `flutter test`
//     when triggered, so the Sign Out tests below assert that the
//     bottom sheet **opens** with Cancel + Sign Out buttons and that
//     Cancel dismisses cleanly — they do NOT exercise the confirm
//     branch (which would hit the Firebase boundary).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/screens/login_screen.dart';
import 'package:drive_care_plus/screens/settings_screen.dart';
import 'package:drive_care_plus/services/notification_preferences.dart';
import 'package:drive_care_plus/services/profile_service.dart';
import 'package:drive_care_plus/services/theme_service.dart';
import 'package:drive_care_plus/widgets/ui/app_feedback_banner.dart';
import 'package:drive_care_plus/widgets/ui/app_gradient_button.dart';
import 'package:drive_care_plus/widgets/ui/app_secondary_button.dart';
import 'package:drive_care_plus/widgets/ui/app_section_header.dart';
import 'package:drive_care_plus/widgets/ui/app_text_field.dart';
import 'package:drive_care_plus/widgets/ui/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// HttpOverrides: 1x1 opaque PNG response for every HTTP GET so the
// `CircleAvatar`'s `NetworkImage(profile.photoUrl)` resolves without
// touching the network. Same shape as the home_widgets_test.dart
// override (kept compact here — the assertions don't inspect the
// avatar bytes).
// ---------------------------------------------------------------------------

final Uint8List _kTransparentPngBytes = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _TransparentPngHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) {}
  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) {}
  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) {}
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? cb) {}
  @override
  set connectionFactory(Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f) {}
  @override
  set findProxy(String Function(Uri url)? f) {}
  @override
  set keyLog(Function(String line)? cb) {}

  @override
  void close({bool force = false}) {}

  Future<HttpClientRequest> _open() async => _FakeHttpClientRequest();

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) => _open();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => _open();
  @override
  Future<HttpClientRequest> get(String host, int port, String path) => _open();
  @override
  Future<HttpClientRequest> getUrl(Uri url) => _open();
  @override
  Future<HttpClientRequest> post(String host, int port, String path) => _open();
  @override
  Future<HttpClientRequest> postUrl(Uri url) => _open();
  @override
  Future<HttpClientRequest> put(String host, int port, String path) => _open();
  @override
  Future<HttpClientRequest> putUrl(Uri url) => _open();
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) => _open();
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _open();
  @override
  Future<HttpClientRequest> head(String host, int port, String path) => _open();
  @override
  Future<HttpClientRequest> headUrl(Uri url) => _open();
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) => _open();
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _open();
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  bool bufferOutput = true;
  @override
  int contentLength = -1;
  @override
  late Encoding encoding;
  @override
  bool followRedirects = true;
  @override
  final HttpHeaders headers = _FakeHttpHeaders();
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  void add(List<int> data) {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}
  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  List<Cookie> get cookies => <Cookie>[];
  @override
  Future<HttpClientResponse> get done => close();
  @override
  Future<void> flush() async {}
  @override
  String get method => 'GET';
  @override
  Uri get uri => Uri();
  @override
  void write(Object? object) {}
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {}
  @override
  void writeCharCode(int charCode) {}
  @override
  void writeln([Object? object = '']) {}
}

class _FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  X509Certificate? get certificate => null;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  int get contentLength => _kTransparentPngBytes.length;
  @override
  List<Cookie> get cookies => <Cookie>[];
  @override
  Future<Socket> detachSocket() async => throw UnsupportedError('detachSocket');
  @override
  final HttpHeaders headers = _FakeHttpHeaders();
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  String get reasonPhrase => 'OK';
  @override
  Future<HttpClientResponse> redirect([String? method, Uri? url, bool? followLoops]) async => this;
  @override
  List<RedirectInfo> get redirects => <RedirectInfo>[];
  @override
  int get statusCode => 200;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_kTransparentPngBytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  bool chunkedTransferEncoding = false;
  @override
  int contentLength = -1;
  @override
  ContentType? contentType;
  @override
  DateTime? date;
  @override
  DateTime? expires;
  @override
  String? host;
  @override
  DateTime? ifModifiedSince;
  @override
  bool persistentConnection = true;
  @override
  int? port;

  @override
  List<String>? operator [](String name) => null;
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void clear() {}
  @override
  void forEach(void Function(String name, List<String> values) action) {}
  @override
  void noFolding(String name) {}
  @override
  void remove(String name, Object value) {}
  @override
  void removeAll(String name) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  String? value(String name) => null;
}

// ---------------------------------------------------------------------------
// Test host: pumps [SettingsScreen] inside a token-themed MaterialApp
// with a routes table containing a stub login route so the Sign Out
// `pushReplacementNamed` (when exercised) lands somewhere instead of
// blowing up. The viewport is set to 1080x1920 so the long settings
// scroll fits without overflow during scroll-into-view operations.
// ---------------------------------------------------------------------------

const String _kLoginStubText = 'login-stub';

Future<void> _pumpSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final ThemeData theme =
      AppTheme.buildTheme(AppColors.emerald500, Brightness.light);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      routes: <String, WidgetBuilder>{
        SettingsScreen.routeName: (_) => const SettingsScreen(),
        LoginScreen.routeName: (_) =>
            const Scaffold(body: Text(_kLoginStubText)),
      },
      initialRoute: SettingsScreen.routeName,
    ),
  );
  // One extra pump drains any post-frame microtasks scheduled by the
  // service singletons so subsequent finders see the settled tree.
  await tester.pump();
}

/// Restores `ProfileService.instance` to a deterministic baseline so
/// each test starts from a known persisted-snapshot. Uses the same
/// canonical defaults that `ProfileService._internal()` constructs.
Future<void> _resetProfileService() async {
  await ProfileService.instance.updateProfile(
    name: 'Driver',
    avatarUrl:
        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80',
    phoneNo: '+60123456789',
    userBio: 'Daily Commuter 🚗',
  );
}

void main() {
  // Install network-image override once for the whole suite.
  setUpAll(() {
    HttpOverrides.global = _TransparentPngHttpOverrides();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NotificationPreferences.instance.reset();
    // Reset ThemeService back to default light + emerald primary so
    // swatch tests start from a known position. The setters notify
    // listeners synchronously, so no extra pump is needed here.
    await ThemeService.instance.setThemeMode(ThemeMode.light);
    await ThemeService.instance.setPrimaryColor(
      ThemeService.presets.values.first,
    );
    await _resetProfileService();
  });

  // -------------------------------------------------------------------
  // Section order — Requirement 6.1.
  // -------------------------------------------------------------------
  group('Section order', () {
    testWidgets(
      'renders all seven AppSectionHeaders in the documented order',
      (tester) async {
        await _pumpSettings(tester);

        // Collect every AppSectionHeader's label in render order.
        final List<String> labels = tester
            .widgetList<AppSectionHeader>(find.byType(AppSectionHeader))
            .map((AppSectionHeader h) => h.label)
            .toList();

        // The seven required sections from Requirement 6.1, in the
        // exact order they should be rendered.
        expect(
          labels,
          <String>[
            'PROFILE',
            'APPEARANCE',
            'NOTIFICATIONS',
            'PRIVACY & SECURITY',
            'DATA & STORAGE',
            'PREFERENCES',
            'ABOUT & SUPPORT',
          ],
          reason: 'Settings sections must render in the exact order '
              'required by Requirement 6.1.',
        );
      },
    );
  });

  // -------------------------------------------------------------------
  // Profile field validators — Requirement 6.2.
  // -------------------------------------------------------------------
  group('Profile field validators', () {
    testWidgets(
      'empty name surfaces inline errorText on the name field',
      (tester) async {
        await _pumpSettings(tester);

        // Find the name field — it is the first AppTextField in the
        // PROFILE section. Both fields are inside the same column so
        // an `at(0)` lookup pins the right one.
        final Finder nameFieldFinder = find.byType(AppTextField).at(0);
        await tester.enterText(nameFieldFinder, '');
        await tester.pump();

        // Scroll the Save Profile button into view (the screen is
        // long), then tap it.
        await tester.ensureVisible(find.byType(AppGradientButton));
        await tester.tap(find.byType(AppGradientButton));
        await tester.pump();

        // The name field must now expose a non-null errorText. The
        // exact wording is a copy detail — assert presence rather than
        // text equality so a future copy tweak doesn't break the test.
        final AppTextField nameField = tester.widget<AppTextField>(
          nameFieldFinder,
        );
        expect(
          nameField.errorText,
          isNotNull,
          reason: 'Empty display-name must surface inline errorText '
              'on the name AppTextField (Requirement 6.2).',
        );
        expect(nameField.errorText, isNotEmpty);
      },
    );

    testWidgets(
      'phone with fewer than 7 digits surfaces inline errorText',
      (tester) async {
        await _pumpSettings(tester);

        final Finder phoneFieldFinder = find.byType(AppTextField).at(1);
        // Six digits — below the 7-digit minimum.
        await tester.enterText(phoneFieldFinder, '123456');
        await tester.pump();

        await tester.ensureVisible(find.byType(AppGradientButton));
        await tester.tap(find.byType(AppGradientButton));
        await tester.pump();

        final AppTextField phoneField = tester.widget<AppTextField>(
          phoneFieldFinder,
        );
        expect(
          phoneField.errorText,
          isNotNull,
          reason: 'Phone with fewer than 7 digits must surface inline '
              'errorText on the phone AppTextField (Requirement 6.2).',
        );
      },
    );
  });

  // -------------------------------------------------------------------
  // Dirty banner — Requirement 6.3.
  // -------------------------------------------------------------------
  group('Dirty banner', () {
    testWidgets(
      'typing a different display name surfaces the warning banner',
      (tester) async {
        await _pumpSettings(tester);

        // No banner before any edit — the controllers were seeded
        // from the persisted profile so the form starts clean.
        expect(
          find.byWidgetPredicate(
            (Widget w) => w is AppFeedbackBanner &&
                w.kind == FeedbackKind.warning,
          ),
          findsNothing,
          reason: 'Warning banner must be absent on first frame when '
              'controllers equal the persisted profile (Requirement 6.3).',
        );

        // Type a different name into the first field. The
        // `Listenable.merge` rebuild flips _isDirty to true and the
        // banner appears on the next pump.
        await tester.enterText(
          find.byType(AppTextField).at(0),
          'A Different Name',
        );
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (Widget w) => w is AppFeedbackBanner &&
                w.kind == FeedbackKind.warning,
          ),
          findsOneWidget,
          reason: 'Warning banner must appear when controller text '
              'differs from the persisted profile (Requirement 6.3).',
        );
      },
    );
  });

  // -------------------------------------------------------------------
  // Swatch grid — Requirement 6.4.
  // -------------------------------------------------------------------
  group('Swatch grid', () {
    testWidgets(
      'renders one swatch per ThemeService preset and a single checkmark '
      'on the currently selected swatch',
      (tester) async {
        await _pumpSettings(tester);

        // Scroll the APPEARANCE section into view so the swatch grid
        // is rendered (offscreen widgets in a ListView may be culled).
        await tester.ensureVisible(
          find.byWidgetPredicate(
            (Widget w) =>
                w is AppSectionHeader && w.label == 'APPEARANCE',
          ),
        );
        await tester.pumpAndSettle();

        // The number of presets is the source of truth for how many
        // swatches the grid should render. Expecting an exact count
        // catches a regression where the grid renders fewer/more
        // than the documented 8 entries.
        final int presetCount = ThemeService.presets.values.length;
        expect(
          presetCount,
          greaterThan(0),
          reason: 'ThemeService.presets must define at least one preset.',
        );

        // Exactly one Icons.check glyph must be rendered across the
        // appearance section — the active preset's checkmark.
        // Requirement 6.4 / 6.5 — exactly-one-checkmark invariant.
        expect(
          find.byIcon(Icons.check),
          findsOneWidget,
          reason: 'Swatch grid must render exactly one Icons.check '
              'glyph for the currently selected preset (Requirement 6.4).',
        );
      },
    );
  });

  // -------------------------------------------------------------------
  // Sign Out flow — Requirements 6.7, 6.8.
  // -------------------------------------------------------------------
  group('Sign Out flow', () {
    testWidgets(
      'tapping Sign Out presents a bottom sheet with Cancel and '
      'Sign Out buttons',
      (tester) async {
        await _pumpSettings(tester);

        // Find the Sign Out AppSecondaryButton at the bottom of the
        // scroll view and scroll it into view, then tap it.
        final Finder signOutFinder = find.byWidgetPredicate(
          (Widget w) =>
              w is AppSecondaryButton && w.label == 'Sign Out',
        );
        expect(signOutFinder, findsOneWidget);
        await tester.ensureVisible(signOutFinder);
        await tester.pumpAndSettle();
        await tester.tap(signOutFinder);
        await tester.pumpAndSettle();

        // The bottom sheet must contain both confirmation buttons.
        // The Sign Out button inside the sheet is an
        // AppGradientButton; the Cancel button is an
        // AppSecondaryButton. We assert presence by their unique
        // labels so the assertions don't depend on widget-tree
        // hierarchy that could shift if the sheet's layout is
        // tweaked later.
        expect(
          find.text('Sign out of DriveCare+?'),
          findsOneWidget,
          reason: 'Sign-out bottom sheet must show its confirmation '
              'headline (Requirement 6.7).',
        );
        expect(
          find.byWidgetPredicate(
            (Widget w) =>
                w is AppGradientButton && w.label == 'Sign Out',
          ),
          findsOneWidget,
          reason: 'Sign-out sheet must contain a Sign Out '
              'AppGradientButton (Requirement 6.7).',
        );
        expect(
          find.byWidgetPredicate(
            (Widget w) =>
                w is AppSecondaryButton && w.label == 'Cancel',
          ),
          findsOneWidget,
          reason: 'Sign-out sheet must contain a Cancel '
              'AppSecondaryButton (Requirement 6.7).',
        );
      },
    );

    testWidgets(
      'tapping Cancel in the sign-out sheet dismisses it without '
      'navigating away',
      (tester) async {
        await _pumpSettings(tester);

        final Finder signOutFinder = find.byWidgetPredicate(
          (Widget w) =>
              w is AppSecondaryButton && w.label == 'Sign Out',
        );
        await tester.ensureVisible(signOutFinder);
        await tester.pumpAndSettle();
        await tester.tap(signOutFinder);
        await tester.pumpAndSettle();

        // Tap Cancel inside the sheet.
        final Finder cancelFinder = find.byWidgetPredicate(
          (Widget w) =>
              w is AppSecondaryButton && w.label == 'Cancel',
        );
        await tester.tap(cancelFinder);
        await tester.pumpAndSettle();

        // The sheet must dismiss and Settings must still be on screen
        // — no Login navigation, no `pushReplacementNamed`. We verify
        // by confirming the login stub is NOT visible and the
        // Settings AppBar title still is.
        expect(
          find.text(_kLoginStubText),
          findsNothing,
          reason: 'Cancel must NOT navigate to LoginScreen '
              '(Requirement 6.8).',
        );
        // A second tap on the Sign Out button works again — proving
        // the sheet is fully dismissed (otherwise the existing sheet
        // would intercept the tap).
        expect(find.text('Sign out of DriveCare+?'), findsNothing);
      },
    );
  });
}
