# iOS → TestFlight on push (GitHub Actions + fastlane)

Push to `main` (or a `v1.0.2` tag) → builds, signs, uploads to **TestFlight**.
You submit for App Store review **manually** in App Store Connect.

Signing: the **distribution certificate** is imported from a secret (`.p12`),
and the **App Store provisioning profile** is created/fetched automatically with
the API key. Version from `pubspec.yaml`/tag, build number from git commit count.

## Secrets (GitHub → Settings → Secrets and variables → Actions)

### App Store Connect API key — role **Admin** or **App Manager**
App Store Connect → Users and Access → Integrations → App Store Connect API → (+).
| Secret | Value |
|---|---|
| `ASC_KEY_ID` | the Key ID |
| `ASC_ISSUER_ID` | the Issuer ID |
| `ASC_KEY_P8` | `base64 -i AuthKey_XXXX.p8 \| pbcopy` |

### Distribution certificate (the part CI can't self-provision)
On your Mac, create an **Apple Distribution** cert for team `MR6847N3F7` (Xcode →
Settings → Accounts → that team → Manage Certificates → **+** → Apple
Distribution), then Keychain Access → **My Certificates** → right-click it →
**Export** → `.p12` (set a password).
| Secret | Value |
|---|---|
| `IOS_DIST_CERT_P12` | `base64 -i dist.p12 \| pbcopy` |
| `IOS_DIST_CERT_PASSWORD` | the `.p12` password |

> Why the cert can't be automatic: a fresh CI runner has no private key, and
> automatic signing would mint a new distribution cert every run (Apple caps how
> many you can have). Importing one `.p12` you own is stable and reusable.

## Recommended one-time addition
`ios/Runner/Info.plist` (set `false` for HTTPS-only encryption):
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

## Release
```bash
git add -A && git commit -m "…" && git push origin main   # → TestFlight build
# or an explicit version:
git tag v1.0.2 && git push origin v1.0.2
```
Then App Store Connect → App Store tab → set "What's New" → pick the build →
**Add for Review → Submit**.
