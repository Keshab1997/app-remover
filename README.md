# Goodbye Apps – Uninstaller (Flutter)

একটা Flutter + Kotlin Android app, যেটা device-এ install করা apps দেখায়, sort/search করে,
আর system uninstall dialog দিয়ে app remove করে। Reference app-টা native Android (Kotlin +
Java) ছিল — এই project-টা পুরো নতুন code দিয়ে Flutter-এ লেখা। Reference app-এর কোনো code,
graphics, icon বা text কপি করা হয়নি।

Play identity (fixed): **`com.keshabstudios.goodbyeapps`** · title: **Goodbye Apps – Uninstaller**

A Flutter reimplementation of a typical "uninstaller" app. The UI is Flutter; the parts
that Android only exposes natively (package list, icons, uninstall intents, RAM info) are
implemented in Kotlin and exposed over a `MethodChannel`.

## Features

- **Two tabs** — User apps / System apps, with live counts.
- **App list** — launcher icon, label, package name, APK size, install/update date.
- **Sort** — by name, date or size, ascending/descending.
- **Search** — by app name or package name.
- **Per-app actions** — Open, App info, Search in Google Play, Uninstall.
- **Multi-select** — checkbox selection, select all, batch uninstall with total size.
- **Free memory bar** — available RAM from `ActivityManager.MemoryInfo`.
- **Live refresh** — `PACKAGE_ADDED` / `PACKAGE_REMOVED` / `PACKAGE_REPLACED`
  broadcasts trigger a reload while the app is open.
- **Theme** — system / light / dark, persisted with `shared_preferences`.
- **Settings** — rate, share, feedback, privacy policy, version.

System apps cannot be uninstalled by the OS; the UI disables the action and explains why.

## Build docs / roadmap

যা যা বাকি আছে আর কীভাবে বানাবে — সব `docs/` folder-এ:

| Doc | কী |
|---|---|
| [docs/README.md](docs/README.md) | index, priority, effort estimate |
| [01 icon & brand](docs/01-icon-and-brand.md) | adaptive icon, Play graphics, screenshot plan |
| [02 signing & release](docs/02-signing-and-release.md) | keystore, `key.properties`, `.aab`, versioning |
| [03 Play Console](docs/03-play-console.md) | listing copy, data safety, permission declaration |
| [04 privacy policy](docs/04-privacy-policy.md) | host করার-ready policy (EN + BN) |
| [05 testing](docs/05-testing-checklist.md) | device matrix + edge cases |
| [06 status bar notification](docs/06-status-bar-notification.md) | original-এর notification feature |
| [07 icon lazy-loading](docs/07-icon-lazy-loading.md) | ২০০+ app-এ list fast |
| [08 accurate size](docs/08-accurate-app-size.md) | data + cache size |
| [09 home shortcut](docs/09-home-screen-shortcut.md) | pinned shortcut |
| [10 Bangla](docs/10-bangla-localization.md) | bn localization |
| [11 ads & IAP](docs/11-ads-and-iap.md) | AdMob + Remove Ads |

## Project layout

```
lib/
  main.dart                  MaterialApp, Material 3 theming
  models/app_info.dart       AppInfo model, byte/date formatting, sorting enum
  services/native_apps.dart  MethodChannel + EventChannel wrapper
  services/settings.dart     Theme persistence
  state/apps_controller.dart List state: load, filter, sort, selection, uninstall
  screens/home_screen.dart   Tabs, app list, search, sort sheet, action sheet
  screens/settings_screen.dart
  widgets/app_tile.dart      List row + icon loader
android/app/src/main/kotlin/com/keshabstudios/goodbyeapps/MainActivity.kt
```

### Native bridge (`goodbye_apps/native`)

| Method | Returns | Notes |
| --- | --- | --- |
| `listApps` | `List<Map>` | Runs on a background executor; icon is a PNG `ByteArray` (max 144 px) |
| `uninstall` | `bool` | `Intent.ACTION_DELETE` with `package:` URI |
| `launch` | `bool` | `getLaunchIntentForPackage` |
| `appInfo` | `bool` | `Settings.ACTION_APPLICATION_DETAILS_SETTINGS` |
| `playStore` | `bool` | `market://` with HTTPS fallback |
| `shareApp` | `bool` | `ACTION_SEND` chooser |
| `openUrl` | `bool` | `ACTION_VIEW` |
| `freeMemory` | `{available,total,lowMemory}` | `ActivityManager.MemoryInfo` |
| `appVersion` | `{versionName,versionCode}` | |

`goodbye_apps/events` (`EventChannel`) emits `PACKAGE_ADDED`, `PACKAGE_REMOVED`,
`PACKAGE_REPLACED`.

## Build

```bash
flutter pub get
flutter analyze
flutter build apk --release
# or, on a connected device
flutter run
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Before publishing on Google Play

1. **Application id** is already set to `com.keshabstudios.goodbyeapps` in
   `android/app/build.gradle.kts` and `namespace`/Kotlin package match it. Do not change it
   after the first upload — Play treats it as permanent.
2. **App icon and copy.** Replace the launcher icon with your own and keep
   `android:label="Goodbye Apps – Uninstaller"` in sync with the Play listing title.
3. **`QUERY_ALL_PACKAGES` declaration.** Play Console asks for a declaration for this
   permission. An app whose core purpose is installing/uninstalling/managing apps is an
   allowed use case — describe exactly that in the declaration.
4. **Privacy policy.** `privacyPolicyUrl` and `supportEmail` live in
   `lib/screens/settings_screen.dart`; point them at hosted pages on `goodbyeapps.com`.
   Play requires a policy for apps that request sensitive permissions, and the
   Data safety form must match what the app actually does.
5. **Signing.** Release builds currently use the debug key. Create an upload keystore and
   configure `signingConfigs` before uploading.
6. **Ads / billing.** This build has neither. If you add AdMob or in-app purchases, you must
   add the SDKs, the consent flow (UMP) and the billing configuration yourself.

## Legal note

This is an independent implementation. The reference APK was inspected only to understand
its feature set and screen behaviour; no source, resources, fonts, images or strings were
copied. Shipping a 1:1 visual clone of an existing published app under its name can be
rejected under Google Play's impersonation and intellectual-property policies, so ship it
under your own brand and design.
