# 12 — UX/design pass (user-এর জন্য আরও ভালো)

**Priority:** retention + review-রেটিং — Play-তে "good but confusing" রিভিউগুলো এখান থেকেই আসে
**Effort:** পুরোটা ১–২ দিন; P0 গুলো আলাদা আলাদা করেও করা যাবে (প্রতিটা ~৩০–৬০ মিনিট)

এটা code review থেকে বের করা list, ধারণা নয় — প্রতিটা item-এর পাশেই কোথায়
কী হচ্ছে সেটা লেখা আছে, তাই verify করা সহজ।

Order: **P0 = user এখনই আটকাচ্ছে / feature খুঁজে পাচ্ছে না**, P1 = মনে থাকার মতো
ভালো লাগে, P2 = polish।

---

## P0-1 — "Pull down to refresh" লিখে দিয়েছে, কিন্তু pull করলে কিছু হয় না

`_appList()` শুধু populate অবস্থায় `RefreshIndicator` দেয় (`home_screen.dart:202`)।
খালি বা ভুল অবস্থায় `_EmptyState` সরাসরি return হয়, আর `_EmptyState` ভেতরে
`AlwaysScrollableScrollPhysics` আছে বলে list টানলে stretch দেখায় — refresh হয় না।
মানে app-এর একমাত্র empty-state copy ("Pull down to refresh the list.") মিথ্যা।

Fix: `_body()`-র failure branch আর `_appList()`-র empty branch দুটোই একই
`RefreshIndicator(onRefresh: _apps.load, ...)` দিয়ে wrap করো। সাথে empty state-এ
একটা `FilledButton.tonal('Refresh')` — টানতে না পারলেও কাজ থাকবে।

---

## P0-2 — Detailed sizes feature টা অদৃশ্য

doc 08 অনুযায়ী `_SizeBreakdown` usage access না থাকলে `SizedBox.shrink()`
দেখায়। ফল: user কখনোই বুঝবে না এই feature টা আছেই — Settings-এ গিয়ে খুলতে
হবে, যেখানে যাবার কোনো পথ নেই। "hide when unavailable" ঠিক ছিল count-এর
জন্য, discovery-র জন্য না।

Fix: shrink না করে এক লাইন inline prompt দেখাও —
`Sizes are APK only · Enable detailed sizes` → tap = usage access settings
(`NativeApps.openUsageAccessSettings()` তো আছেই)। প্রথমবার dismiss করলে `settings.dart`-এ একটা `sizes_prompt_dismissed`
  bool রেখে দাও, আর কখনো দেখাবে না।

---

## P0-3 — Batch uninstall চলাকালীন কিছুই দেখায় না

`AppsController.uninstallSelected()` প্রতি app-এ ৬০ms wait করে
(`apps_controller.dart`), screen-এ তখন পর্যন্ত কোনো progress নেই, আর
`NativeApps.uninstall()`-এর `bool` ফেলে দেওয়া হয় — fail হলেও নীরব।
৬টা app delete করতে ৩.৬ সেকেন্ড user অন্ধকারে বসে থাকে।

Fix:
- progress: action bar-টাই বদলাও — `Uninstalling 3 of 6…` + `LinearProgressIndicator`
- শেষে feedback: `Freed 1.4 GB · 6 apps removed` snackbar (size =
  uninstall-এর আগে ধরা `selectedSize`-এর total, count = কয়টা intent গেছে)
- fail হলে honest message: `2 apps could not be opened in the system dialog`
- হ্যাপটিক: শুরুতে `HapticFeedback.mediumImpact()` (codebase-এ এখন
  `HapticFeedback` কোথাও নেই — grep করলে ০ পাওয়া যায়)

---

## P0-4 — প্রথম launch-এ spinner, list নয়

২০ app-এর metadata ১৫০ms-এই আসে (doc 07-এর পর), কিন্তু UI তবুও
`CircularProgressIndicator` + "Loading apps…" দেখায় — user চোখে ধীর লাগে,
আর list বসার জায়গাটা ফাঁকা থাকে।

Fix: প্রথম frame-এ ৮টা skeleton row (grey icon box + দুটো bar) দেখাও, data
এসে গেলে fade-in। ২০ লাইনের widget, perceived speed সবচেয়ে সস্তায় বাড়ে।
`Shimmer` dependency লাগবে না — `AnimatedOpacity`-ই যথেষ্ট।

---

## P0-5 — Select all কখনো ভুল tab বেছে নেয়

```dart
onPressed: () => _apps.selectAll(_apps.appsFor(system: _tabs.index == 1)),
```
`TabController.index` swipe-অ্যানিমেশনের মাঝে পুরনো tab-এর দিকে থাকে, তাই
swipe করার সাথে সাথে "select all" চাপলে অন্য tab-এর app select হয়ে যেতে পারে —
এটা destructive action-এর input, এখানে tolerance থাকা উচিত নয়।

Fix: `AppsController`-এ present `bool system` state রাখো (tab listener থেকে
update), অথবা select-all-এর সময়ে `_tabs.indexIsChanging` check করো।
Copy-তেও স্পষ্ট করো: "Select all 42 in User apps" — user যাকে select করছে
সেটা দেখা মাত্র ভয় কমে।

---

## P1-6 — Default sort "name" রাখা এই app-এর কাজ বোঝে না

User এই app খোলে জায়গা খালি করতে। সবচেয়ে বড় অ্যাপটা আগে দেখাই তার কাজ,
নামের alphabet নয়। এটা এক লাইনের পরিবর্তন, আর impact সবচেয়ে বড়:

```dart
SortField _sortField = SortField.size;
bool _ascending = false;
```

সাথে sort choice টা persist করো — এখন `settings.dart`-এ শুধু
`theme_mode` + `status_bar_enabled` আছে, তাই প্রতিবার restart-ে sort name
অনুসারে ফিরে আসে। sort + direction + last-used tab (User/System) — তিনটাই
pref-এ রাখা যায়।

---

## P1-7 — "কখনো ব্যবহার হয়নি" ফিল্টার = আসল killer feature

usage access তো P0-2 দিয়েই চাইছ; সেই `PACKAGE_USAGE_STATS` থেকে
`lastTimeUsed`-ও পাওয়া যায়। মানে:

- Chip row-এ: **`Not used in 90 days`**, **`Over 500 MB`**, **`Installed recently`**
- Row-এ secondary line: "Not opened since 12 Jan"

এটাই user-কে "কোনটা মুছব?" প্রশ্নের উত্তর দেয় — uninstaller apps-এর
reviews-এ এই প্রশ্নটাই সবচেয়ে বেশি ওঠে। Kotlin-এ
`UsageStatsManager.queryUsageStats(INTERVAL_YEAR, …)` একবার cache করে
`loadApps()`-এর সাথে পাঠালেই হবে (executor-এ, main thread-এ নয়), আর permission
না থাকলে chip গুলো hide।

---

## P1-8 — Search-এ keyboard results ঢেকে দেয়

`ListView.builder`-এ `keyboardDismissBehavior` নেই (grep: ০), আর search
field-এ `textInputAction: TextInputAction.search` নেই — ফলে Android-এ
"Enter" না চেপে list দেখা যায় না ঠিকমতো, keyboard ৩–৪টা row খেয়ে রাখে।

Fix: list-এ `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`,
field-এ `textInputAction: .search` + `textCapitalization: .none` +
`autofillHints: const []`; row tap-এ keyboard বন্ধ করো; header-এ
"12 of 240 apps" count দেখাও।

---

## P1-9 — Row-এর affordance তিনটা, একটার দরকার

এখন প্রতিটা row-তে: tap (sheet) + long-press (select) + always-on `Checkbox`।
Checkbox সবসময় দেখালে list ভিজ্যুয়ালি ভারী হয়, আর "ট্যাপ করলে খোলে না
টিক পড়ে?" — দ্বিধা তৈরি হয়। Material-এর list-selection pattern পরিষ্কার:

- normal mode: checkbox নেই, tap = sheet, long-press = selection mode
  (enter করার সময় `HapticFeedback.selectionClick()`)
- selection mode: checkbox/`Check` circle আসে, tap = toggle, header bar
  (title "N selected") + bottom bar ("Uninstall", "Select all", "Cancel")

এতে normal browsing এ ৪৮px tap target-এর ভিড় কমে, আর selection mode স্পষ্ট হয়।

---

## P1-10 — Memory bar: একি কাজের দুইটা বোতাম, ছোট tap target

একই screen-এ app bar-এ `refresh` (list reload) আর memory bar-এ আরেকটা
`refresh` icon (size 18 = ~30px tap target, Material মিনিমাম 48)। দুটোর নাম
এক, কাজ আলাদা — user গুলিয়ে ফেলে, অথচ pull-to-refresh (P0-1 ঠিক করলে)ই
দুটোর কাজ করে।

Fix: memory bar-এর icon button বাদ দাও, পুরো bar-টাই tappable করো →
RAM breakdown sheet (Free / Used, "Refresh" ও "Status bar notification"
toggle ওখানেই)। সাথে ২px-এর `LinearProgressIndicator` দিলে সংখ্যা দুটো
পড়ার আগেই বোঝা যায় ফোন কতটা ভরা।

---

## P1-11 — App bar-এ ৪টা icon, ৩টা যথেষ্ট

`search` + `sort` + `refresh` + `settings`। Material 3 অনুযায়ী sort list-এর
উপর chip/filter হিসেবে বেশি স্বাভাবিক (আর বদলালেই list animate হবে), refresh
pull-to-refresh-এর সাথে ডুপ্লিকেট। প্রস্তাব: app bar = title + search +
settings(overflow-এ "How it works"/"Rate"); sort+filter = list-এর ঊপরে
এক লাইনের chip row (`Size ↓`, `Not used in 90 days`, `Over 500 MB`)।

---

## P2-12 — Accessibility, এখন শূন্য

`lib/`-এ `semanticLabel` এর count ০, `Semantics` নেই, haptics নেই।
Screen reader-এ: `Checkbox`-এর নাম নেই ("Unchecked" বলে পড়ে, কোন app-এর
সেটা বোঝা যায় না), tab count-এর মানে বলে না। করা দরকার:

- `Checkbox(semanticsLabel: 'Select ${app.label}')` বা row-কে
  `Semantics(selected: …, checked: …)` দিয়ে wrap
- icon button গুলোতে `tooltip` আছে (ভালো), তবে selection bar-এর
  "Uninstall" button-এ `Semantics(label: 'Uninstall N selected apps')`
- fontScale 2x-এ row-এর ৩ লাইন কেটে যায় কিনা (doc 05-এর checklist-এ এটা
  manual test হিসেবে রাখো, `textScaler` দিয়ে widget test-ও লেখা যায়)
- **Reduce motion** চালু থাকলে icon fade-in আর list animation
  `MediaQuery.disableAnimations` দেখলে animation গুলো skip করো
- light theme-এ `labelSmall` + `onSurfaceVariant` combo WCAG 4.5:1 পড়ে না
  — row-এর size/date লাইন `bodySmall`-এ উঠিয়ে দাও

---

## P2-13 — Tablet/landscape: এক কলাম, বিশাল ফাঁকা

`ListView.builder` একটাই, তাই landscape বা tablet-এ পুরো প্রস্থে ২০টা লম্বা
strip। দুটো অ্যাডাপ্টেশন:

- `LayoutBuilder`/`MediaQuery.sizeOf` দিয়ে ৬০০dp+: `SliverGrid`
  (`childAspectRatio: 3.4`) দুই কলাম — এক হাতে scroll করতে সুবিধা হয়;
- মোটামুটি বড় window-এ `showModalBottomSheet`-এর বদলে
  `showAdaptiveDialog` (Material 3, M3 ডায়ালগ বড় জায়গায় নিজে থেকেই
  centered+fixed-width হয়) — ৩০০dp চওড়া bottom sheet-এ ৬টা action row
  বিরাট ফাঁকা জায়গা নেয়।

---

## P2-14 — ছোট ছোট যা immediately ভালো লাগে

| Item | কোথায় | কী |
|---|---|---|
| Icon এ layout jump নেই ✓ | `app_tile.dart` `SizedBox(48)` | ঠিক আছে, icon এসে ফেড-ইন করলে আরও ভালো (`AnimatedSwitcher`, fade 120ms) |
| New badge | row | ৭ দিনের মধ্যে ইনস্টল হলে small `Installed recently` chip — "এটা কি আমার? " দ্বিধা দূর করে |
| System app reason | sheet | "System apps can't be uninstalled" বাক্যটা ঠিক, কিন্তু পাশে "App info" row থাকলে user জায়গা খোঁজে; system app-এর sheet-এ uninstall-এর জায়গায় "Disable" ব্যাখ্যা (Android-এর own toggle) দেখাও |
| Search history | search bar | last ৫টা query (local pref) — একই app বারবার খোঁজে |
| Sheet-এ copy package name | `_showActions` | long-press-to-copy সাপোর্ট টেক্সট; debug/support-এ সবচেয়ে কাজে লাগে |
| Uninstall count limit | `uninstallSelected` | ২৫টার বেশি হলে "This will ask 25 times" আগেই বলে দাও — system dialog fatigue থেকে বাঁচে |
| Offline honesty | anywhere | network use নেই, কিন্তু first-run-এ এক লাইন "Works offline. Nothing leaves your phone." trust বাড়ায় (doc 04-এর policy-র সাথে মিলে যায়) |

---

## Acceptance

- [ ] empty + error state-এ pull করলে refresh হয়, নাহলে copy মিথ্যা
- [ ] usage access না থাকলে-ও detailed sizes feature দৃশ্যমান (prompt দেখায়)
- [ ] batch uninstall-এ progress + "Freed X GB" feedback আছে
- [ ] প্রথম frame skeleton, spinner না
- [ ] select-all সঠিক tab-এর app নেয় (swipe মাঝখানে চাপলেও)
- [ ] default sort = size desc, আর sort/tab restart-এ মনে থাকে
- [ ] search-এ keyboard dragscroll-ে বন্ধ হয়
- [ ] normal mode-এ checkbox নেই, selection mode-এ আছে
- [ ] screen reader প্রতিটা toggle-র নাম বলে
- [ ] 600dp+ এ দুই কলাম

## Files

```text
lib/screens/home_screen.dart        (P0-1,3,5, P1-8,9,10,11)
lib/state/apps_controller.dart      (P0-3,5, P1-6)
lib/services/settings.dart            (P0-2, P1-6: pref keys)
lib/widgets/app_tile.dart             (P1-9, P2-12, "New" badge)
lib/services/native_apps.dart         (P1-7: lastTimeUsed)
android/.../MainActivity.kt           (P1-7: UsageStatsManager)
test/**                                 (textScaler + select-all + empty-state refresh)
```
