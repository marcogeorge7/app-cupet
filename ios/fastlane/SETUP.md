# iOS → TestFlight on push (GitHub Actions + fastlane)

Every push to `main` builds, signs, and uploads a new build to **TestFlight**
(version from `pubspec.yaml`, build number from the git commit count). You then
**submit for App Store review manually** in App Store Connect when ready.

Signing is **automatic**: xcodebuild creates/fetches the distribution
certificate + App Store provisioning profile for team `MR6847N3F7` using the
App Store Connect API key (`-allowProvisioningUpdates`). No certs/profiles to
manage.

## One-time setup — 3 GitHub secrets

App Store Connect → **Users and Access → Integrations → App Store Connect API** →
create a key with the **Admin** role (Admin is needed so it can create the
signing certificate the first time), download the `.p8` (offered only once), and
note its **Key ID** and **Issuer ID**.

Repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|---|---|
| `ASC_KEY_ID` | the key's Key ID |
| `ASC_ISSUER_ID` | the Issuer ID (top of that page) |
| `ASC_KEY_P8` | base64 of the `.p8`: `base64 -i AuthKey_XXXX.p8 \| pbcopy` |

That's it — no cert/profile secrets needed with automatic signing.

> The Apple ID behind the API key must be on the **MR6847N3F7** team (the one
> that owns `app.cupet.cupetApp`).

## Recommended one-time addition
Add to `ios/Runner/Info.plist` (set `false` for standard HTTPS-only encryption):
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```
Otherwise each TestFlight build stalls at "Missing Compliance" until answered by hand.

## Release
```bash
git add -A
git commit -m "…"
git push origin main      # → builds + uploads to TestFlight
```
Then in App Store Connect → **App Store** tab → set "What's New" → pick the build
→ **Add for Review → Submit**.
