import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';

class ShortcutsService {
  static const String schemeStart = 'probike://start';
  static const String schemeStop = 'probike://stop';
  static const String legacySchemeStart = 'cycletrack://start';
  static const String legacySchemeStop = 'cycletrack://stop';

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

  /// Copies a URL scheme directly to the device clipboard.
  static Future<void> copySchemeToClipboard(String scheme) async {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
    await Clipboard.setData(ClipboardData(text: scheme));
  }

  /// Opens Apple Shortcuts app, attempting to create a new shortcut directly.
  static Future<bool> openShortcutsApp({bool createNew = true}) async {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    final createUri = Uri.parse('shortcuts://create-shortcut');
    final defaultUri = Uri.parse('shortcuts://');

    try {
      if (createNew && await canLaunchUrl(createUri)) {
        return await launchUrl(createUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(defaultUri)) {
        return await launchUrl(defaultUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  /// One-tap flow: copies the scheme to clipboard and opens the Shortcuts app.
  static Future<bool> setupShortcutWithClipboard({required String scheme}) async {
    await copySchemeToClipboard(scheme);
    return await openShortcutsApp(createNew: true);
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
