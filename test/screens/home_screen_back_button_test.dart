import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drive_care_plus/core/theme/app_theme.dart';
import 'package:drive_care_plus/core/theme/tokens/tokens.dart';
import 'package:drive_care_plus/screens/home_screen.dart';
import 'package:drive_care_plus/services/profile_service.dart';
import 'package:drive_care_plus/services/theme_service.dart';
import 'package:drive_care_plus/services/vehicle_insights.dart';

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
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel activityRecognitionChannel = MethodChannel('flutter_activity_recognition/method');
  const MethodChannel platformChannel = SystemChannels.platform;

  bool isSystemPopCalled = false;

  setUpAll(() {
    HttpOverrides.global = _TransparentPngHttpOverrides();
  });

  setUp(() async {
    isSystemPopCalled = false;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'has_seen_onboarding_guide': true, // Prevent onboarding dialog popup during tests
    });

    // Mock flutter_activity_recognition permission check
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      activityRecognitionChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'checkPermission') {
          return 'DENIED';
        }
        if (methodCall.method == 'requestPermission') {
          return 'DENIED';
        }
        return null;
      },
    );

    // Mock platform navigator pop to monitor exit trigger
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      platformChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'SystemNavigator.pop') {
          isSystemPopCalled = true;
          return null;
        }
        return null;
      },
    );

    // Baseline configuration
    ProfileService.instance.isPro = false;
    await ThemeService.instance.setThemeMode(ThemeMode.light);
    await ThemeService.instance.setPrimaryColor(
      ThemeService.presets['Emerald Green']!,
    );
    await VehicleInsights.instance.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(activityRecognitionChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(platformChannel, null);
  });

  Widget hostApp({required Widget child}) {
    final ThemeData theme = AppTheme.buildTheme(AppColors.emerald500, Brightness.light);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: child,
    );
  }

  group('HomeScreen Back Button Interception Tests', () {
    testWidgets('Tapping back on non-zero tabs redirects to Cockpit (index 0)', (tester) async {
      await tester.pumpWidget(hostApp(child: const HomeScreen()));
      await tester.pumpAndSettle();

      // Verify initial tab is Cockpit (index 0)
      expect(HomeScreen.activeTabNotifier.value, equals(0));

      // Switch to a non-zero tab (e.g., Wallet, index 4)
      HomeScreen.activeTabNotifier.value = 4;
      await tester.pumpAndSettle();
      expect(HomeScreen.activeTabNotifier.value, equals(4));

      // Simulate a back press
      final dynamic popResult = await tester.binding.handlePopRoute();
      expect(popResult, isTrue); // Intercepted
      await tester.pumpAndSettle();

      // Should redirect to Cockpit (index 0)
      expect(HomeScreen.activeTabNotifier.value, equals(0));
    });

    testWidgets('Tapping back on Cockpit once shows snackbar and does not exit', (tester) async {
      await tester.pumpWidget(hostApp(child: const HomeScreen()));
      await tester.pumpAndSettle();

      // Ensure we are on index 0
      expect(HomeScreen.activeTabNotifier.value, equals(0));
      expect(isSystemPopCalled, isFalse);

      // Simulate first back press
      final dynamic popResult = await tester.binding.handlePopRoute();
      expect(popResult, isTrue); // Intercepted
      await tester.pump(); // Start snackbar animation

      // Should show 'Press back again to exit' snackbar
      expect(find.text('Press back again to exit'), findsOneWidget);
      expect(isSystemPopCalled, isFalse);
    });

    testWidgets('Tapping back twice within 2 seconds exits app via SystemNavigator.pop()', (tester) async {
      await tester.pumpWidget(hostApp(child: const HomeScreen()));
      await tester.pumpAndSettle();

      // Ensure we are on index 0
      expect(HomeScreen.activeTabNotifier.value, equals(0));

      // First back press
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Press back again to exit'), findsOneWidget);
      expect(isSystemPopCalled, isFalse);

      // Second back press immediately
      await tester.binding.handlePopRoute();
      await tester.pump();

      // Should trigger native app exit
      expect(isSystemPopCalled, isTrue);
    });

    testWidgets('Tapping back twice with more than 2 seconds interval does not exit', (tester) async {
      await tester.pumpWidget(hostApp(child: const HomeScreen()));
      await tester.pumpAndSettle();

      // Ensure we are on index 0
      expect(HomeScreen.activeTabNotifier.value, equals(0));

      // First back press
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Press back again to exit'), findsOneWidget);
      expect(isSystemPopCalled, isFalse);

      // Wait more than 2 seconds (e.g. 2.1 seconds physically to update wall-clock time)
      await Future.delayed(const Duration(milliseconds: 2100));
      await tester.pump();

      // Second back press after wait
      await tester.binding.handlePopRoute();
      await tester.pump();

      // Should show snackbar again, not exit
      expect(find.text('Press back again to exit'), findsOneWidget);
      expect(isSystemPopCalled, isFalse);
    });
  });
}
