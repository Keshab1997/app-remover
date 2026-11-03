# Play Store release readiness — Goodbye Apps

This is a working checklist, not a claim of Play approval. Confirm the current
requirements in Play Console before submission.

## Before submission

- [ ] Host and review the privacy policy in `docs/legal/` at a real, public URL;
  replace the placeholder URL in `lib/screens/settings_screen.dart`. Verify the
  support email there belongs to the developer and works. Do not submit the
  placeholder `goodbyeapps.com` details without verification.
- [ ] Review Data safety and permission declarations against the actual app and
  all dependencies. Installed-app inventory is sensitive: justify
  `QUERY_ALL_PACKAGES` as core app management and supply the demonstration Play
  requests. Approval is not guaranteed. Review `REQUEST_DELETE_PACKAGES` too.
- [ ] Verify release signing and Play App Signing with the owner. The Gradle
  configuration falls back to debug signing when `key.properties` is absent;
  do not upload such a build. Keep the upload key and passwords out of Git.
- [ ] Verify version code, application ID, target API and all current Play
  Console requirements. Check testing requirements for this developer account.
- [ ] Review the existing English and Bangla listing drafts under
  `distribution/listing/`, choose a working support address, and prepare/verify
  the required icon, feature graphic and accurate device screenshots. Do not
  publish listing changes without the owner's approval.
- [ ] Complete Play Console app-content forms (including privacy, Data safety,
  content rating, ads and target audience) truthfully; existing drafts are not
  substitutes for reviewing the final build.
- [ ] Test an actual signed release on Android devices: first launch and repeat
  launch, onboarding skip and completion, search, individual and batch uninstall
  with cancellation, optional usage access and notifications, and dark/Bangla
  layouts. Test upgrades from any previous version too.
- [ ] Run the manual `Flutter CI — Format, Analyze & Test` workflow once when
  the owner is ready. Publishing and Play upload require separate approval.

Existing guidance: `docs/02-signing-and-release.md`, `docs/03-play-console.md`,
`docs/04-privacy-policy.md` and `docs/05-testing-checklist.md`. Some details in
older documents may be outdated; verify rather than copying their form answers.
