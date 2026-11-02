# 03 — Play Console: app create থেকে release

**Priority:** blocker
**Effort:** ২ ঘণ্টা + review-এর অপেক্ষা

---

## 0. আগে যা লাগবে

- [ ] Google Play Developer account (একবার $25)
- [ ] Signed `.aab` (doc 02)
- [ ] Icon 512×512, feature graphic 1024×500, min ২টা screenshot (doc 01)
- [ ] Hosted privacy policy URL (doc 04)
- [ ] Support email (domain register করার পর `hello@goodbyeapps.com`)

---

## 1. App তৈরি

Play Console → **Create app**:

| Field | Value |
|---|---|
| App name | `Goodbye Apps – Uninstaller` (২৬ অক্ষর) |
| Default language | English (United States) |
| App or game | App |
| Free or paid | Free |
| Declarations | Play policies + US export laws ✓ |

> নতুন **personal** developer account হলে: production release-এর আগে **closed testing-এ
> কমপক্ষে ১২ জন tester, ১৪ দিন continuous** — নিয়ম বদলায়, Console-এ current requirement দেখে নাও।

---

## 2. Store listing copy

### Short description (৮০ অক্ষরের মধ্যে)

```text
Uninstall apps in two taps. Check size, install date and free up space fast.
```

(৭৬ অক্ষর — Play-তে keyword stuffing করো না, এটাই ভালো।)

### Full description (draft — ৪০০০-এর মধ্যে)

```text
Goodbye Apps makes removing unwanted apps quick and clear.

See every app installed on your phone with its icon, package name, APK size and
install date. Sort by name, size or date, search by name, and uninstall one app
or many at once. System apps are shown separately and marked as protected, so
you always know what can and cannot be removed.

WHY GOODBYE APPS
• Clear list – every app with size and install date, no clutter
• Fast removal – multi-select and uninstall several apps in a row
• Smart sorting – by name, date or size, ascending or descending
• Instant search – find an app by name or package name
• System app awareness – system apps are separated and protected
• Free memory at a glance – see available RAM on every screen
• Light and dark theme – follows your system or your choice

HOW IT WORKS
Goodbye Apps uses the standard Android uninstall dialog. Android always asks
you to confirm, so no app is ever removed silently.

PRIVACY
No account. No analytics. No ads. The app does not send your app list anywhere.
It only reads the installed app list on your device so it can show it to you.

PERMISSIONS
• Installed app list – to show your apps
• Uninstall requests – to open the system uninstall dialog
• Notifications (optional) – only if you turn on the status bar feature

Goodbye Apps is a small, focused utility. If something is missing, tell us at
hello@goodbyeapps.com.
```

### Keyword targets (description-এ স্বাভাবিকভাবে ঢোকাও)

`uninstaller`, `uninstall apps`, `app remover`, `remove apps`, `app manager`,
`free up space`, `apk size`, `system apps`

⚠️ Title বা description-এ অন্য কোনো brand-এর নাম লিখো না। "Best", "#1", "Free VPN"
জাতীয় claim দিও না — policy violation।

---

## 3. App content section (সবগুলো form পূরণ)

| Section | Answer |
|---|---|
| Privacy policy | `https://goodbyeapps.com/privacy-policy` |
| App access | All functionality available without login |
| Ads | No (এখন ads নেই) |
| Content rating | Utility → Everyone |
| Target audience | 18+ (Families policy এড়াতে; app সব বয়সেই কাজ করে) |
| News app | No |
| COVID / health | No |
| Data safety | নিচে দেখো |
| Government app | No |
| Financial features | No |
| Photo/video permissions | No |

### Data safety — এখন যা বলতে হবে

- Data collected: **None**
- Data shared: **None**
- Data processed ephemerally: **None**
- Security practices: data not transmitted (✅), no account creation

কারণ: app কোনো network-এ ডেটা পাঠায় না। Theme preference শুধু device-এ
`shared_preferences`-এ থাকে।

> Ads বা Firebase যোগ করলে এই form **অবশ্যই** update করতে হবে, নাহলে policy strike।

---

## 4. `QUERY_ALL_PACKAGES` declaration

Play Console → **App content → Sensitive permissions → Installed apps (QUERY_ALL_PACKAGES)**।

Justification (কপি করে বসাও):

```text
Goodbye Apps is an app-management utility whose core, user-visible function is
to list the applications installed on the device so the user can inspect them
and uninstall them.

The QUERY_ALL_PACKAGES permission is required to display a complete, accurate
list of installed apps with their icons, package names, APK sizes and install
dates. Without it, Android 11+ returns only a partial list and the app's core
purpose cannot be fulfilled. The app does not collect, transmit or share the
installed app list; all processing happens on the device.

This falls under the permitted use case "device and app management" for
QUERY_ALL_PACKAGES.
```

সাথে screen recording বা screenshot দিতে বললে: app list + uninstall flow-এর ৩০ সেকেন্ডের
video দাও।

---

## 5. Graphics upload

| Asset | File | Note |
|---|---|---|
| App icon | 512×512 PNG | alpha নেই |
| Feature graphic | 1024×500 | text ৫০px-এর বড় |
| Phone screenshots | ২–৮টা | 1080×1920+ |
| 7-inch tablet | optional | |
| 10-inch tablet | optional | |

---

## 6. Release track

```text
Internal testing  →  apk/aab upload  →  নিজে + ২ জন test
      ↓
Closed testing    →  ১২+ tester, ১৪ দিন (personal account rule)
      ↓
Production        →  staged rollout 20% → 50% → 100%
```

প্রতিটা track-এ:
1. **Create new release**
2. `.aab` upload
3. Release notes (English):

```text
First release.
• See every installed app with size and install date
• Sort by name, date or size
• Uninstall one app or many at once
• Light and dark theme
```

4. **Review release** → **Start rollout**

---

## 7. Review-এর আগে self-check

- [ ] App crash করে না (release build-এ, minify সহ)
- [ ] First screen-এ ২ সেকেন্ডের বেশি blank নেই
- [ ] Privacy policy URL live (200 OK)
- [ ] Support email-এ mail যায়
- [ ] সব screenshot-এ আসল app-এর UI (mockup না)
- [ ] Description-এ `QUERY_ALL_PACKAGES`-এর কথা স্পষ্ট
- [ ] Ads "No" — যদি পরে ads যোগ করো, form update
- [ ] `versionCode` unique
- [ ] Target SDK current Play requirement (এখন Flutter যা দেয়, সেটাই ঠিক)

---

## 8. Reject হলে সাধারণ কারণ

| কারণ | সমাধান |
|---|---|
| Impersonation | নাম/icon/description অন্য app-এর মতো হলে বদলাও |
| `QUERY_ALL_PACKAGES` justification দুর্বল | doc-এর text-টা ব্যবহার করো, video দাও |
| Privacy policy নেই / 404 | host করে URL দাও |
| Data safety mismatch | ads/analytics যোগ করলে form update |
| Broken functionality | আসল device-এ test করে video দাও |
| Permissions over-ask | অদরকারি permission manifest থেকে বাদ দাও |
