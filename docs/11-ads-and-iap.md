# 11 — Ads + "Remove Ads" (monetization)

**Priority:** v1.2 —user base হওয়ার পরে
**Effort:** ১ দিন + review

> ⚠️ Ads যোগ করলে **privacy policy, Data safety form, listing-এর "Ads" answer** —
> তিনটাই বদলাতে হবে। আগে না বদলে দিলে policy strike।

---

## 1. Model

Original app-এর মতো:

- Free version: banner + মাঝে মাঝে interstitial
- One-time IAP **"Remove Ads"** (subscription নয়)
- Ads থাকলেও app-এর core কাজ কখনো block হবে না

---

## 2. AdMob setup

1. https://admob.google.com → Add app → Android → `com.keshabstudios.goodbyeapps`
2. Ad units বানাও:
   - `banner` — list-এর নিচে
   - `interstitial` — ৩–৫টা uninstall-এর পরে একবার (max)
   - `native` (optional) — list-এর মধ্যে প্রতি ৮–১০ row-তে
3. `app-ads.txt` নিজের domain-এ host করো (AdMob বলে দেবে কী লিখতে হবে)।

### `android/app/src/main/AndroidManifest.xml`

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY" />
```

### `pubspec.yaml`

```bash
flutter pub add google_mobile_ads in_app_purchase
```

### `lib/main.dart`

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.load();
  await MobileAds.instance.initialize();
  runApp(const AppRemoverApp());
}
```

**Test করার সময় শুধু Google-এর test id ব্যবহার করো** — নিজের ad unit-এ নিজে click করলে
account ban হয়।

```dart
const testBannerId = 'ca-app-pub-3940256099942544/6300978111';
const testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
```

---

## 3. Consent (EU/EEA-র জন্য বাধ্যতামূলক)

`google_mobile_ads`-এর সাথে UMP SDK আসে:

```dart
final params = ConsentRequestParameters();
ConsentInformation.instance.requestConsentInfoUpdate(
  params,
  () async {
    if (await ConsentInformation.instance.isConsentFormAvailable()) {
      ConsentForm.loadAndShowConsentFormIfRequired((formError) {
        // এর পরে ads load করা যাবে
      });
    }
  },
  (formError) {},
);
```

AdMob console → **Privacy & messaging** → GDPR message + US states message তৈরি করো।

Settings-এ **"Privacy options"** row রাখো (original-এ ছিল) — এটা consent form আবার খোলে:

```dart
if (await ConsentInformation.instance.isConsentFormAvailable()) {
  ConsentForm.showPrivacyOptionsForm((_) {});
}
```

---

## 4. Banner (list-এর নিচে)

```dart
class BannerAdBar extends StatefulWidget { ... }

// state
BannerAd? _ad;
bool _loaded = false;

@override
void initState() {
  super.initState();
  _ad = BannerAd(
    adUnitId: kReleaseMode ? realBannerId : testBannerId,
    size: AdSize.banner,
    request: const AdRequest(),
    listener: BannerAdListener(
      onAdLoaded: (_) => setState(() => _loaded = true),
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        _ad = null;
      },
    ),
  )..load();
}

@override
void dispose() {
  _ad?.dispose();
  super.dispose();
}
```

`HomeScreen`-এর `bottomNavigationBar`-এর উপরে বসাও, height 50dp।

---

## 5. Interstitial (সতর্কভাবে)

```dart
int _uninstallCount = 0;

Future<void> _maybeShowInterstitial() async {
  if (AppSettings.adsRemoved.value) return;
  _uninstallCount++;
  if (_uninstallCount % 4 != 0) return;   // প্রতি ৪টায় একবার

  await InterstitialAd.load(
    adUnitId: kReleaseMode ? realInterstitialId : testInterstitialId,
    request: const AdRequest(),
    adLoadCallback: InterstitialAdLoadCallback(
      onAdLoaded: (ad) {
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) => ad.dispose(),
          onAdFailedToShowFullScreenContent: (ad, _) => ad.dispose(),
        );
        ad.show();
      },
      onAdFailedToLoad: (_) {},
    ),
  );
}
```

কখনোই uninstall confirm dialog-এর **আগে** দেখাবে না — user flow ভেঙে যায়, uninstall
rate কমে।

---

## 6. "Remove Ads" IAP

Play Console → Monetize → Products → **In-app products** → Create:

| Field | Value |
|---|---|
| Product ID | `remove_ads` |
| Name | Remove Ads |
| Description | One payment. No ads, forever. |
| Price | নিজের মতো ($1.99–$2.99) |
| Status | Active |

### Code

```dart
import 'package:in_app_purchase/in_app_purchase.dart';

class Billing {
  static const productId = 'remove_ads';
  static final adsRemoved = ValueNotifier<bool>(false);

  static Future<void> init() async {
    if (!await InAppPurchase.instance.isAvailable()) return;
    final response = await InAppPurchase.instance
        .queryProductDetails({productId});
    // product details UI-তে দেখাও

    InAppPurchase.instance.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.productID != productId) continue;
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          await _grant();
          await InAppPurchase.instance.completePurchase(purchase);
        }
        if (purchase.status == PurchaseStatus.error) {
          // error handling
        }
      }
    });

    await InAppPurchase.instance.restorePurchases(); // reinstall-এ ফিরিয়ে আনে
  }

  static Future<void> _grant() async {
    adsRemoved.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ads_removed', true);
  }

  static Future<void> buy() async {
    final details = await InAppPurchase.instance
        .queryProductDetails({productId});
    if (details.productDetails.isEmpty) return;
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: details.productDetails.first,
      ),
    );
  }
}
```

### UI

`lib/main.dart` বা `HomeScreen`-এ:

```dart
ValueListenableBuilder<bool>(
  valueListenable: Billing.adsRemoved,
  builder: (context, removed, _) => removed
      ? const SizedBox.shrink()
      : BannerAdBar(),
),
```

Settings-এ "Remove Ads" row → paywall sheet (4টা benefit + price + "One payment,
no subscription") — original-এর `ra_*` string-গুলো ছিল:

- "We Remove Apps. You Remove Ads."
- "No Ads — A cleaner that is clean itself"
- "Faster Cleanup — Uninstall without breaks"
- "Support Indie Developers — You keep this app alive"

---

## 7. Policy checklist (ads যোগ করার দিন)

- [ ] Play Console → App content → **Ads: Yes**
- [ ] Data safety: *Device or other IDs* collected? → AdMob ব্যবহার করলে **Yes**
      (advertising ID), purpose: advertising, shared with third parties: Yes
- [ ] Privacy policy update: AdMob, advertising ID, consent, opt-out
- [ ] UMP consent form live (EEA + US states)
- [ ] `app-ads.txt` live
- [ ] Children policy: target audience 18+ রাখো, অথবা Families policy মানো
- [ ] Interstitial uninstall flow-এর মাঝখানে নয়
- [ ] Test ads দিয়ে সব flow verify

---

## 8. Acceptance

- [ ] Free user: banner দেখা যায়, ৪ uninstall-এ একবার interstitial
- [ ] "Remove Ads" কিনলে সাথে সাথে সব ad বন্ধ
- [ ] App reinstall করলে restore purchases কাজ করে
- [ ] Purchase cancel করলে entitlement হয় না
- [ ] Airplane mode-এ ad fail করলে layout ভাঙে না
- [ ] Consent form প্রথম launch-এ আসে (EEA locale-এ test)
- [ ] Data safety + privacy policy update করা

## 9. Files

```text
android/app/src/main/AndroidManifest.xml   (AdMob app id)
pubspec.yaml                               (google_mobile_ads, in_app_purchase)
lib/main.dart                              (MobileAds init, Billing init)
lib/ads/banner_ad_bar.dart                 (নতুন)
lib/ads/interstitial.dart                  (নতুন)
lib/billing/billing.dart                   (নতুন)
lib/screens/settings_screen.dart           (Remove Ads + Privacy options)
docs/04-privacy-policy.md                  (আপডেট করতে হবে)
```
