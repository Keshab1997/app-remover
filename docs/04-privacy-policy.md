# 04 — Privacy policy (host করার-ready text)

**Priority:** blocker — Play Console-এ policy URL ছাড়া submit হবে না
**Effort:** ১ ঘণ্টা (host + URL বসানো)

---

## 1. কোথায় host করবে

তিনটা বাস্তব অপশন:

| Option | URL | খরচ | Note |
|---|---|---|---|
| `goodbyeapps.com` (recommended) | `https://goodbyeapps.com/privacy-policy` | ডোমেইন ~$10/বছর | support email-ও এখানে |
| GitHub Pages | `https://keshab1997.github.io/goodbyeapps-legal/privacy.html` | ফ্রি | ১০ মিনিটে হয়ে যায় |
| Google Sites / Notion public page | নিজের URL | ফ্রি | দ্রুত, কিন্তু 덜 professional |

GitHub Pages সবচেয়ে দ্রুত: একটা public repo `goodbyeapps-legal` বানাও, `index.html`-এ
নিচের text রাখো, Settings → Pages → Deploy from branch `main`।

Host করার পরে URL বসাও:
- `lib/screens/settings_screen.dart` → `privacyPolicyUrl`
- Play Console → App content → Privacy policy

---

## 2. Policy text (English — এটাই Play-তে দেবে)

```markdown
# Privacy Policy — Goodbye Apps

Last updated: [DATE]

Goodbye Apps ("the app", "we") is an Android utility that helps you review and
uninstall applications installed on your device. This policy explains what the
app does with information and what it does not do.

## Summary

- We do not require an account.
- We do not collect, transmit, sell or share your personal data.
- The list of apps on your device stays on your device.
- There are no analytics, advertising or tracking SDKs in this version.

## Information the app accesses

To do its job, the app reads the following on your device:

- **Installed application list** — app names, package names, icons, APK size and
  install/update dates. This is displayed to you and is never uploaded.
- **Device memory information** — available and total RAM, shown in the app's
  bottom bar. It is not stored or transmitted.
- **App preferences** — your theme choice is stored locally using Android's
  app-private storage. It never leaves your device.

The app does not access your contacts, photos, files, location, microphone,
camera, messages, call logs or accounts.

## Permissions and why they are needed

- **QUERY_ALL_PACKAGES** — to show the complete list of installed apps, which is
  the app's core function.
- **REQUEST_DELETE_PACKAGES** — to open Android's system uninstall dialog when
  you ask to remove an app.
- **POST_NOTIFICATIONS** (optional) — only if you enable the optional status bar
  notification.
- **RECEIVE_BOOT_COMPLETED** (optional) — only to restore that notification after
  a restart, if you enabled it.

Android shows its own confirmation dialog for every uninstall. The app cannot
remove anything silently.

## Data sharing

We do not share data with third parties. The app does not include advertising,
analytics, crash-reporting or attribution SDKs.

Some screens open external services at your request:

- Google Play Store (app details / rating)
- Your email app (feedback)
- Your system share sheet (sharing the app)

Those services have their own privacy policies.

## Children

The app is a general utility and is not directed to children under 13.

## Data retention

The app keeps no server-side data. Locally stored settings remain until you clear
the app's data or uninstall it.

## Security

Because no data is transmitted, there is no server-side store to breach. Local
settings use Android's app-private storage.

## Changes

If a future version adds advertising, analytics or any feature that changes how
data is handled, this policy will be updated before that version is released,
and the "Last updated" date will change.

## Contact

Keshab Studios
Email: hello@goodbyeapps.com
```

> Ads যোগ করলে উপরের "no analytics / no ads" অংশ **অবশ্যই** বদলাতে হবে, আর Play-এর Data
> safety form-ও update করতে হবে।

---

## 3. বাংলা version (ঐচ্ছিক, BD-র user-এর জন্য ভালো)

```markdown
# প্রাইভেসি পলিসি — Goodbye Apps

সর্বশেষ আপডেট: [তারিখ]

Goodbye Apps একটি Android utility, যা আপনার ফোনে ইনস্টল করা অ্যাপ দেখতে ও
আনইনস্টল করতে সাহায্য করে।

## সংক্ষেপে

- কোনো অ্যাকাউন্ট লাগে না।
- আমরা আপনার কোনো ব্যক্তিগত তথ্য সংগ্রহ, সংরক্ষণ বা শেয়ার করি না।
- আপনার ফোনের অ্যাপ লিস্ট ফোনের বাইরে যায় না।
- এই version-এ কোনো analytics, ads বা tracking নেই।

## অ্যাপ যা পড়ে

- ইনস্টল করা অ্যাপের নাম, প্যাকেজ নাম, আইকন, APK সাইজ, ইনস্টল তারিখ — শুধু
  আপনার কাছে দেখানোর জন্য, কোথাও পাঠানো হয় না।
- RAM তথ্য — শুধু নিচের bar-এ দেখানোর জন্য।
- থিম পছন্দ — শুধু আপনার ফোনে সংরক্ষিত থাকে।

## অনুমতি কেন লাগে

- **QUERY_ALL_PACKAGES** — সব অ্যাপের লিস্ট দেখাতে।
- **REQUEST_DELETE_PACKAGES** — Android-এর আনইনস্টল ডায়ালগ খুলতে।
- **POST_NOTIFICATIONS** — শুধু status bar notification চালু করলে।
- **RECEIVE_BOOT_COMPLETED** — শুধু ওই notification restart-এর পরে ফিরিয়ে আনতে।

প্রতিটা আনইনস্টলে Android নিজে অনুমতি চায়; অ্যাপ নিজে থেকে কিছু মুছে ফেলতে পারে না।

## যোগাযোগ

Keshab Studios — hello@goodbyeapps.com
```

---

## 4. Hosting check

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://goodbyeapps.com/privacy-policy
# 200 হওয়া লাগবে
```

- [ ] URL HTTPS
- [ ] Login ছাড়া খোলে
- [ ] Mobile-এ পড়া যায়
- [ ] Contact email কাজ করে
- [ ] "Last updated" আছে
- [ ] `privacyPolicyUrl` constant update করা হয়েছে
