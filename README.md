# CleanSera Cleaner App (Flutter + Riverpod)

Mobile app for **business-owned cleaners** on CleanSera.

## Features

- Login with cleaner credentials (created by the business)
- Today’s jobs + multi-day schedule
- Job detail: customer, address, notes, maps, call
- Check-in (optional GPS), start job, complete job
- Interactive checklists
- Profile + sign out

## Stack

- Flutter 3.24+
- **Riverpod** (`flutter_riverpod`) for state
- `go_router` navigation
- `dio` + `flutter_secure_storage` for API + tokens
- `geolocator`, `url_launcher`

## Quick start

```bash
cd cleansera_cleaner_app
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-api.example.com
```

Default API base is `http://localhost:8000`.

## Structure

```
lib/
  main.dart, app.dart
  core/          constants, network (Dio), theme, router
  models/        User, CleanerProfile, Job, Checklist
  features/      auth, home, jobs, checklist, profile
  providers/     authProvider, jobsProvider, jobActions
  widgets/
```

## Backend contract (align with cleansera_sass)

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/auth/login` | email/password → tokens + user |
| POST | `/auth/refresh` | refresh access token |
| GET | `/cleaners/me` | active cleaner profile |
| GET | `/bookings/my` | `?from=&to=&status=` |
| GET | `/bookings/:id` | job detail |
| POST | `/bookings/:id/check-in` | optional lat/lng |
| POST | `/bookings/:id/start` | start job |
| POST | `/bookings/:id/complete` | finish job |
| GET | `/checklists/booking/:id` | checklist |
| POST | `/checklists/items/:id/complete` | tick item |

Only users with an **ACTIVE** `CleanerProfile` can use the app.

## Permissions

**Android** – INTERNET, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION  
**iOS** – NSLocationWhenInUseUsageDescription

## Next steps

1. Match response shapes to your real API
2. Firebase push for new assignments
3. Photo proof on complete
4. Offline checklist queue

Private — CleanSera.
