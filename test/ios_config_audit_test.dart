import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bike_track/config.dart';

void main() {
  group('iOS Config & Pre-Codemagic Build Audit Tests', () {
    final infoPlistFile = File('ios/Runner/Info.plist');
    final pubspecFile = File('pubspec.yaml');

    test('1. Info.plist exists and is well-formed XML', () {
      expect(infoPlistFile.existsSync(), isTrue,
          reason: 'ios/Runner/Info.plist must exist');

      final content = infoPlistFile.readAsStringSync();
      expect(content, isNotEmpty);

      // Remove XML comments: <!-- ... -->
      final withoutComments =
          content.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

      // Tokenize XML tags
      final tagRegex = RegExp(r'<(\/)?([a-zA-Z0-9_\-]+)([^>]*?)(\/?)>');
      final matches = tagRegex.allMatches(withoutComments);

      final List<String> tagStack = [];

      for (final match in matches) {
        final isClosing = match.group(1) == '/';
        final tagName = match.group(2)!;
        final attributes = match.group(3) ?? '';
        final isSelfClosing = match.group(4) == '/' || attributes.trim().endsWith('/');

        // Skip declaration and doctype if caught by regex
        if (tagName.startsWith('?') || tagName.startsWith('!')) continue;

        if (isSelfClosing) {
          // Self-closing tag <tag/> is valid and does not change stack
          continue;
        } else if (isClosing) {
          expect(tagStack.isNotEmpty, isTrue,
              reason: 'Found closing tag </$tagName> with empty tag stack');
          final lastTag = tagStack.removeLast();
          expect(lastTag, equals(tagName),
              reason: 'Tag mismatch: expected closing </$lastTag> but got </$tagName>');
        } else {
          // Opening tag <tag>
          tagStack.add(tagName);
        }
      }

      expect(tagStack.isEmpty, isTrue,
          reason: 'Unclosed XML tags remaining in Info.plist: $tagStack');
    });

    test('2. Info.plist contains all required Location & Background permissions', () {
      final content = infoPlistFile.readAsStringSync();

      // NSLocationWhenInUseUsageDescription
      expect(content.contains('<key>NSLocationWhenInUseUsageDescription</key>'), isTrue);
      expect(content.contains('Tracking your bike ride distance, speed, and live route.'), isTrue);

      // NSLocationAlwaysAndWhenInUseUsageDescription
      expect(
          content.contains('<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>'),
          isTrue);

      // UIBackgroundModes with location
      expect(content.contains('<key>UIBackgroundModes</key>'), isTrue);
      expect(content.contains('<string>location</string>'), isTrue);
    });

    test('3. Info.plist contains CFBundleURLSchemes with cycletrack for NFC/Deep linking', () {
      final content = infoPlistFile.readAsStringSync();

      expect(content.contains('<key>CFBundleURLSchemes</key>'), isTrue);
      expect(content.contains('<string>cycletrack</string>'), isTrue);
    });

    test('4. pubspec.yaml contains bike_track and necessary dependencies', () {
      expect(pubspecFile.existsSync(), isTrue);
      final content = pubspecFile.readAsStringSync();

      expect(content.contains('name: bike_track'), isTrue);
      expect(content.contains('geolocator:'), isTrue);
      expect(content.contains('wakelock_plus:'), isTrue);
      expect(content.contains('flutter_map:'), isTrue);
      expect(content.contains('supabase_flutter:'), isTrue);
      expect(content.contains('flutter_local_notifications:'), isTrue);
    });

    test('5. lib/config.dart has non-empty supabaseUrl and supabaseAnonKey', () {
      expect(supabaseUrl, isNotEmpty);
      expect(supabaseUrl.startsWith('https://'), isTrue);
      expect(supabaseAnonKey, isNotEmpty);
      expect(supabaseAnonKey.split('.').length, equals(3),
          reason: 'supabaseAnonKey should be a valid 3-part JWT token');
    });
  });
}
