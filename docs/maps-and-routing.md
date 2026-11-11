# 🗺️ Cartography, Stadia Maps & Route Rendering

> **Context:** Dark cartography integration, compile-time key security, fallback tile provider, dual-layer route styling, and camera bounds fitting.  
> **Source Files:** [`lib/config/map_config.dart`](file:///f:/dev/bike-track/lib/config/map_config.dart), [`lib/screens/live_ride_screen.dart`](file:///f:/dev/bike-track/lib/screens/live_ride_screen.dart), [`lib/screens/ride_details_screen.dart`](file:///f:/dev/bike-track/lib/screens/ride_details_screen.dart), [`lib/screens/daily_stats_screen.dart`](file:///f:/dev/bike-track/lib/screens/daily_stats_screen.dart)

---

## 1. Native Dark Cartography: Stadia Maps Alidade Smooth Dark

ProBike relies exclusively on **Stadia Maps Alidade Smooth Dark** raster tiles. This style provides high-contrast, distraction-free night and day cartography tailored for handlebar viewing:

- **Tile Template URL:** `https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png?api_key=<key>`
- **User Agent Header:** `com.probike.tracker`
- **Tile Buffering:** `keepBuffer: 4`, `panBuffer: 2` (guarantees smooth panning during rapid handlebar vibrations).
- **Background Matching:** The map background is styled with the active theme background color, preventing white flashes while tiles load.

---

## 2. API Key Security & Compile-Time Injection

### Invariant: Zero Hardcoded Keys
API keys are never checked into version control or written into Dart source code.

### Build-Time Injection
The key is injected strictly at compile time via Flutter's `--dart-define`:
```bash
flutter build ios --release --no-codesign --dart-define=STADIA_MAPS_API_KEY="your_api_key_here"
```

In `StadiaMapConfig`:
```dart
static const String _envApiKey = String.fromEnvironment('STADIA_MAPS_API_KEY');
```

### CI/CD Enforcement
In `codemagic.yaml`, release builds fail immediately with an explicit diagnostic message if `STADIA_MAPS_API_KEY` is missing from the environment.

---

## 3. Safe Missing-Key Fallback (`SafeEmptyTileProvider`)

### The Challenge
During automated widget testing and developer builds without an active API key, sending unauthenticated HTTP requests to Stadia Maps produces `401 Unauthorized` errors, breaks offline test guarantees, and pollutes test logs.

### The Solution
`StadiaMapConfig.buildTileLayer()` automatically switches tile providers based on key availability:
```dart
static TileLayer buildTileLayer({
  String? explicitKey,
  Color? backgroundColor,
}) {
  final url = buildUrlTemplate(explicitKey);
  if (url == null) {
    // Returns 1x1 transparent byte tiles without network requests
    return TileLayer(
      tileProvider: const SafeEmptyTileProvider(),
      tileBuilder: (context, tileWidget, tile) => Container(
        color: backgroundColor ?? const Color(0xFF121418),
      ),
    );
  }

  return TileLayer(
    urlTemplate: url,
    userAgentPackageName: userAgentPackageName,
    keepBuffer: 4,
    panBuffer: 2,
  );
}
```

---

## 4. Mandatory Cartographic Attribution

In compliance with OpenStreetMap and Stadia Maps licensing, every map view (`LiveRideScreen`, `RideDetailsScreen`, `DailyStatsScreen`) includes active attribution:
- Text: `© Stadia Maps © OpenMapTiles © OpenStreetMap`
- Widget: `StadiaAttributionWidget`
- Hyperlinks: Tapping opens browser links to respective license pages via `url_launcher`.

---

## 5. Dual-Layer Glowing Route Polylines

To maximize visibility under direct sunlight and high ambient contrast, active routes are rendered as a **dual-layer glowing polyline**:

```mermaid
graph TD
    subgraph Polyline_Stack [Dual-Layer Polyline]
        GLOW[Outer Glow Line:\nWidth = 8.0 - 10.0\nColor = theme.polylineGlow (Semi-Transparent)]
        CORE[Inner Core Line:\nWidth = 3.5 - 4.5\nColor = theme.polylineCore (Solid Accent)]
    end
```

```dart
PolylineLayer(
  polylines: [
    // Layer 1: Ambient Glow
    Polyline(
      points: routePoints,
      strokeWidth: 9.0,
      color: theme.polylineGlow,
    ),
    // Layer 2: High-Contrast Core
    Polyline(
      points: routePoints,
      strokeWidth: 4.0,
      color: theme.polylineCore,
    ),
  ],
)
```

---

## 6. Camera Bounds Auto-Fitting (`CameraFit.bounds`)

When reviewing completed rides in `RideDetailsScreen`:
1. If `routePoints.length >= 2`, calculates bounding box:
   ```dart
   final bounds = LatLngBounds.fromPoints(routePoints);
   ```
2. Fits camera dynamically with comfortable edge padding:
   ```dart
   mapController.fitCamera(
     CameraFit.bounds(
       bounds: bounds,
       padding: const EdgeInsets.all(32.0),
     ),
   );
   ```
3. Displays a green circle pin at start coordinate and a red checkered pin at the finish coordinate.
4. If `routePoints.isEmpty` or `isManual == true`, gracefully hides map and renders `AppStrings.manualRideNoMap`.

---

## 7. Unified Multi-Ride Day Map (`DailyStatsScreen`)

When exploring a day with multiple rides:
- All routes taken on that day are rendered simultaneously on one unified Stadia dark map.
- Each ride is assigned a distinct vibrant neon hue from `_routeColors` (`Emerald`, `Cyan`, `Violet`, `Amber`, `Coral`, `Blue`).
- **Filter Chips:** Tapping a specific ride filter chip dims non-selected routes (`withOpacity(0.2)`) and highlights the active route.

