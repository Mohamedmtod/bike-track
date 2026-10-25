import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

/// Central configuration for Stadia Maps (Alidade Smooth Dark style).
///
/// Reads the API key strictly from `--dart-define=STADIA_MAPS_API_KEY=...`
/// at compile time. Never hardcodes a real key and guards against
/// unauthenticated network requests in release builds or test environments.
class StadiaMapConfig {
  /// Compile-time environment variable key.
  static const String _envApiKey =
      String.fromEnvironment('STADIA_MAPS_API_KEY');

  /// Stadia Maps Alidade Smooth Dark raster tile URL template.
  static const String baseTileUrl =
      'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png';

  /// Required attribution text using standard unicode escape to prevent encoding corruption.
  static const String attributionText =
      '\u00A9 Stadia Maps \u00A9 OpenMapTiles \u00A9 OpenStreetMap';

  /// User agent package name sent in HTTP headers.
  static const String userAgentPackageName = 'com.probike.tracker';

  /// Optional listener/callback for tile load errors, useful for diagnostics and testing.
  static void Function(TileCoordinates coordinates, Object error, StackTrace? stackTrace)?
      onTileError;

  /// In-memory test key override for automated testing.
  static String? _testApiKey;

  /// Sets an in-memory test API key for testing without environment variables.
  @visibleForTesting
  static void setTestApiKey(String? key) {
    _testApiKey = key;
  }

  /// Clears any in-memory test API key override.
  @visibleForTesting
  static void resetTestApiKey() {
    _testApiKey = null;
  }

  /// Active API key: returns injected test key if present, otherwise compile-time environment key.
  static String get apiKey => _testApiKey ?? _envApiKey;

  /// Returns true if a non-empty API key is configured.
  static bool get isConfigured => apiKey.trim().isNotEmpty;

  /// Builds the Stadia raster URL template from an optional explicit key or active key.
  /// If no key is available, returns null so unauthenticated requests are not issued.
  static String? buildUrlTemplate([String? explicitKey]) {
    final key = explicitKey ?? apiKey;
    if (key.trim().isEmpty) {
      return null;
    }
    return '$baseTileUrl?api_key=${key.trim()}';
  }

  /// Builds the standard [TileLayer] for ProBike with approved buffer settings.
  /// When unconfigured, safely falls back to [SafeEmptyTileProvider] to eliminate
  /// unauthenticated network requests and prevent test crashes.
  static TileLayer buildTileLayer({
    int keepBuffer = 4,
    int panBuffer = 2,
    String? explicitKey,
  }) {
    final url = buildUrlTemplate(explicitKey);
    final hasKey = url != null && url.isNotEmpty;

    return TileLayer(
      urlTemplate: url,
      subdomains: const [],
      userAgentPackageName: userAgentPackageName,
      keepBuffer: keepBuffer,
      panBuffer: panBuffer,
      tileProvider: hasKey ? NetworkTileProvider() : SafeEmptyTileProvider(),
      errorTileCallback: (tile, error, stackTrace) {
        debugPrint(
          'StadiaMapConfig: Network error loading tile [z=${tile.coordinates.z}, x=${tile.coordinates.x}, y=${tile.coordinates.y}]: $error',
        );
        onTileError?.call(tile.coordinates, error, stackTrace);
      },
    );
  }
}

/// Fallback TileProvider supplying a 1x1 transparent PNG in memory.
/// Guarantees that when the API key is missing or in widget tests,
/// flutter_map renders cleanly without sending unauthenticated requests.
class SafeEmptyTileProvider extends TileProvider {
  SafeEmptyTileProvider({super.headers});

  static final Uint8List _transparentPng = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_transparentPng);
  }
}

/// Visible, legible attribution widget required by Stadia Maps.
/// Displays "© Stadia Maps © OpenMapTiles © OpenStreetMap" with active links
/// and stays visible without requiring user interaction.
class StadiaAttributionWidget extends StatelessWidget {
  final Alignment alignment;
  final EdgeInsetsGeometry margin;

  const StadiaAttributionWidget({
    super.key,
    this.alignment = Alignment.bottomRight,
    this.margin = const EdgeInsets.all(8),
  });

  static Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        margin: margin,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Text.rich(
          TextSpan(
            text: '\u00A9 ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
            children: [
              TextSpan(
                text: 'Stadia Maps',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => _openUrl('https://stadiamaps.com/'),
              ),
              const TextSpan(text: ' \u00A9 '),
              TextSpan(
                text: 'OpenMapTiles',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => _openUrl('https://openmaptiles.org/'),
              ),
              const TextSpan(text: ' \u00A9 '),
              TextSpan(
                text: 'OpenStreetMap',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap =
                      () => _openUrl('https://www.openstreetmap.org/copyright'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
