# ⚡ Hardware Integration, NFC & Apple Shortcuts

> **Context:** Hardware specs for iPhone 14 Pro and Galaxy RL600H, NFC stem automation, deep link routing, and Apple Shortcuts integration.  
> **Source Files:** [`lib/services/shortcuts_service.dart`](file:///f:/dev/bike-track/lib/services/shortcuts_service.dart), [`lib/services/ride_controller.dart`](file:///f:/dev/bike-track/lib/services/ride_controller.dart), [`lib/main.dart`](file:///f:/dev/bike-track/lib/main.dart)

---

## 1. Target Hardware Specifications

### 1.1 iPhone 14 Pro
- **Screen Resolution:** 393 × 852 logical points @ 3x Retina (`1179 × 2556` physical px).
- **Display Technology:** Super Retina XDR OLED display. True black backgrounds (`#090A0F`, `#121418`) turn off OLED pixels, drastically conserving battery during multiple hours of handlebar GPS navigation.
- **Dynamic Island Inset:** Top safe area inset is **`59.0` pt**. On `LiveRideScreen`, maps bleed behind the island while telemetry pills float below 59pt.
- **Home Indicator Inset:** Bottom safe area inset is **`34.0` pt**. Action buttons have defensive padding to prevent accidental iOS home gestures.
- **Background Execution:** `UIBackgroundModes: location` enabled with `showBackgroundLocationIndicator: true` and `pauseLocationUpdatesAutomatically: false`.

### 1.2 Galaxy RL600H Hybrid Bike
- **Frame:** Alloy Titanium / Gunmetal Matte Finish.
- **Drivetrain:** Shimano Tourney 3×7 Speed Groupset.
- **Front Suspension:** Equipped with a mechanical lockout knob finished in iconic electric cobalt blue (`#0EA5E9`).
- **NFC Tag Placement:** An NTAG213 / NTAG215 waterproof sticker is adhered to the handlebar stem. Tapping the iPhone against this tag launches or stops rides instantly.

---

## 2. Deep Linking Architecture

Both schemes are registered in `ios/Runner/Info.plist` and parsed in `lib/main.dart`:
- `probike://start` & `probike://stop` (Primary Modern Scheme)
- `cycletrack://start` & `cycletrack://stop` (Legacy Backward-Compatible Alias)

```mermaid
flowchart LR
    NFC[NFC Stem Tag Tap] --> SHORT[Apple Shortcuts Automation]
    SHORT -->|Deep Link URI: probike://start| APP[lib/main.dart: onGenerateRoute / Stream]
    APP -->|Command: startRide()| RC[RideController]
    RC -->|Verify Idle & Acquire GPS| LIVE[Open LiveRideScreen]
```

---

## 3. Rapid-Fire NFC Tap Debounce Protection

### The Problem
When the iPhone rests on or near the handlebar stem mount, minor handlebar vibrations or physical re-adjustments can cause the NFC chip to trigger the shortcut repeatedly (up to 10–20 times in 2 seconds).

### The Solution: Re-entrancy Lock
`RideController` implements an atomic state guard:
```dart
bool _isStarting = false;

Future<bool> startRide() async {
  // If ride is already active or start sequence is currently running, ignore
  if (isRiding || _isStarting) {
    return false;
  }
  
  _isStarting = true;
  try {
    // 1. Initialize session & telemetry
    // 2. Start GPS acquisition
    // 3. Fire start notification
    return true;
  } finally {
    _isStarting = false;
  }
}
```
If the user taps the NFC tag 20 times in rapid succession, only the first trigger executes; subsequent calls are rejected cleanly without resetting distance or disrupting GPS tracking.

---

## 4. Apple Shortcuts Automation Workflow

### Why Not Direct `.shortcut` Files?
Direct binary `.shortcut` downloads cannot be imported into modern iOS versions without Apple Developer Team signatures or iCloud sharing links, yielding security errors.

### The In-App Clipboard Wizard (`ShortcutsService`)
1. In `SettingsScreen`, the user taps **"Setup Shortcut"** under the NFC section.
2. `ShortcutsService` copies `probike://start` (or `probike://stop`) directly to the iOS clipboard with `Clipboard.setData()`.
3. A visual step-by-step bottom sheet explains how to create the automation in 10 seconds:
   - **Step 1:** Open Apple Shortcuts app $\rightarrow$ Automation tab $\rightarrow$ "Create Personal Automation".
   - **Step 2:** Select "NFC" $\rightarrow$ Tap "Scan" and touch the stem sticker.
   - **Step 3:** Add action "Open URLs" $\rightarrow$ Paste copied link.
   - **Step 4:** Toggle OFF "Ask Before Running" and set "Notify When Run" to OFF.

