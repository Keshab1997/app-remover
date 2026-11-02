# 10 — Bangla localization (এবং অন্য ভাষা)

**Priority:** nice-to-have — BD-র user-এর জন্য ভালো conversion
**Effort:** ৩ ঘণ্টা

---

## 1. Setup

### `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any

flutter:
  generate: true      # ← এটা যোগ করো
  uses-material-design: true
```

### `l10n.yaml` (project root-এ নতুন file)

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-dir: lib/l10n/generated
synthetic-package: false
nullable-getter: false
```

> `synthetic-package: false` দিলে generated file গুলো `lib/l10n/generated/`-এ থাকে —
> IDE-তে খোঁজা সহজ, আর নতুন Flutter version-এ import path ভাঙে না।

### `lib/main.dart`

```dart
import 'l10n/generated/app_localizations.dart';

MaterialApp(
  onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // ...
)
```

`flutter pub get` + `flutter gen-l10n` (build-এর সময় automatic-ও হয়)।

---

## 2. String table

পুরো UI-তে এখন যত hardcoded string আছে, সব এখানে। বাঁ দিকের key দিয়ে ARB বানাবে।

| Key | English | বাংলা |
|---|---|---|
| `appTitle` | Goodbye Apps | Goodbye Apps *(brand translate করো না)* |
| `tabUserApps` | User apps | ইউজার অ্যাপ |
| `tabSystemApps` | System apps | সিস্টেম অ্যাপ |
| `loadingApps` | Loading apps… | অ্যাপ লোড হচ্ছে… |
| `searchApps` | Search apps | অ্যাপ খুঁজুন |
| `noMatches` | No matches | কিছু পাওয়া যায়নি |
| `appsNotFound` | Apps not found | কোনো অ্যাপ পাওয়া যায়নি |
| `pullToRefresh` | Pull down to refresh the list. | লিস্ট রিফ্রেশ করতে নিচে টানুন। |
| `tryDifferentSearch` | Try a different name or package. | অন্য নাম বা প্যাকেজ দিয়ে চেষ্টা করুন। |
| `sort` | Sort | সাজান |
| `sortByName` | Sort by name | নাম অনুযায়ী সাজান |
| `sortByDate` | Sort by date | তারিখ অনুযায়ী সাজান |
| `sortBySize` | Sort by size | সাইজ অনুযায়ী সাজান |
| `ascending` | Ascending | ছোট থেকে বড় |
| `descending` | Descending | বড় থেকে ছোট |
| `toggleSortDirection` | Toggle sort direction | সাজানোর দিক বদলান |
| `selectedCount` | {count} selected | {count}টি নির্বাচিত |
| `appsAndSize` | {count} apps • {size} | {count}টি অ্যাপ • {size} |
| `uninstall` | Uninstall | আনইনস্টল |
| `open` | Open | খুলুন |
| `appInfo` | App info | অ্যাপ তথ্য |
| `searchInPlay` | Search in Google Play | Google Play-তে খুঁজুন |
| `systemAppsProtected` | System apps can't be uninstalled | সিস্টেম অ্যাপ আনইনস্টল করা যায় না |
| `cancel` | Cancel | বাতিল |
| `tryAgain` | Try again | আবার চেষ্টা করুন |
| `settings` | Settings | সেটিংস |
| `theme` | Theme | থিম |
| `systemDefault` | System default | সিস্টেম ডিফল্ট |
| `light` | Light | লাইট |
| `dark` | Dark | ডার্ক |
| `rateApp` | Rate this app | অ্যাপটি রেট করুন |
| `rateSubtitle` | Give us 5 stars on Google Play | Google Play-তে ৫ স্টার দিন |
| `shareApp` | Share app | অ্যাপ শেয়ার করুন |
| `sendFeedback` | Send feedback | মতামত পাঠান |
| `privacyPolicy` | Privacy policy | প্রাইভেসি পলিসি |
| `version` | Version | ভার্সন |
| `freeMemory` | Free memory | ফ্রি মেমোরি |
| `used` | {used} / {total} used | {used} / {total} ব্যবহৃত |
| `uninstallOne` | Uninstall app? | অ্যাপ আনইনস্টল করবেন? |
| `uninstallMany` | Uninstall {count} apps? | {count}টি অ্যাপ আনইনস্টল করবেন? |
| `uninstallConfirmBody` | The system will ask you to confirm each uninstall. | প্রতিটি আনইনস্টলের জন্য সিস্টেম অনুমতি চাইবে। |
| `addToHomeScreen` | Add to home screen | হোম স্ক্রিনে যোগ করুন |
| `statusBar` | Status bar notification | স্ট্যাটাস বার নোটিফিকেশন |

Bold না করা বাকি string-ও একইভাবে extract করো (`lib/screens/*`, `lib/widgets/*`)।

---

## 3. `lib/l10n/app_en.arb`

```json
{
  "@@locale": "en",
  "appTitle": "Goodbye Apps",
  "tabUserApps": "User apps",
  "tabSystemApps": "System apps",
  "loadingApps": "Loading apps…",
  "searchApps": "Search apps",
  "selectedCount": "{count} selected",
  "@selectedCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "uninstallMany": "Uninstall {count} apps?",
  "@uninstallMany": {
    "placeholders": { "count": { "type": "int" } }
  },
  "freeMemory": "Free memory",
  "uninstall": "Uninstall"
}
```

(পুরো table-টা একই format-এ বসাও।)

## 4. `lib/l10n/app_bn.arb`

```json
{
  "@@locale": "bn",
  "appTitle": "Goodbye Apps",
  "tabUserApps": "ইউজার অ্যাপ",
  "tabSystemApps": "সিস্টেম অ্যাপ",
  "loadingApps": "অ্যাপ লোড হচ্ছে…",
  "searchApps": "অ্যাপ খুঁজুন",
  "selectedCount": "{count}টি নির্বাচিত",
  "uninstallMany": "{count}টি অ্যাপ আনইনস্টল করবেন?",
  "freeMemory": "ফ্রি মেমোরি",
  "uninstall": "আনইনস্টল"
}
```

---

## 5. ব্যবহার

```dart
final l10n = AppLocalizations.of(context);

Text(l10n.tabUserApps)
Text(l10n.selectedCount(selected.length))
```

`AppTile`-এর মতো widget-এ `context` থাকলেই `AppLocalizations.of(context)` পাওয়া যায়।

---

## 6. সংখ্যা ও তারিখ

- টাকার মতো জিনিস নেই, তাই সংখ্যা ইংরেজিতে রাখাই ভালো (`2.1 GB`, `3 apps`) —
  বাংলা সংখ্যা (`২.১`) অনেক user-এর কাছে অপরিচিত লাগে।
- `formatDate()` এখন ইংরেজি মাসের নাম দেয়। locale-aware করতে:

```dart
import 'package:intl/intl.dart';

String formatDate(DateTime date, String locale) =>
    DateFormat.yMMMd(locale).format(date);
```

`AppLocalizations.of(context).localeName` দিয়ে locale পাওয়া যাবে।

---

## 7. Play listing-এ language

Play Console → Store listing → **Manage translations** → Bengali যোগ করো।
Title-টা ইংরেজিতেই রাখো (brand), short description বাংলায় দিতে পারো:

```text
দুই ট্যাপে অ্যাপ আনইনস্টল করুন। সাইজ, ইনস্টল তারিখ দেখুন, জায়গা খালি করুন।
```

---

## 8. Acceptance

- [ ] ফোনের ভাষা বাংলা → পুরো UI বাংলা (brand নাম বাদে)
- [ ] ফোনের ভাষা ইংরেজি → ইংরেজি
- [ ] কোনো hardcoded string থাকে না (`grep -rn '"[A-Z]' lib/` করে দেখো)
- [ ] Placeholder ({count}) সব ভাষায় ঠিক বসে
- [ ] Font scale 2x-এ বাংলা text কাটে না
- [ ] `flutter gen-l10n` warning ছাড়া চলে

## 9. Files

```text
pubspec.yaml
l10n.yaml                              (নতুন)
lib/l10n/app_en.arb                    (নতুন)
lib/l10n/app_bn.arb                    (নতুন)
lib/l10n/generated/**                  (generated, commit করো)
lib/main.dart
lib/screens/**, lib/widgets/**
```
