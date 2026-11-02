# 02 — Release signing ও `.aab` build

**Priority:** blocker (signed না হলে Play-তে upload হবে না)
**Effort:** ১ ঘণ্টা

---

## 1. Upload keystore বানাও (একবারই)

```bash
mkdir -p ~/keystores
keytool -genkeypair -v \
  -keystore ~/keystores/goodbyeapps-upload.jks \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias upload
```

Prompt-এ যা চাইবে:

| Field | Value |
|---|---|
| Password | শক্ত password (password manager-এ রাখো) |
| CN | Keshab Sarkar |
| OU | Keshab Studios |
| O | Keshab Studios |
| L | Dhaka |
| ST | Dhaka |
| C | BD |

> ⚠️ **এই file আর password হারালে app update করতে পারবে না।** দুই জায়গায় backup রাখো
> (একটা offline)। Play App Signing চালু করলে upload key রিসেট করা যায়, তাই অবশ্যই
> Play App Signing **opt in** করবে।

---

## 2. `android/key.properties`

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/Users/keshabsarkar/keystores/goodbyeapps-upload.jks
```

`android/.gitignore`-এ `key.properties` আর `*.jks` আগেই ignore করা আছে — commit হবে না।
`git status` দিয়ে একবার confirm করে নাও।

---

## 3. `android/app/build.gradle.kts` update

File-এর একদম উপরে import + load:

```kotlin
import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

`android { }` block-এর ভিতরে `buildTypes`-এর আগে:

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String?
        keyPassword = keystoreProperties["keyPassword"] as String?
        storeFile = keystoreProperties["storeFile"]?.let { file(it) }
        storePassword = keystoreProperties["storePassword"] as String?
    }
}
```

তারপর `buildTypes`-এ debug signing সরিয়ে:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro",
        )
    }
}
```

`android/app/proguard-rules.pro` (নতুন file):

```proguard
# Flutter engine
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# MethodChannel bridge uses no reflection, but keep the activity entry point.
-keep class com.keshabstudios.goodbyeapps.MainActivity { *; }
```

**Minify চালু করার পরে অবশ্যই আসল ফোনে test করো** — release build-এ channel method নাম
strip হলে app crash করবে (এখানে নাম string literal, তাই সাধারণত safe)।

---

## 4. Versioning

`pubspec.yaml`:

```yaml
version: 1.0.0+1
#        │     └── versionCode (Play-তে প্রতি upload-এ বাড়াতে হবে)
#        └──────── versionName (user যে version দেখে)
```

Rules:
- প্রতিটা Play upload-এ `+N` বাড়াও (2, 3, 4 …)। একই code দুইবার upload হবে না।
- User-facing change না থাকলেও code বাড়াতে হবে।
- Flutter split APK ব্যবহার করলে ABI অনুযায়ী code নিজে থেকে বাড়ায়; `.aab`-তে এটা সমস্যা না।

---

## 5. Build

```bash
cd ~/Projects/app_remover
flutter clean
flutter pub get
flutter analyze
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Side-load test-এর জন্য:

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 6. Signature verify

```bash
# aab-এর signature
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab | tail -5

# apk-এর signature + certificate
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

`apksigner` এখানে: `~/Library/Android/sdk/build-tools/36.0.0/apksigner`

Expected: `Verifies` + তোমার DN (`CN=Keshab Sarkar, O=Keshab Studios, C=BD`)।

---

## 7. Local bundle test (Play-এ দেওয়ার আগে)

```bash
brew install bundletool          # একবার
bundletool build-apks \
  --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=/tmp/goodbye.apks \
  --ks=~/keystores/goodbyeapps-upload.jks \
  --ks-key-alias=upload

bundletool install-apks --apks=/tmp/goodbye.apks
```

এতে বুঝবে Play-এর split-install-এ app ঠিকঠাক চলে (missing resource / ABI issue নেই)।

---

## 8. Acceptance criteria

- [ ] `key.properties` GitHub-এ যায়নি (`git log -p -- android/key.properties` খালি)
- [ ] Keystore-এর ২টা backup আছে
- [ ] `flutter build appbundle --release` সফল
- [ ] `apksigner verify` / `jarsigner -verify` পাস
- [ ] Release APK আসল ফোনে install + app list load + uninstall কাজ করে
- [ ] Minify চালু থাকার পরেও কোনো crash নেই
- [ ] `versionCode` আগের upload-এর চেয়ে বড়

## 9. যেসব file touch হবে

```text
android/key.properties            (নতুন, git-ignored)
android/app/build.gradle.kts      (signingConfigs + release buildType)
android/app/proguard-rules.pro    (নতুন)
pubspec.yaml                      (version bump)
```
