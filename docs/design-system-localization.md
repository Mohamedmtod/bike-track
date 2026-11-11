# 🎨 Design System, Theming & Localization

> **Context:** Contrast-tailored themes, vector share card exporter, typography invariants, and bilingual localization engine.  
> **Source Files:** [`lib/theme/app_theme.dart`](file:///f:/dev/bike-track/lib/theme/app_theme.dart), [`lib/l10n/app_strings.dart`](file:///f:/dev/bike-track/lib/l10n/app_strings.dart), [`lib/widgets/daily_share_card.dart`](file:///f:/dev/bike-track/lib/widgets/daily_share_card.dart)

---

## 1. The 3 Contrast-Tailored Palettes

ProBike provides three handcrafted palettes managed via `ThemeController`:

| Attribute | Galaxy RL600H *(Default)* | ProBike Classic | Editorial Aubergine |
| :--- | :--- | :--- | :--- |
| **Philosophy** | Matched to bike titanium frame | OLED cyber night cockpit | High-contrast daylight riding |
| **Background** | `#121418` (Dark Gunmetal) | `#090A0F` (True OLED Black) | `#F6F1E9` (Warm Ivory) |
| **Surface Card** | `#1A1E24` | `#14161F` | `#FFFFFF` |
| **Primary Accent** | `#0EA5E9` (Cobalt Blue) | `#CCFF00` (Neon Cyber Lime) | `#51283F` (Deep Plum) |
| **Polyline Core** | `#0EA5E9` | `#CCFF00` | `#51283F` |
| **Polyline Glow** | `0x660EA5E9` | `0x66CCFF00` | `0x4451283F` |
| **Map Tile Tint** | Direct Stadia Dark | Direct Stadia Dark | Warm Ivory Matrix |

### Custom Warm Ivory Matrix for Daylight Map
```dart
static const ColorFilter warmIvoryMapFilter = ColorFilter.matrix(<double>[
  0.95,  0.0,   0.0,   0.0, 10.0,
  0.0,   0.92,  0.0,   0.0,  8.0,
  0.0,   0.0,   0.85,  0.0,  5.0,
  0.0,   0.0,   0.0,   1.0,  0.0,
]);
```

---

## 2. Typography & Layout Invariants

### 2.1 Tabular Figures Defense
In cycling cockpits, timers and speedometers update every second or with every GPS fix. Proportional numbers cause width changes that make the UI visually jitter. All numerical telemetry displays **MUST** use `FontFeature.tabularFigures()`:
```dart
style: TextStyle(
  fontFeatures: const [FontFeature.tabularFigures()],
  // ...
)
```

### 2.2 RenderFlex Overflow Defense
On smaller screen configurations or when font scaling is increased, speed and distance numbers can cause overflow exceptions. All primary telemetry metrics are wrapped in defensive `FittedBox` widgets:
```dart
FittedBox(
  fit: BoxFit.scaleDown,
  child: Text(
    formattedValue,
    style: theme.telemetryLarge,
  ),
)
```

---

## 3. High-Res Vector Share Card (`DailyShareCard`)

### Architecture & Export Pipeline
Cyclists can share their daily achievements directly to Instagram Stories, WhatsApp, or Twitter without cloud rendering:
1. `DailyShareCard` renders an offscreen high-contrast vector card (`RepaintBoundary`).
2. Computes the normalized vector route projection onto a `CustomPainter` canvas.
3. Renders metrics: Date, Total Distance (`km`), Moving Time, Average Speed, and Top Speed.
4. Exports a high-density PNG (`ui.ImageByteFormat.png` at pixel ratio `3.0`).
5. Invokes `IShareService.shareImageFile()` to open the native iOS share sheet via `share_plus`.

---

## 4. Bilingual Localization Engine (`lib/l10n/`)

Controlled by `LocaleController` (`selected_language` key: `'ar'` or `'en'`). `AppStrings` provides zero-overhead, type-safe getters for the entire UI:

### 4.1 Egyptian Cycling Slang (`ar` — Default)
- Incorporates natural, energetic Cairo street-cycling vocabulary:
  - Header greeting: *"يا هلا يا كابتن! 🚴‍♂️"*
  - Subtitle: *"جاهز لطلعة جديدة النهاردة؟"*
  - Active button: *"🚴 ابدأ رايد دلوقتي (Start)"*
  - Moving time: *"وقت البدال"*
  - Map recenter: *"سنترني ع الخريطة"*
  - Hydration card: *"منبه شرب المية والراحة 💧"*
  - Bike rig specs: *"شاسيه ألومنيوم تيتانيوم • سرعات Shimano Tourney 3x7 • قفل مساعدين"*
  - Stop shortcut: *"فرمل ووقّف الرايد"*

### 4.2 Modern Cycling English (`en`)
- Crisp, professional international cycling vernacular:
  - Header: *"Welcome back, Rider! 🚴‍♂️"*
  - Subtitle: *"Ready to crush a new ride today?"*
  - Active button: *"🚴 Let's Roll (Start Ride)"*
  - Moving time: *"Moving Time"*
  - Map recenter: *"Recenter Map"*
  - Hydration card: *"Hydration & Rest Reminder 💧"*
  - Bike rig specs: *"Alloy Titanium Frame • Shimano Tourney 3x7 • Suspension Lockout"*
  - Stop shortcut: *"Shortcut: Stop & Finish Ride"*

### 4.3 Zero Language Mixing & RTL Layout
- In Arabic mode, English words are forbidden from headings, metric titles, and dialogs.
- Full Right-to-Left (RTL) mirroring is respected across all metric cards, navigation chevrons, and sheet layouts.

