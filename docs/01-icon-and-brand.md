# 01 — Icon, adaptive icon ও brand assets

**Priority:** blocker (Play listing-এ icon বাধ্যতামূলক)
**Effort:** ৩–৪ ঘণ্টা (design + export + build)

---

## 1. Brand

| Item | Value |
|---|---|
| App name | **Goodbye Apps – Uninstaller** |
| Package | `com.keshabstudios.goodbyeapps` |
| Domain (কিনতে হবে) | `goodbyeapps.com` |
| Support email | `hello@goodbyeapps.com` |
| Primary color | `#3D5AFE` (theme-এর seed, `lib/main.dart`) |
| Dark | `#1A237E` |
| Accent | `#00E5A0` |

### Icon concept

"বিদায়" বোঝায় এমন simple glyph — app tile একটা rounded square, সেটা হালকা tilt করা,
আর ডান দিকে একটা arrow বেরিয়ে যাচ্ছে। 2 রঙের মধ্যে রাখো, gradient নয় (Play-তে ছোট দেখায়
gradient ঘোলা লাগে)।

Rules:
- Background: solid `#3D5AFE`
- Foreground: white glyph
- কোনো text, letter, "G" নেই — 48px-এ পড়া যায় না
- অন্য app-এর icon-এর সাথে মিল নেই (Splend Apps-এর icon কপি করা যাবে না)

Design tool-এ যা যা লাগবে: `icon-source.svg` (1024×1024), `icon-foreground.svg` (432×432,
safe zone 264×264), `icon-mono.svg` (single color, transparent background)।

---

## 2. Android adaptive icon

Android-এ ৩টা layer লাগে: background, foreground, monochrome (Android 13+ themed icon)।

### File structure

```text
android/app/src/main/res/
  mipmap-anydpi-v26/ic_launcher.xml
  drawable/ic_launcher_foreground.xml      (vector) অথবা .png
  values/colors.xml                        (নতুন)
  mipmap-mdpi/ic_launcher.png              48×48
  mipmap-hdpi/ic_launcher.png              72×72
  mipmap-xhdpi/ic_launcher.png             96×96
  mipmap-xxhdpi/ic_launcher.png            144×144
  mipmap-xxxhdpi/ic_launcher.png           192×192
```

`mipmap-anydpi-v26/ic_launcher.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
```

`values/colors.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#3D5AFE</color>
</resources>
```

### সহজ রাস্তা — `flutter_launcher_icons`

Foreground safe zone-এ (মাঝের 66dp) রাখলে একবার PNG দিলেই সব density generate হয়।

```bash
flutter pub add --dev flutter_launcher_icons
```

`pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: "ic_launcher"
  image_path: "assets/branding/icon.png"                 # 1024×1024, background সহ
  adaptive_icon_background: "#3D5AFE"
  adaptive_icon_foreground: "assets/branding/icon_fg.png" # 1024×1024, transparent
  adaptive_icon_monochrome: "assets/branding/icon_mono.png"
  min_sdk_android: 21
```

```bash
dart run flutter_launcher_icons
```

**সতর্কতা:** `flutter_launcher_icons` `mipmap-anydpi-v26` overwrite করে — আগে `git status`
দেখে নাও, আর generate-এর পরে icon-টা আসল ফোনে (Android 13 themed icon সহ) চোখে দেখে নাও।

---

## 3. Play Store graphics

| Asset | Size | Format | Note |
|---|---|---|---|
| App icon | 512×512 | 32-bit PNG, alpha নেই | Play Console-এ আলাদা upload |
| Feature graphic | 1024×500 | JPEG/PNG, alpha নেই | listing-এর উপরে হিরো ব্যানার |
| Phone screenshots | min 2, max 8 | 1080×1920 বা 1080×2400 | জরুরি: list, selection mode, settings |
| Tablet screenshots | optional | 1600×2560 | tab support থাকলে দাও |

### Screenshot plan (এই order-এ দিলে conversion ভালো)

1. **App list** — "See every app and its size" caption
2. **Selection mode** — "Uninstall many apps at once"
3. **Sort sheet** — "Sort by size, date or name"
4. **Action sheet** — "Open, inspect or remove in one tap"
5. **Settings** — "Light, dark or system theme"

Screenshot নেওয়ার আগে: ডেমো ফোনে status bar পরিষ্কার করো, নাম-নম্বর blur করো,
আর একই device-এ consistent ভাষা রাখো।

---

## 4. Acceptance criteria

- [ ] Android 8 (API 26) থেকে Android 15 পর্যন্ত icon ঠিক দেখায়
- [ ] Android 13+ themed (monochrome) icon ঠিক দেখায়
- [ ] Icon 48dp-এ পড়া যায়, ভেতরে text নেই
- [ ] Play Console 512×512 icon reject করে না (alpha channel নেই)
- [ ] Feature graphic-এ 1024×500-এর বাইরে কিছু crop হয় না
- [ ] `flutter build appbundle` এর পরে `mipmap-anydpi-v26` APK-তে আছে

## 5. যেসব file touch হবে

```text
android/app/src/main/res/**            (generate করা icon)
android/app/src/main/res/values/colors.xml   (নতুন)
assets/branding/                        (নতুন, design source)
pubspec.yaml                            (flutter_launcher_icons dev dep)
```
