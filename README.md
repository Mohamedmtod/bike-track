# 🚴 ProBike (`com.probike.tracker`)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![iOS](https://img.shields.io/badge/iOS-16%2B-black?logo=apple)](https://apple.com)
[![Tests](https://img.shields.io/badge/Tests-92%20Passing-brightgreen)](https://github.com/Mohamedmtod/bike-track)
[![Analysis](https://img.shields.io/badge/Analysis-0%20Issues-brightgreen)](https://github.com/Mohamedmtod/bike-track)
[![Supabase](https://img.shields.io/badge/Supabase-Cloud%20Synced-3ECF8E?logo=supabase)](https://supabase.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **ProBike** is an offline-first, high-precision cycling telemetry app and route cockpit built for the **iPhone 14 Pro** and tailored for the **Galaxy RL600H Hybrid** bike. It features a 4-layer GPS anti-drift filter, keyless OpenStreetMap rendering with theme matrices, NFC stem-tap automation, and a bilingual design system.

---

> 🤖 **AI Agents & Contributors:** Read [`AGENT_CONTEXT.md`](file:///f:/dev/bike-track/AGENT_CONTEXT.md) first before modifying any code!  
> It contains the complete architectural bible, strict invariants, database schema, and test suite specifications.

---

## 🌟 Key Features

- **🛡️ 4-Layer GPS Anti-Drift Engine:** Real-time physics pipeline rejecting horizontal inaccuracy (>20m), Doppler stationary speeds (≤2.5 km/h), micro-jitter (≤3m), and tunnel teleportation spikes (>65 km/h).
- **🗺️ Keyless Themed Maps:** 100% free official OpenStreetMap server tiles styled on-the-fly via custom Flutter `ColorFilter` matrices (Dark OLED & Warm Ivory) without API keys or third-party style servers.
- **⚡ Instant NFC & Apple Shortcuts:** Tap the iPhone against the bike stem NFC tag to instantly launch or stop rides via `probike://start` and `probike://stop`.
- **☁️ Offline-First & Crash Resilience:** Local-first persistence in `SharedPreferences`, snapshot recovery every 10 seconds, and deduplicated upserts on `client_id` in Supabase PostgreSQL.
- **🎨 3 Contrast-Tailored Themes:**
  1. **Galaxy RL600H - Titanium Sport (Default):** Gunmetal background with electric cobalt blue suspension-knob accents.
  2. **ProBike Classic:** OLED pitch-black with cyber neon lime.
  3. **Editorial Aubergine:** Warm ivory and deep plum for daylight riding.
- **🇪🇬 Bilingual Localization:** Instant toggle between authentic Egyptian Cycling Slang (`ar`) and Modern Pro Cycling English (`en`).
- **📊 Interactive Analytics & Management:** Today's Hero stats, 7-day rolling overview, manual ride entry modal, and bidirectional Swipe-to-Delete with confirmation safeguards.
- **💧 Smart Hydration Reminders:** Periodic haptic pulses (customizable 5 to 180 mins) to hydrate and rest during long rides.

---

## 🚀 Quick Start

### 1. Prerequisites
- Flutter SDK (stable channel)
- CocoaPods & Xcode (for iOS builds)

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run Static Analysis
```bash
flutter analyze
```

### 4. Run the 92+ Automated Test Suite
```bash
flutter test
```

### 5. Run on Connected Device / Simulator
```bash
flutter run
```

---

## 🧪 Testing Architecture

ProBike maintains a strict testing regime with **92 automated unit, widget, and chaos scenarios**:

```bash
# Run all unit, widget, and edge-case tests
flutter test

# Run the 30 Chaos & Stress failure scenarios
flutter test test/stress_and_edge_cases_test.dart

# Run live Supabase roundtrip integration test
RUN_SUPABASE_LIVE_TEST=true flutter test test/supabase_live_test.dart
```

See [`AGENT_CONTEXT.md`](file:///f:/dev/bike-track/AGENT_CONTEXT.md) for full descriptions of all 10 test files and stress groups.

---

## 📦 CI/CD Pipeline (Codemagic)

ProBike builds automated unsigned IPAs for sideloading via AltStore, Sideloadly, or TrollStore through [`codemagic.yaml`](file:///f:/dev/bike-track/codemagic.yaml):

1. Enables Swift Package Manager
2. Resolves dependencies (`flutter pub get`)
3. Enforces zero lint issues (`flutter analyze`)
4. Verifies 100% test pass rate (`flutter test`)
5. Compiles unsigned iOS release (`flutter build ios --release --no-codesign`)
6. Packages payload into `ProBike_iOS.ipa`

---

## 📄 License

This project is licensed under the MIT License.
