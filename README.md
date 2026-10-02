# DriveCare+ 🚗

> An all-in-one vehicle care & workshop-booking companion app built with **Flutter** and **Firebase** — manage your garage, log refuels, track journeys, book workshops, top up a wallet, and secure your account with biometrics + 2FA.

A mobile application project demonstrating real-world integrations (Google Maps/Places, Firebase Auth & Firestore, ToyyibPay payments), a token-driven theming system, local-first caching with cloud sync, and a broad automated test suite.

---

## ✨ Highlights

- **🔐 Secure by design** — Android biometric login, Google Authenticator-compatible TOTP 2FA, and biometric authorization for wallet transactions.
- **🚙 Vehicle management** — register vehicles, view health gauges, browse a structured car-spec database, and customize a car avatar.
- **⛽ Refuel & journey logs** — record refuel entries, track journeys with background location, and see mileage impact analytics.
- **🗺️ Workshop marketplace** — discover nearby workshops on a map, browse services & pricing, and manage bookings.
- **📅 Smart reminders** — zoned local notifications fire 30 minutes before and at the exact start of a booking, plus daily trip reviews.
- **💳 Wallet & payments** — in-app wallet with top-ups and Pro subscriptions via the ToyyibPay payment gateway (sandbox).
- **🎨 Dynamic theming** — a design-token architecture that rebuilds the entire light/dark theme from a single seed color.
- **🗄️ Document vault** — store and view vehicle documents (registration, insurance, etc.).

---

## 🧱 Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter / Dart (SDK `^3.11.1`) |
| Auth & data | Firebase Auth, Cloud Firestore, Firebase Storage, Remote Config |
| Maps & location | Google Maps SDK, Places API (New), Routes API, Roads API, `geolocator`, `geocoding` |
| Payments | ToyyibPay (sandbox) via REST + a Firebase Cloud Function webhook |
| Security | `local_auth` (biometrics), `flutter_secure_storage`, `otp` + `qr_flutter` (TOTP 2FA) |
| Notifications | `flutter_local_notifications` + `timezone` (zoned scheduling) |
| Background tracking | `flutter_foreground_task`, `flutter_activity_recognition` |
| Local persistence | `sqflite`, `shared_preferences` |
| Animation & UI | `lottie`, `flutter_svg`, custom design-token theme system |

---

## 🏗️ Architecture

DriveCare+ follows a **local-first, cloud-sync** model:

- **Local cache** (`sqflite` / `SharedPreferences` / `VehicleInsights`) keeps the app usable offline and instant on open.
- **Firestore synchronization** restores vehicles, bookings, refuel logs, and vault documents on login and writes changes back to the cloud.
- **Service layer** (`lib/services/`) isolates every external dependency — Firebase, Google APIs, ToyyibPay, notifications, biometrics, TOTP — behind focused single-responsibility services.
- **Design-token theming** (`lib/core/theme/`) drives the whole UI from one seed color; the theme pair is rebuilt atomically so light/dark always move together.

### Project structure

```
lib/
├── main.dart                 # Startup: Firebase, services, notifications bootstrap
├── app.dart                  # Root MaterialApp + named-route table
├── firebase_options.dart     # Firebase project config
├── core/                     # Theme tokens & utilities
├── models/                   # Data models (Workshop, vehicles, etc.)
├── screens/                  # Feature screens (see list below)
├── services/                 # Firebase, Maps, ToyyibPay, biometric, TOTP, notifications…
└── widgets/                  # Reusable UI component library
functions/
└── index.js                  # ToyyibPay webhook (Firebase Cloud Function)
test/                         # Unit, widget & property-based test suites
```

### Feature screens
Splash · Login · Register · Home (Cockpit) · Vehicle / Garage · Vehicle Customizer · Maintenance · Trip Planner · Trip Tracking · Journey Log · Mileage Impact · Booking · Refuel Log · Workshop Map · Workshop Detail · Wallet History · Document Vault · Document Viewer · Notifications · Settings · TOTP Setup · TOTP Verification · ToyyibPay WebView · Cloud Sync & API Monitor.

---

## 🚀 Getting Started

### Prerequisites
- **Flutter** SDK with Dart `^3.11.1`
- **Android SDK** (minSdk 24) — Android is the primary platform
- A machine with Java compatible with Gradle 8.13 (Java 17–23; **not** Java 25/26)

### 1. Install dependencies
```bash
flutter pub get
```

### 2. Configure the Google Maps / Places API key
The API key is **not committed to source** — it is injected at build time and consumed by two independent readers (Dart and the native Android manifest). Set both in one run command:

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=<YOUR_KEY> -PGOOGLE_MAPS_API_KEY=<YOUR_KEY>
```

To avoid retyping, set a session/user environment variable called `GOOGLE_MAPS_API_KEY` (the Gradle layer reads it automatically), then pass `--dart-define` as above.

> Recommended: restrict the key in Google Cloud Console to your package name + signing SHA-1 and to only the Maps/Places/Routes/Roads APIs.

### 3. Firebase
The Android `google-services.json` and `lib/firebase_options.dart` are included and point to the project's Firebase app. To run against your **own** backend, replace them with your Firebase project's files (`flutterfire configure`).

### 4. ToyyibPay (wallet / payments)
Payment features run against the **ToyyibPay sandbox** (`dev.toyyibpay.com`) and are a demo integration. The secret key is read from **Firebase Remote Config** (`toyyibpay_secret_key`) — it is never hard-coded, so wallet top-ups stay inactive until you publish a value in Remote Config.

### Run the app
```bash
flutter run
```

---

## 🧪 Testing

The project ships a broad suite under `test/` (unit, widget, and property-based tests) plus custom lint guards under `tool/`.

```bash
flutter analyze          # static analysis
flutter test             # full test suite
```

A GitHub Actions workflow (`.github/workflows/ci.yml`) runs a **reference-source guard → analyze → test → debug APK build** on every push/PR.

---

## 🔒 Security Notes

- No API keys, secrets, or signing material are committed to source. The Maps key and ToyyibPay secret are supplied via build-time injection and Remote Config, respectively.
- `.gitignore` excludes keystores (`*.jks`, `*.keystore`), signing config (`key.properties`), and environment files (`.env`).
- The ToyyibPay webhook is received by a Cloud Function that performs atomic Firestore transactions for wallet ledger updates.

---

## 📸 Screenshots

> App screenshots are coming soon. They'll be captured from a running build and
> added here as a gallery of the Cockpit, Garage, Workshop Map, Wallet, and
> Settings screens.

<!-- To add a gallery later: place images in assets/images/screenshots/ then uncomment:

| Cockpit | Garage | Workshop Map | Wallet |
|:---:|:---:|:---:|:---:|
| ![](assets/images/screenshots/home.png) | ![](assets/images/screenshots/garage.png) | ![](assets/images/screenshots/workshop_map.png) | ![](assets/images/screenshots/wallet.png) |

-->

---

## 📄 License

This project is created as part of a Mobile App Development coursework/portfolio. If you plan to keep it public, consider adding an open-source license (e.g. MIT) to clarify reuse terms.

---

## 👤 Author

Built by **muhammadaizat0185** — a Flutter/Firebase vehicle-care showcase.

_If you found this useful, consider starring the repo. ⭐_
