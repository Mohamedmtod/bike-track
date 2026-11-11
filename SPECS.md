# 🚴 ProBike — Official System Specifications (Single Source of Truth)

> **Application Identifier:** `com.probike.tracker`  
> **Status:** Production-Ready • 156 Passing Automated Tests • 0 Linter Warnings  
> **Target Platform:** iOS (iPhone 14 Pro, iOS 16+)  
> **Companion Bike:** Galaxy RL600H Hybrid (Alloy Titanium Frame)  
> **Detailed Documentation:** See the [`docs/`](./docs/README.md) hub for modular technical guides.

---

## 1. Project Vision & Core Philosophy
- **Target User:** Personal single-user cycling application tailored for high-precision telemetry on **iPhone 14 Pro** and handlebar mounting on the **Galaxy RL600H Hybrid** bike.
- **Core Goal:** Real-time route tracking, speed metrics, day-level analytics, personal records, and instant start/stop automation triggered via NFC stem tap.
- **Strict Simplicity Invariants:**
  - **NO** user authentication or login screens required for primary telemetry.
  - **NO** runtime `.env` loaders (`lib/config.dart` and `lib/config/map_config.dart` use clean constants and compile-time `--dart-define`).
  - **Offline-First Resilience:** Local persistence in `SharedPreferences` precedes any Supabase network request.
  - **Crash Resilience:** 10-second active ride snapshots safeguard in-progress sessions against iOS background terminations.

---

## 2. User Journey & NFC Workflow
1. **Start Ride (NFC Trigger):**
   - The cyclist taps the iPhone against the waterproof NTAG213/215 sticker on the bike stem.
   - Apple Shortcuts invokes deep link `probike://start` (or legacy `cycletrack://start`).
   - The app navigates directly to **`LiveRideScreen`**, begins GPS acquisition, activates screen wakelock (`WakelockPlus`), and fires an immediate start notification.
2. **Rapid NFC Tap Debounce (Idempotency):**
   - If the iPhone taps the stem sticker repeatedly (up to 20x within 2 seconds), `RideController` enforces an atomic re-entrancy lock (`_isStarting`), ignoring duplicate executions without resetting distance.
3. **During the Ride:**
   - Fullscreen dark map displays route polyline (ambient glow + solid core), 42x42 navigation puck, and live telemetry cards with tabular figures.
   - 4-layer GPS filter cleans accuracy jumps, Doppler stationary speeds, micro-jitter, and tunnel speed spikes.
   - Periodic hydration alert vibrates and notifies rider according to `reminderMinutes` (5–180 min stepper).
4. **Stop Ride:**
   - Cyclist taps the full-width Stop Ride button (or triggers `probike://stop`).
   - Tracking stops, wakelock is released, wall-clock duration is reconciled, local storage is updated, and non-blocking sync queues the summary to Supabase.
   - Cyclist is directed to **`RideDetailsScreen`** or back to **`DashboardScreen`**.

---

## 3. Screen Architecture (The 6 Production Screens)

The application implements 6 fully tested screens (see [`docs/architecture.md`](./docs/architecture.md)):

1. **`DashboardScreen`:**
   - Today's Hero Card (aggregate distance, moving pedal time, average speed).
   - 7-Day Rolling Interactive Bar Chart (tapping any column opens `DailyStatsScreen` for that date).
   - Active Ride Glowing Banner (resumes live ride after cold restart or background switch).
   - Manual Ride Entry modal (`is_manual: true`).
   - Recent rides history with bidirectional swipe-to-delete and rollback SnackBar.
2. **`LiveRideScreen`:**
   - Edge-to-edge Stadia Maps Alidade Smooth Dark cartography behind Dynamic Island.
   - Dual-layer glowing route polyline and navigation puck.
   - Tabular telemetry cards: Speed (`km/h`), moving time (`HH:MM:SS`), distance (`km`), top speed.
   - Red Stop Ride action button with double haptic pulse.
3. **`RideDetailsScreen`:**
   - Dynamic route camera bounds fitting (`CameraFit.bounds` with 32pt padding).
   - Green start pin and red finish checkered marker.
   - Clean stat breakdown fallback when `is_manual: true` or GPS coordinates are empty.
4. **`DailyStatsScreen` (Day Analytics & Unified Map):**
   - Chronological breakdown of all rides completed on the selected local calendar day.
   - Unified multi-ride Stadia dark map displaying all routes simultaneously with distinct neon colors.
   - Interactive route filter chips to highlight individual rides and dim remaining paths.
   - Vector share card generator (`DailyShareCard`) exporting 3x high-res PNGs for social sharing.
5. **`OverallStatsScreen` (Analytics Hub & Personal Records):**
   - Period segmentation switcher: `Day`, `Week`, `Month`, `Year`, and `All Time`.
   - Metric pill switcher: `Distance`, `Duration`, `Average Speed`, and `Ride Count`.
   - Dynamic bar chart bucketed by period.
   - Personal records showcases: Longest Ride, Fastest Average Speed, Most Active Day.
   - Digital all-time lifetime odometer.
6. **`SettingsScreen`:**
   - Theme switcher sheet (`Galaxy RL600H`, `ProBike Classic`, `Editorial Aubergine`).
   - Language toggle (Egyptian Arabic `ar` vs Modern English `en`).
   - Hydration alert stepper (5 to 180 minutes).
   - NFC & Apple Shortcuts setup wizard with one-tap clipboard copy.
   - Cloud sync diagnostics and pending offline ride counter.

---

## 4. GPS Physics & Anti-Drift Engine

A deterministic 4-layer physics filter runs on every position update (see [`docs/gps-telemetry-physics.md`](./docs/gps-telemetry-physics.md)):
- **Layer 1 (Accuracy):** Rejects `position.accuracy > 20.0m` (clamps speed to 0.0).
- **Layer 2 (Doppler Stationary):** Rejects `rawSpeedKmh <= 2.5 km/h` + 3-second silence watchdog.
- **Layer 3 (Micro-Jitter):** Rejects geodesic distance `stepMeters <= 3.0m` between points.
- **Layer 4 (Speed Spike):** Rejects satellite teleportation `rawSpeedKmh > 65.0 km/h`.
- **Wall-Clock Duration Sync:** Reconciles elapsed time against `DateTime.now().difference(startTime)` to counter iOS background suspension.
- **Zero NaN/Infinity Defense:** Division guards ensure invalid numbers never reach UI or database.

---

## 5. Offline-First Architecture & Supabase Schema

Local persistence always precedes remote network requests (see [`docs/offline-sync-database.md`](./docs/offline-sync-database.md)):
- **Keys in `SharedPreferences`:** `cached_rides_history`, `pending_sync_rides`, `pending_delete_rides`, `active_ride_snapshot`, `telemetry_queue`.
- **Supabase PostgreSQL Tables:**
  - `public.rides` (deduplicated on `client_id` with idempotent upsert).
  - `public.ride_logs` (telemetry events, in-memory ring buffer of 500, 14-day auto purge).
- **Overnight Rides (`isOvernight`):** Timestamps stored in explicit UTC; daily aggregations computed according to the rider's local calendar day (`toLocal()`).

---

## 6. Cartography & Design System

- **Map Provider:** Stadia Maps Alidade Smooth Dark (`keepBuffer: 4`, `panBuffer: 2`). Key injected via `--dart-define=STADIA_MAPS_API_KEY`. Missing key automatically activates `SafeEmptyTileProvider` without unauthenticated requests.
- **Attribution:** Visible and clickable `© Stadia Maps © OpenMapTiles © OpenStreetMap` via `StadiaAttributionWidget`.
- **3 Contrast Palettes:**
  - `Galaxy RL600H`: Titanium gunmetal (`#121418`) + electric cobalt blue (`#0EA5E9`).
  - `ProBike Classic`: OLED black (`#090A0F`) + neon cyber lime (`#CCFF00`).
  - `Editorial Aubergine`: Warm ivory (`#F6F1E9`) + deep plum (`#51283F`).
- **Typography:** Tabular figures (`FontFeature.tabularFigures()`) across all telemetry; defensive `FittedBox` on all large metrics.
- **Bilingual Engine:** Zero-overhead getters in `AppStrings`. Zero language mixing in Arabic mode; complete RTL layout support.

---

## 7. Automated Testing & Verification Invariants

- **Automated Test Suite:** 156 passing tests across 16 test files.
- **Static Analysis:** 0 errors, 0 warnings (`flutter analyze`).
- **CI/CD:** Codemagic builds unsigned IPA for sideloading (`codemagic.yaml`); GitHub Actions executes release verification (`ios_build.yml`).
