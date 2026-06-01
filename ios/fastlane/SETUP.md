# iOS → TestFlight on push (GitHub Actions + fastlane)

Every push to `main` builds, signs, and uploads a new build to **TestFlight**
(version from `pubspec.yaml`, build number from the git commit count). You then
**submit for App Store review manually** in App Store Connect when you're ready.

You can also push a tag (`git tag v1.0.2 && git push origin v1.0.2`) to stamp an
explicit marketing version, or run it from the Actions tab (Run workflow).

## One-time setup — GitHub secrets

Repo → **Settings → Secrets and variables → Actions → New repository secret**.

### App Store Connect API key
App Store Connect → **Users and Access → Integrations → App Store Connect API** →
create a key with the **App Manager** role, download the `.p8` (only offered once).

| Secret | Value |
|---|---|
| `ASC_KEY_ID` | the key's Key ID |
| `ASC_ISSUER_ID` | the Issuer ID (top of that page) |
| `ASC_KEY_P8` | base64 of the `.p8`: `base64 -i AuthKey_XXXX.p8 \| pbcopy` |

### Signing (reuse the cert/profile you already distribute with)
- Export your **Apple Distribution** certificate from Keychain Access as a `.p12` (give it a password).
- Download the **App Store** provisioning profile for `app.cupet.cupetApp` (Apple Developer portal → Profiles, or Xcode).

| Secret | Value |
|---|---|
| `IOS_DIST_CERT_P12` | `base64 -i dist.p12 \| pbcopy` |
| `IOS_DIST_CERT_PASSWORD` | the password you set on the `.p12` |
| `IOS_PROVISIONING_PROFILE` | `base64 -i profile.mobileprovision \| pbcopy` |
| `IOS_PROFILE_NAME` | the profile's **Name** as shown in the portal (e.g. `CuPet App Store`) |

## Recommended one-time addition (avoids a manual prompt on every build)
Add to `ios/Runner/Info.plist` (set `false` if the app uses only standard
encryption such as HTTPS — the usual case):
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```
Otherwise each TestFlight build sits at "Missing Compliance" until you answer the
export-compliance question by hand.

## Submitting for App Store review (manual, in App Store Connect)
1. App Store Connect → your app → **TestFlight** → confirm the new build finished processing.
2. **App Store** tab → create/select the version → set **What's New**, screenshots, etc.
3. Under **Build**, pick the TestFlight build → **Add for Review** → **Submit**.

## Notes
- Build number = `git rev-list --count HEAD`; it climbs with every commit, so
  TestFlight always accepts the new build under the same version.
- Bump the marketing version by editing `version:` in `pubspec.yaml` (or pushing
  a `vX.Y.Z` tag) when you start a new App Store version.
- The lane sets `uploadSymbols: false` (no Crashlytics) — that's why the
  "Upload Symbols Failed" dSYM warnings won't appear from this pipeline.
