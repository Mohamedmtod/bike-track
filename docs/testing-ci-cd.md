# 🧪 Automated Testing & CI/CD Pipelines

> **Context:** 156 automated test suite catalog, 30 Chaos & Stress scenarios, Codemagic sideload build workflow, and GitHub Actions.  
> **Source Directory:** [`test/`](file:///f:/dev/bike-track/test), [`codemagic.yaml`](file:///f:/dev/bike-track/codemagic.yaml), [`.github/workflows/ios_build.yml`](file:///f:/dev/bike-track/.github/workflows/ios_build.yml)

---

## 1. Testing Philosophy & Test Matrix

ProBike enforces a strict testing standard with **156 passing automated tests** across 16 test files:

| Test File | Scenarios / Focus | Key Responsibilities |
| :--- | :--- | :--- |
| `stress_and_edge_cases_test.dart` | **30 Scenarios** | 7 Chaos Groups: GPS dropouts, rapid NFC spam, background timer freezes, backend 500s. |
| `ride_logic_test.dart` | **25 Tests** | Unit tests for 4-layer GPS filter, speed calculations, NaN protections, and wall-clock sync. |
| `offline_first_sync_test.dart` | **18 Tests** | Verifies offline queueing, retry loops, slow/hanging networks, and delete synchronization. |
| `analytics_and_daily_stats_test.dart` | **14 Tests** | Multi-ride day aggregations, period summaries, personal records, and widget navigation. |
| `map_and_deeplink_test.dart` | **16 Tests** | Stadia Alidade Smooth Dark URLs, buffer configs, key injection, safe fallback, and deep link parsing. |
| `overnight_ride_day_attribution_test.dart` | **12 Tests** | Midnight crossing attribution, local calendar time vs UTC serialization, and daily summary splitting. |
| `ride_details_and_delete_test.dart` | **9 Tests** | Route bounds calculation, manual ride fallback, bidirectional swipe-to-delete. |
| `settings_and_localization_test.dart` | **7 Tests** | Theme switching, Egyptian/English strings, hydration stepper bounds, clipboard deep-link copy. |
| `editorial_aubergine_ui_ux_test.dart` | **6 Tests** | Editorial Aubergine daylight theme audit, text contrast, zero language mixing in Arabic. |
| `iphone14_pro_ui_test.dart` | **4 Tests** | iPhone 14 Pro screen resolution (393x852) & Dynamic Island safe area padding verification. |
| `theme_customization_test.dart` | **5 Tests** | AppThemeTokens palette integrity, SharedPreferences persistence, selector sheet interaction. |
| `ios_config_audit_test.dart` | **6 Tests** | Validates Info.plist, CFBundleURLSchemes, location background permissions, and build scripts. |
| `rtl_layout_ux_test.dart` | **2 Tests** | Verifies RTL layout, text directionality, and card alignment. |
| `pause_resume_ride_test.dart` | **1 Test** | Pause/resume timing, notification updates, and snapshot preservation. |
| `supabase_live_test.dart` | **2 Tests (Live)** | Live integration against Supabase project `mvgmsnhqsfywvugtpdsq` (gated by env var). |
| `widget_test.dart` | **1 Test** | Application bootstrap smoke test. |

---

## 2. The 30 Chaos & Stress Scenarios (`stress_and_edge_cases_test.dart`)

The chaos test suite simulates real-world street conditions, device edge-cases, and network failures:

- **GROUP A (Scenarios 1–4): Everyday Scenarios**
  - Standard 3-minute ride; instantaneous start/stop; zero-distance rides; 2-hour steady-pace endurance.
- **GROUP B (Scenarios 5–8): Street & Glitch Scenarios**
  - Long red light (speed zeroing); GPS accuracy jumps (>20m); 3m micro-jitter filter; tunnel exit speed spike (>65 km/h).
- **GROUP C (Scenarios 9–14): Catastrophic Failures**
  - 20x rapid NFC spam; offline start & stop with queueing; app crash & snapshot recovery; NaN/Infinity clock skew; corrupt JSON recovery.
- **GROUP D (Scenarios 15–19): iOS Lifecycle & Power**
  - Phone call interruption; background timer throttling (wall-clock sync); low battery mode; notification flood; wake lock toggle.
- **GROUP E (Scenarios 20–24): Street Terrain & Physics**
  - Cobblestone vibrations; U-turns; highway overpass elevation shifts; start/stop in same GPS cell; extreme top speed vs moving min speed.
- **GROUP F (Scenarios 25–28): Storage Resilience & Concurrency**
  - 50 offline rides sync; manual ride entry overlap; offline deletion queueing; local cache clearing without affecting pending queue.
- **GROUP G (Scenarios 29–30): Network & Backend Chaos**
  - Supabase 500 error / offline retry loop; telemetry buffer cap at 500 items.

---

## 3. CI/CD Build Pipelines

### 3.1 Codemagic Unsigned IPA Workflow ([`codemagic.yaml`](file:///f:/dev/bike-track/codemagic.yaml))
Produces unsigned `.ipa` packages ready for sideloading via **AltStore**, **Sideloadly**, or **TrollStore**:
1. Enables Swift Package Manager (`flutter config --enable-swift-package-manager`).
2. Resolves dependencies (`flutter pub get`).
3. Runs static analysis (`flutter analyze` — fails if any warning or issue exists).
4. Executes full automated test suite (`flutter test --concurrency=1`).
5. Validates `STADIA_MAPS_API_KEY` secret.
6. Builds unsigned iOS release (`flutter build ios --release --no-codesign --dart-define=STADIA_MAPS_API_KEY="$STADIA_MAPS_API_KEY"`).
7. Packages payload into `ProBike_iOS.ipa` artifact.

### 3.2 GitHub Actions Workflow ([`.github/workflows/ios_build.yml`](file:///f:/dev/bike-track/.github/workflows/ios_build.yml))
Provides continuous integration verification on every push and pull request to `main`.

---

## 4. Developer Test Commands

```bash
# 1. Run static analysis (must report 0 issues)
flutter analyze

# 2. Run the complete 156-test automated suite
flutter test --concurrency=1

# 3. Run specific test suites
flutter test test/stress_and_edge_cases_test.dart
flutter test test/offline_first_sync_test.dart
flutter test test/overnight_ride_day_attribution_test.dart

# 4. Run live Supabase integration tests (Windows PowerShell)
$env:RUN_SUPABASE_LIVE_TEST="true"; flutter test test/supabase_live_test.dart

# 4b. Run live Supabase integration tests (macOS/Linux)
RUN_SUPABASE_LIVE_TEST=true flutter test test/supabase_live_test.dart
```

