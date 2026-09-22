# CleanSera Cleaner App

Flutter mobile app for cleaners working a job assigned by a business on
**CleanSera**. A cleaner is invited, onboarded, and (if needed) offboarded
by the business that employs them — this app is the worker-facing side of
that relationship, not a standalone marketplace app.

Backend: [cleansera_sass](https://github.com/olumuyiwaa/cleansera_sass)

---

## Table of contents

- [Features](#features)
- [Tech stack](#tech-stack)
- [Repository structure](#repository-structure)
- [Local setup](#local-setup)
- [Configuration](#configuration)
- [Offline behavior](#offline-behavior)
- [Related repositories](#related-repositories)

---

## Features

| Area | What's there |
|---|---|
| **Auth** | Login, session refresh, secure token storage |
| **Jobs** | Assigned job list, job detail, on-my-way / check-in / start / complete, photo upload |
| **Checklists** | Per-job checklist, mark items complete |
| **Messaging** | Conversations with the business/dispatcher |
| **Earnings** | Earnings view, Stripe Connect onboarding/status (payouts) |
| **Profile** | Own profile, availability, document uploads (ID, background check, certifications, contract, insurance) |
| **Push notifications** | Firebase Cloud Messaging, registered per-device against the business the cleaner is working for |
| **Offline queue** | Actions taken with no connectivity are queued and replayed once back online (`lib/providers/offline_queue_provider.dart`) |

A cleaner's affiliation with a business is modeled explicitly
(`lib/models/business_affiliation.dart`). A cleaner working for more than
one business can switch which one is active from the Profile tab or the
app bar (`lib/widgets/business_switcher_sheet.dart`) — no re-login or
password needed, since it reuses `POST /auth/select-business` on the
still-valid access token. Switching does not currently warn or block if a
job is clocked in on the business being left.

## Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Dart ≥3.4) |
| State | flutter_riverpod + riverpod_generator |
| Routing | go_router |
| HTTP | dio |
| Codegen | freezed, json_serializable |
| Secure storage | flutter_secure_storage, shared_preferences |
| Push | firebase_core, firebase_messaging, flutter_local_notifications |
| Location | geolocator, permission_handler |
| Media | image_picker, cached_network_image, flutter_svg |
| Misc | connectivity_plus, package_info_plus, uuid, timeago, equatable |

## Repository structure

```
cleansera_cleaner_app/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   ├── api_constants.dart    # Backend endpoint paths, base URL
│   │   │   └── app_constants.dart
│   │   ├── network/
│   │   │   └── dio_client.dart
│   │   ├── router/
│   │   │   └── app_router.dart       # /login, /home, jobs, jobs/:id, messages, profile, availability, documents, earnings
│   │   ├── services/
│   │   │   └── push_service.dart
│   │   └── theme/
│   ├── features/
│   │   ├── auth/          # data/ presentation/
│   │   ├── jobs/          # data/ presentation/
│   │   ├── checklist/
│   │   ├── messaging/     # data/ presentation/
│   │   ├── earnings/      # data/ presentation/
│   │   ├── profile/       # data/ presentation/
│   │   └── home/
│   ├── models/
│   │   └── business_affiliation.dart
│   ├── providers/
│   │   └── offline_queue_provider.dart
│   └── widgets/
└── pubspec.yaml
```

## Local setup

```bash
git clone https://github.com/olumuyiwaa/cleansera_cleaner_app.git
cd cleansera_cleaner_app
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

Point `API_BASE_URL` at a running `cleansera_sass` instance — on a physical
device or emulator, `localhost` won't reach your dev machine; use your
machine's LAN IP or `10.0.2.2` for the Android emulator.

Firebase push notifications need platform config files
(`google-services.json` for Android, `GoogleService-Info.plist` for iOS)
from your own Firebase project — not included in the repo.

## Configuration

`lib/core/constants/api_constants.dart` is the single source of truth for
every backend path this app calls. Two entries carry inline notes because
a previous version pointed at paths the backend doesn't expose — worth
knowing if a build ever mysteriously stops loading device-token
registration or messaging threads:

- Device token registration: `POST /cleaners/me/device-token` (not
  `/notifications/fcm-token`)
- Messaging: `/messaging` (not `/conversations`)

If the backend's route mounts in `src/routes/index.js` ever change, this
file is the one place to check and update.

## Offline behavior

`connectivity_plus` detects connection state; actions taken while offline
go through `offline_queue_provider.dart` and are replayed once
connectivity returns, rather than failing silently or blocking the UI.

## Related repositories

| Repo | Role |
|---|---|
| [cleansera_sass](https://github.com/olumuyiwaa/cleansera_sass) | Backend API |
| [cleansera_sass_frontend](https://github.com/olumuyiwaa/cleansera_sass_frontend) | Business dashboard, storefront, customer portal |
| [cleansera_sass_website](https://github.com/olumuyiwaa/cleansera_sass_website) | Marketing site |

## License

Private — all rights reserved.
