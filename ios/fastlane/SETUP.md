# iOS auto-release (GitHub Actions + fastlane)

Pushing a version tag builds the app, uploads it to **TestFlight**, and submits
it for **App Store review** — version from the tag, build number from the git
commit count.

```bash
# cut a release:
git tag v1.0.2
git push origin v1.0.2
```

`workflow_dispatch` (Actions tab → "iOS Release" → Run workflow) also works and
lets you type the version.

## One-time setup

### 1. App Store Connect API key  (Users and Access → Integrations → App Store Connect API)
Create a key with the **App Manager** role, download the `.p8` (once!), and note
its **Key ID** and **Issuer ID**. Then add GitHub repo secrets
(Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `ASC_KEY_ID` | the key's Key ID |
| `ASC_ISSUER_ID` | the Issuer ID |
| `ASC_KEY_P8` | **base64** of the `.p8` file: `base64 -i AuthKey_XXXX.p8 \| pbcopy` |

### 2. Signing — distribution cert + App Store provisioning profile
From your Mac (you already have these, since you distribute manually today):
- Export your **Apple Distribution** certificate from Keychain as a `.p12` (set a password).
- Download the **App Store** provisioning profile for `app.cupet.cupetApp`
  (Apple Developer → Profiles, or Xcode), the `.mobileprovision` file.

| Secret | Value |
|---|---|
| `IOS_DIST_CERT_P12` | `base64 -i dist.p12 \| pbcopy` |
| `IOS_DIST_CERT_PASSWORD` | the password you set on the `.p12` |
| `IOS_PROVISIONING_PROFILE` | `base64 -i profile.mobileprovision \| pbcopy` |
| `IOS_PROFILE_NAME` | the profile's **Name** (as shown in the Developer portal, e.g. `CuPet App Store`) |

> Tip (lower maintenance): switch signing to **fastlane match** later so the
> certs live in a private git repo and rotate cleanly — but the secrets above
> work and reuse your existing cert/profile.

## Two things that block *unattended* App Store submission — set these once

1. **Export compliance.** Add to `ios/Runner/Info.plist` (true if your app uses
   only standard encryption like HTTPS, which is the usual case):
   ```xml
   <key>ITSAppUsesNonExemptEncryption</key>
   <false/>
   ```
   Without it, every build sticks at "Missing Compliance" and can't auto-submit.

2. **"What's New" / release notes.** App Store review of a *new* marketing
   version requires release notes. The lane uses `skip_metadata: true` (it does
   **not** push store text), so fill "What's New" for the version on App Store
   Connect, **or** switch the lane to managed metadata (`fastlane/metadata/`).

## Honest expectations
- **TestFlight upload is reliable.** The **App Store submit-for-review** step is
  the fragile one — the first run often needs the two items above sorted out, and
  ASC `precheck` may flag things (IDFA, encryption, missing notes).
- If you'd rather de-risk it, change the lane to stop after `upload_to_testflight`
  and submit for review by hand the first couple of times.
- Build number = `git rev-list --count HEAD`. Because each release bumps the
  **marketing version** (from the tag), the build number doesn't need to clear
  your previously-used `+6`. If you ever reuse a version, bump the build with an
  offset instead.
