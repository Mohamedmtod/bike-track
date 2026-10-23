# 🚴 Bike Track — Official Project Specifications (Single Source of Truth)

## 1. Project Vision & Core Philosophy
- **Target User:** Personal single-user application (built specifically for the owner's personal use on **iPhone 14 Pro**).
- **Core Goal:** Track daily and weekly cycling distance, duration, and speed accurately triggered via an NFC tag mounted on the bike, with zero friction and zero over-engineering.
- **Strict Simplicity Rule:**
  - **NO** user authentication or login screens.
  - **NO** `.env` files or environment loader packages (`lib/config.dart` holds constants directly).
  - **NO** complex mathematical filters (no Kalman filters, no AI motion classification, no pedometer/activity recognition).
  - **NO** storing thousands of raw GPS points in the cloud database; route polyline lives in memory during the active ride, and only the final ride summary is persisted to Supabase.

---

## 2. User Journey & NFC Workflow
1. **Start Ride (NFC Trigger):**
   - The user places their iPhone 14 Pro near the NFC tag on the bike.
   - iOS Apple Shortcuts triggers the deep link: `cycletrack://start`.
   - The app opens directly to the **Live Ride Screen**, starts the timer and GPS tracking, and fires an immediate start notification.
2. **Duplicate NFC Tap Protection (Idempotency):**
   - If the phone touches the NFC tag multiple times while a ride is already active (`isRiding == true`), the app MUST ignore the extra triggers completely without resetting or duplicating the active ride.
3. **During the Ride:**
   - The screen displays a live dark-mode map with the route polyline, current location marker, elapsed duration, distance (`km`), current speed (`km/h`), max speed, and min speed.
   - The screen stays awake (`wakelock_plus`) while open on the handlebar, and continues tracking in the background if the user locks the phone.
   - **Smart "Still Riding?" Reminder:** Every `X` minutes (customizable by the user in 5-minute steps from the Dashboard), the app sends a notification asking if the user is still on the bike or forgot to stop the ride.
4. **Stop Ride:**
   - The user taps the large red **STOP RIDE** button inside the app (or triggers `cycletrack://stop` via Shortcut).
   - Tracking stops, ride summary is saved to Supabase (`public.rides`), a completion summary notification is sent, and the app returns to the **Dashboard Screen**.

---

## 3. Functional Requirements & Calculations

### A. Metrics & GPS Logic (`geolocator`)
- **Distance (`distanceMeters`):** Calculated incrementally using `Geolocator.distanceBetween` between consecutive GPS updates. Ignore micro-jitter steps smaller than `2.0 meters`.
- **Current Speed (`currentSpeedKmh`):** Read directly from iPhone GPS hardware (`position.speed * 3.6`). No complex smoothing equations.
- **Max Speed (`maxSpeedKmh`):** Highest `currentSpeedKmh` recorded during the ride.
- **Min Speed (`minSpeedKmh`):** Lowest non-stationary moving speed recorded during the ride (`currentSpeedKmh > 2.0 km/h`).
- **Average Speed (`avgSpeedKmh`):** Calculated at ride completion as `(distanceMeters / 1000) / (durationSeconds / 3600)`.
- **Elapsed Time (`durationSeconds`):** Must accurately reflect real elapsed ride time even if iOS locks the screen or throttles background timers.

### B. Notifications (`flutter_local_notifications`)
1. **Ride Started Notification:** Fired immediately when `startRide()` begins (`"🚴 بدأت الرحلة! العداد شغال دلوقتي.. طريق السلامة يا بطل"`).
2. **Periodic Reminder Notification:** Fired every `reminderMinutes` (`"🤔 لسه راكب العجلة؟ عدى X دقيقة على الرايد.. لسه مكمل ولا نزلت ونسيت توقف؟"`).
   - **Customizable Interval:** User can adjust `reminderMinutes` directly from the Dashboard using `[+ 5 دقايق]` and `[- 5 دقايق]` buttons (clamped between `5` and `180` minutes, persisted in `SharedPreferences`).
3. **Ride Completed Notification:** Fired when `stopRide()` finishes, showing total distance in km and duration in minutes.

---

## 4. Cloud Database Specification (Supabase)
- **Single Table Only (`public.rides`):**
  - `id`: `bigint` (Primary Key, Identity)
  - `start_time`: `timestamptz` (ISO8601 UTC string)
  - `duration_seconds`: `int`
  - `distance_meters`: `float8`
  - `avg_speed_kmh`: `float8`
  - `max_speed_kmh`: `float8`
  - `min_speed_kmh`: `float8`
- **Access Policy:** Personal app using direct `anon` key access (RLS disabled or open anon policy for `public.rides`).
- **Offline Safety:** Saving to Supabase must be wrapped in `try/catch` so poor street connectivity never crashes the UI or prevents stopping a ride.

---

## 5. Target Hardware & UI/UX Specifications (iPhone 14 Pro)
- **Target Viewport:** iPhone 14 Pro (`393 x 852` logical points, `@3x` DPR, `120Hz` ProMotion Super Retina XDR OLED).
- **Safe Area & Hardware Cutouts:**
  - **Top Inset (`59pt`):** Must clear the **Dynamic Island** cleanly on `DashboardScreen`, and float status pills below `59pt` on `LiveRideScreen` while the map bleeds edge-to-edge behind the island.
  - **Bottom Inset (`34pt`):** Bottom buttons (`Start Ride` / `STOP RIDE`) must have sufficient bottom padding above the iOS Home Indicator to prevent accidental swipe collisions.
- **Visual Design System:**
  - **Colors:** True OLED Black (`#090A0F`), Titanium Dark Cards (`#14161F`) with `24px` radius and subtle `1px` border, Electric Neon Lime (`#CCFF00`) primary accent, Crimson Red (`#FF2D55`) stop action.
  - **Typography:** All timers, speeds, and distances MUST use `FontFeature.tabularFigures()` to prevent horizontal jitter during live updates, and `FittedBox(fit: BoxFit.scaleDown)` to guarantee zero `RenderFlex` overflow.
  - **Map Styling:** OpenStreetMap `TileLayer` filtered through a dark-mode color matrix so the map renders as a dark navigation radar with a high-contrast `#CCFF00` route polyline.
  - **Haptics:** Native iOS Taptic Engine feedback (`HapticFeedback`) on all button interactions.

---

## 6. Screen Architecture (Strictly 2 Screens)
1. **`DashboardScreen`:**
   - Today's Hero Card (Total Distance km, Total Duration, Max Speed today).
   - Weekly Overview Card (Last 7 days total km, ride count, and 7-day visual bar chart).
   - Dynamic Reminder Control Card (`[- 5 دقايق]` / `[+ 5 دقايق]` stepper showing current `reminderMinutes`).
   - Recent Rides History List (fetched from Supabase).
   - Manual Start Ride Button at the bottom.
2. **`LiveRideScreen`:**
   - Top 55%: Dark-mode `FlutterMap` with live route polyline, current position marker, and recenter button.
   - Bottom 45%: Glassmorphic cockpit showing live digital timer, 4 metric tiles (Distance, Current Speed, Max Speed, Min Speed), and a full-width Red **STOP RIDE** button.
