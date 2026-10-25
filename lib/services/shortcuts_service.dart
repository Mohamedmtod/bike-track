import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';

class ShortcutsService {
  static const String schemeStart = 'probike://start';
  static const String schemeStop = 'probike://stop';

  static String get startShortcutCloudUrl =>
      '$supabaseUrl/storage/v1/object/public/shortcuts/ProBike_Start.shortcut';

  static String get stopShortcutCloudUrl =>
      '$supabaseUrl/storage/v1/object/public/shortcuts/ProBike_Stop.shortcut';

  /// Generates the official Apple Shortcuts import URL.
  /// Format: shortcuts://import-shortcut?url=[ENCODED_URL]&name=[ENCODED_NAME]
  static Uri buildImportShortcutUri({required String fileUrl, required String name}) {
    final encodedUrl = Uri.encodeComponent(fileUrl);
    final encodedName = Uri.encodeComponent(name);
    return Uri.parse('shortcuts://import-shortcut?url=$encodedUrl&name=$encodedName');
  }

  /// Triggers opening the Shortcut in iOS Shortcuts app.
  static Future<bool> installShortcut({
    required String fileUrl,
    required String name,
  }) async {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    final importUri = buildImportShortcutUri(fileUrl: fileUrl, name: name);
    try {
      if (await canLaunchUrl(importUri)) {
        return await launchUrl(importUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try opening Shortcuts app directly
        final fallbackShortcutsApp = Uri.parse('shortcuts://');
        if (await canLaunchUrl(fallbackShortcutsApp)) {
          return await launchUrl(fallbackShortcutsApp, mode: LaunchMode.externalApplication);
        }
        // Fallback: try opening file in browser
        final webUri = Uri.parse(fileUrl);
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      return false;
    }
  }

  /// Directly tests the deep link (e.g. probike://start or probike://stop)
  static Future<bool> testDeepLink(String urlScheme) async {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    try {
      final uri = Uri.parse(urlScheme);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
