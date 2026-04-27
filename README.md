# CuPet — Flutter app

Pet dating app, built with Flutter + `flutter_bloc` (clean architecture, feature-first).
Pairs with the `cupet_backend` Laravel/Filament project in the sibling directory.

## Stack

- Flutter 3 + `flutter_bloc` for state management
- `go_router` navigation, `get_it` DI
- `dio` HTTP client with Sanctum bearer interceptor
- `firebase_auth` (phone OTP) + `firebase_messaging` (FCM push)
- `pusher_channels_flutter` connected to Laravel Reverb websockets
- `appinio_swiper`, `cached_network_image`, `image_picker`, `geolocator`, `google_fonts`

## Project layout

```
lib/
├── main.dart              # bootstraps Firebase, DI, FCM, runs the app
├── app/                   # MaterialApp, theme, router
├── core/                  # network, realtime, storage, DI, errors, messaging
├── features/
│   ├── auth/              # Firebase phone OTP → Sanctum token
│   ├── profile/           # owned pets CRUD (photos, vaccinations, location)
│   ├── discover/          # appinio_swiper deck + DiscoverBloc
│   ├── matches/           # matches list + MatchesBloc
│   ├── chat/              # 1:1 chat, ChatBloc subscribes to Reverb
│   └── reports/           # report-pet bottom sheet
└── shared/                # models + reusable widgets (EmptyState w/ mascot)
```

## Branding

Yellow-led palette (`#FFD23F`), charcoal ink, off-white surface. Headings use the
`Barrio` Google Font; body uses `Manrope` as a free fallback for the proprietary
"Obviously" font referenced in the brief. Empty states reserve a circular slot for
the "Germeen" mascot — drop the artwork into `assets/images/germeen.png` and swap
the emoji placeholder in `lib/shared/widgets/empty_state.dart`.

## Configuration

Compile-time configuration via `--dart-define`:

| Key | Default | Description |
| --- | --- | --- |
| `API_BASE_URL` | `http://10.0.2.2:8000/api/v1` | Laravel API base URL (Android emulator default) |
| `REVERB_APP_KEY` | `cupet-key` | Must match `REVERB_APP_KEY` in the backend `.env` |
| `REVERB_HOST` | `10.0.2.2` | Laravel Reverb host |
| `REVERB_PORT` | `8080` | Laravel Reverb port |
| `REVERB_SCHEME` | `http` | `http` or `https` |
| `BROADCASTING_AUTH_URL` | `http://10.0.2.2:8000/broadcasting/auth` | Sanctum-auth endpoint Reverb calls for private channels |

Firebase: drop `google-services.json` (Android) / `GoogleService-Info.plist` (iOS)
into the platform folders, then run `flutterfire configure` to generate
`lib/firebase_options.dart`.

## Run

```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 \
  --dart-define=REVERB_APP_KEY=cupet-key \
  --dart-define=REVERB_HOST=10.0.2.2 \
  --dart-define=REVERB_PORT=8080 \
  --dart-define=REVERB_SCHEME=http \
  --dart-define=BROADCASTING_AUTH_URL=http://10.0.2.2:8000/broadcasting/auth
```

iOS simulator: replace `10.0.2.2` with `127.0.0.1`.
Physical device: use your machine's LAN IP for both `API_BASE_URL` and
`REVERB_HOST`.

## Realtime + push

- Private channels: `user.{id}` (new match) and `conversation.{id}` (new message),
  authorized via `/broadcasting/auth` using the Sanctum token.
- FCM token registration is handled in `core/messaging/fcm_service.dart` and
  posted to `POST /devices` after sign-in.

## Testing

```bash
flutter analyze
flutter test
```
