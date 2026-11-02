# Build docs — index

এই folder-এ app-টা Play Store-এ তোলার আগে যা যা বানাতে/করতে হবে, তার প্রতিটার জন্য আলাদা
spec আছে। প্রতিটা doc-এ **কী বানাতে হবে, কোন file-এ, কী code, কীভাবে verify করবে** —
সব লেখা আছে। উপরের থেকে নিচে priority অনুযায়ী সাজানো।

| # | Doc | কী কাজ | Blocker? | সময় |
|---|---|---|---|---|
| 01 | [Icon & brand](01-icon-and-brand.md) | Adaptive icon, Play icon, feature graphic, screenshot plan | ✅ Play-তে যেতে | ৩–৪ ঘণ্টা |
| 02 | [Signing & release](02-signing-and-release.md) | Keystore, `key.properties`, `.aab` build, versioning | ✅ Play-তে যেতে | ১ ঘণ্টা |
| 03 | [Play Console listing](03-play-console.md) | Listing copy, data safety, `QUERY_ALL_PACKAGES` declaration, testing track | ✅ Play-তে যেতে | ২ ঘণ্টা |
| 04 | [Privacy policy](04-privacy-policy.md) | Host করার মতো পুরো policy text + permissions ব্যাখ্যা | ✅ Play-তে যেতে | ১ ঘণ্টা |
| 05 | [Testing checklist](05-testing-checklist.md) | Device matrix, edge case, release-এর আগে QA | ✅ Play-তে যেতে | ২ ঘণ্টা |
| 06 | [Status bar notification](06-status-bar-notification.md) | Original-এর status bar feature + permission flow | না | ৩–৪ ঘণ্টা |
| 07 | [Icon lazy-loading](07-icon-lazy-loading.md) | ২০০+ app-এ list fast করা | না | ৩ ঘণ্টা |
| 08 | [Accurate app size](08-accurate-app-size.md) | APK + data + cache size (StorageStatsManager) | না | ২ ঘণ্টা |
| 09 | [Home screen shortcut](09-home-screen-shortcut.md) | যেকোনো app-এর pinned shortcut | না | ১–২ ঘণ্টা |
| 10 | [Bangla localization](10-bangla-localization.md) | `app_bn.arb`, সব string extract | না | ৩ ঘণ্টা |
| 11 | [Ads & Remove Ads](11-ads-and-iap.md) | AdMob + one-time purchase (original-এ ছিল) | না | ১ দিন |

## Suggested order

```text
১. 02 signing        (এটা ছাড়া .aab বানানো যাবে না)
২. 01 icon           (Play listing-এর জন্য icon লাগবেই)
৩. 03 + 04 listing   (policy ছাড়া upload আটকে যাবে)
৪. 05 testing        (আসল ফোনে একবার পুরো flow)
৫. 06 / 07 / 08      (v1.1 — release-এর পরে)
৬. 10 / 09           (v1.1)
৭. 11 ads            (v1.2, যখন user base হবে)
```

## এখন যা আছে (v1.0 code complete)

- [x] User / System app tabs, count সহ
- [x] Icon, name, package, size, date সহ list
- [x] Name / Date / Size sort, ascending–descending
- [x] Search (name + package)
- [x] Open, App info, Play Store, Uninstall action
- [x] Multi-select + select all + batch uninstall
- [x] Free RAM bar
- [x] App install/remove হলে auto-refresh
- [x] Theme (system / light / dark), persisted
- [x] Settings: rate, share, feedback, privacy, version
- [x] Package `com.keshabstudios.goodbyeapps`, title "Goodbye Apps – Uninstaller"

## যা এই batch-এ যোগ হয়েছে (code, main-এ push করা)

- [x] Status bar notification — doc 06 (`NotificationHelper.kt`, BootReceiver, Settings toggle)
- [x] Icon lazy-loading — doc 07 (`IconStore`, প্রতি row-এর icon on demand)
- [x] Accurate size (data + cache) — doc 08 (`StorageStatsManager`, usage access row)
- [x] Home screen shortcut — doc 09 (`addShortcut`, action sheet-এ entry)
- [x] Bangla — doc 10 (`lib/l10n/app_bn.arb`, পুরো UI extract করা)
- [x] Release signing — `e620419`-এ wire করা আছে
- [x] Privacy policy **text** — `docs/legal/`-এ host-ready HTML (English + বাংলা)
- [x] Play listing **copy** — `distribution/listing/`, উত্তর `distribution/app-content-answers.md`

## এখনো যা বাকি (তোমার হাত লাগবে)

- [x] App icon — doc 01: `tool/make_icons.py` থেকে adaptive/legacy/Play/feature graphic (brand `#3D5AFE`, flat glyph)
- [ ] Privacy policy **hosting** + `privacyPolicyUrl` update — file ready, URL বাকি
- [ ] `.aab` build verify — Actions → *Build Android APK or AAB (Manual)*
- [ ] Play Console upload — doc 03 (Console-এর ভেতরে ঢুকতে হয়)
- [ ] Device testing — doc 05
- [ ] Ads / Remove Ads — doc 11 (AdMob app ID লাগবে)

## Build command (যখনই দরকার)

```bash
cd ~/Projects/app_remover
flutter pub get
flutter analyze
flutter build appbundle --release     # Play-এর জন্য
flutter build apk --release           # সাইড-load টেস্টের জন্য
```
