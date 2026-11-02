# Play Console — App content উত্তর (copy-paste ready)

`docs/03-play-console.md`-এর checklist এই file-এর উত্তরগুলো দিয়ে পূরণ করো।
Store listing-এর ভাষাভিত্তিক text আলাদা: `distribution/listing/<lang>/`।

## Store listing

| Field | File | Characters |
|---|---|---|
| App name | `listing/en-US/app-name.txt` | 26 / 30 |
| Short description | `listing/en-US/short-description.txt` | 76 / 80 |
| Full description | `listing/en-US/full-description.txt` | 1779 / 4000 |
| Bengali translation | `listing/bn-BD/…` | name brand-এ English-ই থাকে (doc 10 §7) |

> v1.0 release-এর পর যা যা যোগ হয়েছে (detailed sizes, status bar
> notification, home screen shortcut, Bangla) — description-এ সেগুলো
> ঢুকানো হয়েছে, claim/checklist-doc-এর বাইরে কিছু নেই।

## Declarations

| Section | Answer |
|---|---|
| Ads | No |
| In-app purchases | No (doc 11 এলে বদলাবে) |
| Content rating | Utility → Everyone |
| Target audience | 18+ রাখো — Families policy এড়ানোর জন্য সবচেয়ে সহজ পথ |
| News / COVID / Government / Financial / Photo-video | No |
| App access | All functionality available without login |

## Data safety

- Data collected: **None**
- Data shared: **None**
- Data processed ephemerally: **None**
- Security practices: "Data is not transmitted" ✅; no account creation

কারণ: কোনো network call নেই; theme + toggle `shared_preferences`-এ device-এ
থাকে। Play usage stats SDK ও নেই — কিছু একটা যোগ করলে এই form আগে বদলাও।

## Sensitive permission: Installed apps (QUERY_ALL_PACKAGES)

```text
Goodbye Apps is an app-management utility whose core, user-visible function is
to list the applications installed on the device so the user can inspect them
and uninstall them.

The QUERY_ALL_PACKAGES permission is required to display a complete, accurate
list of installed apps with their icons, package names, sizes and install
dates. Without it, Android 11+ returns only a partial list and the app's core
purpose cannot be fulfilled. The app does not collect, transmit or share the
installed app list; all processing happens on the device.

This falls under the permitted use case "device and app management" for
QUERY_ALL_PACKAGES.
```

দরকার হলে ৩০ সেকেন্ডের screen recording: app list → select → system
uninstall dialog।

## Release notes

`whatsnew/whatsnew-en-US` + `whatsnew/whatsnew-bn-BD` — Play track-এর "Release
notes" ফield-এ ওই two files-এর text। প্রথম production release হলে doc 03 §6-এর
"First release." bullets ব্যবহার করো।

## Upload-এর আগে (doc 03 §7 থেকে যা agent দেখতে পারে না)

- [ ] Privacy policy URL live (200 OK, HTTPS, login ছাড়া খোলে)
- [ ] `privacyPolicyUrl` constant সেই URL-এ আপডেট করা হয়েছে
- [ ] Support email-এ আসলে mail যায়
- [ ] Icon 512×512 + feature graphic 1024×500 + ২টা আসল screenshot
- [ ] `versionCode` আগের থেকে বেশি
- [ ] Data safety-র উত্তর code-এর সঙ্গে মেলে (ads/analytics নেই)
