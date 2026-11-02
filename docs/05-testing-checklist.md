# 05 — Testing checklist (Play-তে দেওয়ার আগে)

**Priority:** blocker
**Effort:** ২ ঘণ্টা (আসল ফোনে)

---

## 1. Device matrix

কমপক্ষে এগুলোতে test করো:

| # | Device | Android | কেন |
|---|---|---|---|
| 1 | নিজের daily phone | 13/14/15 | main flow |
| 2 | পুরনো phone / emulator | 11 (API 30) | permission + package visibility |
| 3 | Samsung / Xiaomi / Realme | যেকোনো | OEM launcher-এ uninstall dialog আলাদা |
| 4 | Work profile / Dual app থাকলে | যেকোনো | package list duplicate |

Emulator বানানো (Android SDK আছে):

```bash
sdkmanager "system-images;android-34;google_apis;arm64-v8a"
avdmanager create avd -n goodbye34 -k "system-images;android-34;google_apis;arm64-v8a"
flutter emulators --launch goodbye34
```

---

## 2. Functional cases

### App list
- [ ] প্রথম launch-এ ২ সেকেন্ডের মধ্যে list আসে
- [ ] প্রতিটা row-তে icon, নাম, package, size, date ঠিক
- [ ] User apps / System apps tab-এর count মেলে
- [ ] Tab swipe করলে list ঠিক থাকে
- [ ] ১৫০+ app থাকলেও scroll smooth (jank নেই)
- [ ] একই নামের দুইটা app আলাদা দেখা যায় (package name দিয়ে)

### Sort
- [ ] Name A→Z, Z→A
- [ ] Size ছোট→বড়, বড়→ছোট
- [ ] Date পুরনো→নতুন, নতুন→পুরনো
- [ ] Sort sheet বন্ধ করে আবার খুললে selection ঠিক দেখায়
- [ ] Sort করার পর scroll position ঠিক থাকে

### Search
- [ ] নামের অংশ লিখলে filter হয়
- [ ] package name লিখলেও পাওয়া যায়
- [ ] uppercase / lowercase দুইটাতেই কাজ করে
- [ ] কোনো match না থাকলে "No matches" দেখায়
- [ ] Back চাপলে search বন্ধ + full list ফিরে আসে

### Actions
- [ ] **Open** — app চালু হয়; launcher intent নেই এমন app-এ crash করে না
- [ ] **App info** — system settings-এর app page খোলে
- [ ] **Play Store** — Play-তে app page খোলে; Play না থাকলে browser-এ fallback
- [ ] **Uninstall (user app)** — Android confirm dialog আসে, confirm-এ app যায়
- [ ] **Uninstall (system app)** — action disabled + "System apps can't be uninstalled"
- [ ] Uninstall cancel করলে list অক্ষত থাকে
- [ ] Uninstall করার পরে list auto-refresh হয়

### Multi-select
- [ ] Checkbox-এ tap করলে select / deselect
- [ ] Long-press করলে select হয়, action sheet খোলে না
- [ ] Select all শুধু current tab-এর app select করে
- [ ] Selection bar-এ count + total size সঠিক
- [ ] X চাপলে selection clear
- [ ] Batch uninstall-এ প্রতিটা app-এর জন্য আলাদা confirm আসে
- [ ] মাঝপথে cancel করলে বাকিগুলো selection-এ থাকে

### Free memory
- [ ] Free RAM দেখায়, ০ B না
- [ ] Refresh-এ value বদলায়
- [ ] Total RAM সঠিক (device settings-এর সাথে মেলাও)

### Settings
- [ ] Theme System / Light / Dark — সাথে সাথে বদলায়
- [ ] App বন্ধ করে আবার খুললে theme মনে আছে
- [ ] Rate / Share / Feedback / Privacy — প্রতিটা intent খোলে
- [ ] Version নাম্বার build-এর সাথে মেলে
- [ ] Back চাপলে home-এ ফেরে

### Events
- [ ] Play Store থেকে নতুন app install → list auto-refresh
- [ ] App uninstall → list auto-refresh
- [ ] App update → size/date update

---

## 3. Permission cases

- [ ] প্রথম launch-এ কোনো permission popup আসে না (ভালো UX)
- [ ] Notification permission চাইলে deny → app crash করে না (feature চালু হলে)
- [ ] Notification permission deny করার পরে settings-এ আবার চাইলে guide দেখায়
- [ ] `QUERY_ALL_PACKAGES` ছাড়া build করলে (শুধু test-এ) list আংশিক আসে — এটাই expected

---

## 4. Edge cases

- [ ] ০টা user app (fresh emulator) → empty state
- [ ] ০টা system app (rare) → empty state
- [ ] খুব বড় APK (500MB+ game) → size সঠিক, list lag করে না
- [ ] নামে ইমোজি / বাংলা / আরবি → ellipsis ঠিক
- [ ] Icon নেই এমন app → fallback icon
- [ ] Split APK app (AAB-installed) → size-এ সব split যোগ হয়
- [ ] App uninstall করার সময় list খোলা → crash করে না
- [ ] Device rotate → selection + tab state থাকে
- [ ] Dark mode-এ contrast ঠিক
- [ ] Font scale 1.3x / 2x → text কাটে না
- [ ] TalkBack চালু → row পড়া যায়, checkbox label আছে

---

## 5. Release-build specific

- [ ] `flutter build apk --release` দিয়ে install (debug নয়)
- [ ] Minify/R8 চালু থাকলে channel call কাজ করে
- [ ] Cold start < 3s
- [ ] App size reasonable (< 20MB)
- [ ] `adb logcat | grep -i "flutter\|AndroidRuntime"` — কোনো exception নেই
- [ ] Battery: ৫ মিনিট চালিয়ে Settings → Battery usage-এ excessive না
- [ ] Airplane mode-এও সব কাজ করে (network লাগে না)

---

## 6. Crash হলে কী করবে

```bash
adb logcat -c && adb logcat | grep -E "AndroidRuntime|flutter"
```

Play-তে যাওয়ার আগে `flutter build appbundle --release` + `bundletool` install করে
**অন্তত একবার** পুরো flow চালাও — split install-এ resource missing হলে সেখানেই ধরা পড়বে।

---

## 7. Sign-off

- [ ] উপরের সব ✅
- [ ] ২ জন আলাদা মানুষ test করেছে
- [ ] কোনো P0/P1 bug নেই
- [ ] Screenshot নেওয়া হয়েছে (doc 01)
- [ ] Privacy policy live (doc 04)
