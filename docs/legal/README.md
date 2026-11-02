# legal — প্রাইভেসি পলিসি (host করার-ready)

`docs/04-privacy-policy.md`-এর text এখান থেকেই host-যোগ্য ফাইলে বসানো হয়েছে।
দুটো ফাইল, দুটোই self-contained — কোনো CSS/font/image fetch করে না, তাই
যেখানেই রাখুন একসাথে চলবে (GitHub Pages, Netlify, নিজের domain, অথবা
email-অ্যাটাচমেন্ট হিসেবে Play review)।

```text
docs/legal/privacy-policy.html       English  (Play Console-এ যেটা দেবে)
docs/legal/privacy-policy-bn.html    বাংলা    (link দুটো পরস্পরের দিকে)
```

## Host করা (সবচেয়ে দ্রুত পথ)

1. Public repo `goodbyeapps-legal` বানাও (Settings → Pages → Deploy from a
   branch → `main`, root)।
2. এই দুটো `.html` + শুধু সেগুলোই — repo-র root-এ রাখো, `privacy.html` নাম
   দিলে URL ছোট থাকে।
3. যাচাই:

   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" https://keshab1997.github.io/goodbyeapps-legal/
   # 200 লাগবে
   ```

   `goodbyeapps.com` নিলে ঠিক same দুটো file ওই domain-এর root-এ দাও।

## Host করার পর এই দুই জায়গায় URL বসাও

| জায়গা | কী |
|---|---|
| `lib/screens/settings_screen.dart` | `privacyPolicyUrl` constant (এখন `https://goodbyeapps.com/privacy-policy`, `TODO` সহ) |
| Play Console → App content → Privacy policy | হুবহু সেই HTTPS URL |

URL বদলালে **দুটোই** বদলাতে হবে — নাহলে app-এর ভেতরের লিঙ্ক ৪০৪ দেবে,
Play review সেটাই ধরে।

## মনে রাখার বিষয়

- **Ads/analytics যোগ করলে** (doc 11) এই পলিসির "no ads / no analytics"
  অংশ + Play Data safety form — দুটোই আপডেট করতে হবে, তারিখসহ। নাহলে
  policy strike।
- Usage access (doc 08) আর status bar notification (doc 06) — দুটোর বর্ণনা
  ইতিমধ্যে এই পলিসিতে আছে, code যেভাবে বলে ঠিক সেভাবে।
- Contact email `hello@goodbyeapps.com` কাজ করা চাই; domain না নিলে
  Play-র support email-ও একই রাখো।
