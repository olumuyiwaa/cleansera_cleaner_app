# CleanSera Cleaner App

Flutter mobile app for **cleaners** who work for businesses on the CleanSera platform.

Cleaners are **managed by their employer business** (onboard / offboard, assign jobs, set pay). They are not independent marketplace providers. A cleaner can be affiliated with more than one business; each affiliation is a separate profile on the backend.

Backend: [cleansera_sass](https://github.com/olumuyiwaa/cleansera_sass)  
Business dashboard: [cleansera_sass_frontend](https://github.com/olumuyiwaa/cleansera_sass_frontend)

---

## Table of contents

- [Purpose & model](#purpose--model)
- [Tech stack](#tech-stack)
- [Repository structure](#repository-structure)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Local setup](#local-setup)
- [Configuration](#configuration)
- [Auth & multi-business](#auth--multi-business)
- [Offline & push](#offline--push)
- [Related repositories](#related-repositories)

---

## Purpose & model

| Role | Responsibility |
|------|----------------|
| **Business** | Invites cleaner, collects documents, activates/suspends/offboards, assigns jobs, configures compensation |
| **Cleaner (this app)** | Sees assigned jobs, navigates, clocks in/out, completes checklists, uploads photos, messages, views earnings |

The app never lets a cleaner “join the platform” independently in the marketplace sense. Access is granted only after a business has onboarded them.

---

## Tech stack

| Layer | Choice |
|-------|--------|
| Framework | Flutter (Dart 3.4+) |
| State | Riverpod (+ code generation) |
| Routing | go_router |
| HTTP | Dio |
| Storage | flutter_secure_storage, shared_preferences |
| Location | geolocator, permission_handler |
| Media | image_picker, cached_network_image |
| Push | Firebase Core + Messaging, flutter_local_notifications |
| Models | freezed, json_serializable |
| Other | connectivity_plus, uuid, timeago, url_launcher |

---

## Repository structure

```
cleansera_cleaner_app/
├── android/
├── ios/
├── assets/
│   ├── images/
│   └── icons/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/              # Config, networking, theme, utils
│   ├── features/          # Feature modules (auth, jobs, messages, …)
│   ├── models/
│   ├── providers/
│   └── widgets/
├── test/
├── pubspec.yaml
└── analysis_options.yaml
```

Feature folders under `lib/features/` map to product areas (jobs, messaging, profile, payroll visibility, etc.).

---

## Features

Implemented or in active development (see recent commits):

- **Auth** — login, session, business affiliation selection
- **Jobs** — assigned jobs list & detail, property notes, status updates
- **Checklists** — job-specific checklist completion
- **Photos** — job photo capture / upload (before & after style workflows)
- **Location** — GPS for clock-in / proximity (permissions required)
- **Messaging** — conversation with the business
- **Push notifications** — Firebase Messaging + local notifications
- **Offline queue** — queue actions when offline and sync when back online
- **Earnings / payouts** — visibility into compensation and payout status (backed by real payroll on the API)
- **Profile** — cleaner profile and document-related surfaces where exposed by the API

The business dashboard remains the source of truth for roster status, compensation rules, and offboarding.

---

## Prerequisites

- Flutter SDK matching `environment.sdk` in `pubspec.yaml` (`>=3.4.0 <4.0.0`)
- Android Studio / Xcode for device or emulator builds
- Running CleanSera API with valid CORS / mobile-accessible base URL
- Firebase project configured for push (Android + iOS)
- Backend env: `FIREBASE_*` credentials so the API can send pushes

---

## Local setup

```bash
# 1. Clone
git clone https://github.com/olumuyiwaa/cleansera_cleaner_app.git
cd cleansera_cleaner_app

# 2. Dependencies
flutter pub get

# 3. Code generation (Riverpod / freezed / json_serializable)
dart run build_runner build --delete-conflicting-outputs

# 4. Configure API base URL
#    Typically in lib/core/config or via --dart-define / env files used by your team.
#    Point at your local or staging API, e.g. http://10.0.2.2:8000/api/v1 (Android emulator)
#    or http://localhost:8000/api/v1 (iOS simulator / desktop).

# 5. Firebase
#    Add google-services.json (Android) and GoogleService-Info.plist (iOS)
#    matching the Firebase project used by the backend.

# 6. Run
flutter run
```

For a clean rebuild of generated code:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

---

## Configuration

Common configuration points (exact paths may vary as the app evolves):

- **API base URL** — must match a reachable `cleansera_sass` instance (`/api/v1`)
- **Firebase** — same project as backend push credentials
- **Deep links / scheme** — if used for invites or password reset

Do not hardcode production secrets in the client. Use compile-time defines or secure remote config as needed.

Example run with define:

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

---

## Auth & multi-business

- Cleaners authenticate as Users.
- Backend issues sessions that can be bound to a `businessId`.
- If a cleaner has multiple `CleanerProfile` rows (multiple employers), the app should allow switching workspace so jobs and messaging stay scoped correctly.
- Offboarded or suspended profiles must not receive new assignments; the API enforces this — the app should handle 403 / empty states gracefully.

---

## Offline & push

- **Offline queue**: actions taken without connectivity are queued and replayed when connectivity returns (`connectivity_plus` + local persistence).
- **Push**: Firebase Cloud Messaging; backend uses Firebase Admin to target device tokens stored on the cleaner profile.
- Request location and notification permissions at the appropriate points in the UX (not only on first launch).

---

## Scripts / common commands

| Command | Description |
|---------|-------------|
| `flutter pub get` | Install packages |
| `dart run build_runner build --delete-conflicting-outputs` | Generate code |
| `flutter run` | Run on connected device / emulator |
| `flutter test` | Unit / widget tests |
| `flutter analyze` | Static analysis |

---

## Related repositories

| Repo | Role |
|------|------|
| [cleansera_sass](https://github.com/olumuyiwaa/cleansera_sass) | Backend API (auth, jobs, payroll, push) |
| [cleansera_sass_frontend](https://github.com/olumuyiwaa/cleansera_sass_frontend) | Business dashboard (roster, dispatch, compensation) |
| [cleansera_sass_website](https://github.com/olumuyiwaa/cleansera_sass_website) | Marketing site |

---

## License

Private — all rights reserved.
