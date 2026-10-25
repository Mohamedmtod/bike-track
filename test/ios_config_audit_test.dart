import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bike_track/config.dart';

void main() {
  group('iOS Config & Pre-Codemagic Build Audit Tests', () {
    final infoPlistFile = File('ios/Runner/Info.plist');
    final projectFile = File('ios/Runner.xcodeproj/project.pbxproj');
    final codemagicFile = File('codemagic.yaml');
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

      // UIBackgroundModes must retain both background capabilities used by the app.
      expect(content.contains('<key>UIBackgroundModes</key>'), isTrue);
      expect(content.contains('<string>location</string>'), isTrue);
      expect(content.contains('<string>fetch</string>'), isTrue);
    });

    test('3. Info.plist contains CFBundleURLSchemes with cycletrack and probike for NFC/Deep linking', () {
      final content = infoPlistFile.readAsStringSync();

      expect(content.contains('<key>CFBundleURLSchemes</key>'), isTrue);
      expect(content.contains('<string>cycletrack</string>'), isTrue);
      expect(content.contains('<string>probike</string>'), isTrue);
      expect(content.contains('<key>LSApplicationQueriesSchemes</key>'), isTrue);
      expect(content.contains('<string>shortcuts</string>'), isTrue);
    });

    test('4. Runner bundle identifier matches the OSM user agent package', () {
      expect(projectFile.existsSync(), isTrue);
      final project = projectFile.readAsStringSync();
      final runnerBundleIds = RegExp(
              r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
          .allMatches(project)
          .map((match) => match.group(1)!.trim())
          .where((id) => !id.endsWith('.RunnerTests'))
          .toSet();

      expect(runnerBundleIds, equals({'com.probike.tracker'}));
    });

    test('5. Codemagic performs sequential tests and packages an unsigned IPA', () {
      expect(codemagicFile.existsSync(), isTrue);
      final content = codemagicFile.readAsStringSync();

      expect(content.contains('flutter test --concurrency=1'), isTrue);
      expect(content.contains('flutter build ios --release --no-codesign'), isTrue);
      expect(content.contains('mkdir -p Payload'), isTrue);
      expect(content.contains('cp -r build/ios/iphoneos/Runner.app Payload/'), isTrue);
      expect(content.contains('zip -r -y ProBike_iOS.ipa Payload'), isTrue);
      expect(content.contains('- ProBike_iOS.ipa'), isTrue);
      expect(content.contains('stadia_credentials'), isTrue,
          reason: 'Codemagic environment must declare the stadia_credentials group');
      expect(content.contains('STADIA_MAPS_API_KEY'), isTrue,
          reason: 'Codemagic must reference STADIA_MAPS_API_KEY for release builds');
      expect(content.contains('if [ -z "\$STADIA_MAPS_API_KEY" ]; then'), isTrue,
          reason: 'Codemagic must fail the build if STADIA_MAPS_API_KEY is missing');
      expect(content.contains('exit 1'), isTrue,
          reason: 'Codemagic must exit with 1 on missing key');
    });

    test('6. pubspec.yaml contains bike_track and necessary dependencies', () {
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

    test('6. Info.plist does NOT contain Google Maps SDK API key (GMSApiKey)', () {
      final content = infoPlistFile.readAsStringSync();

      // Must NOT contain Google Maps API key entries
      expect(content.contains('GMSApiKey'), isFalse,
          reason: 'Info.plist must not contain GMSApiKey - we use flutter_map with OSM, not Google Maps SDK');
      expect(content.contains('com.google.maps'), isFalse,
          reason: 'Info.plist must not reference Google Maps SDK');
      expect(content.contains('AIza'), isFalse,
          reason: 'Info.plist must not contain any Google API key (AIza prefix)');
    });

    test('7. Info.plist has correct CFBundleDisplayName and CFBundleName as ProBike', () {
      final content = infoPlistFile.readAsStringSync();

      // CFBundleDisplayName should be ProBike
      expect(content.contains('<key>CFBundleDisplayName</key>'), isTrue);
      // The value after CFBundleDisplayName should be ProBike
      final displayNameRegex = RegExp(
          r'<key>CFBundleDisplayName</key>\s*<string>([^<]+)</string>');
      final displayMatch = displayNameRegex.firstMatch(content);
      expect(displayMatch, isNotNull,
          reason: 'CFBundleDisplayName must be present with a value');
      expect(displayMatch!.group(1)!.trim(), equals('ProBike'));

      // CFBundleName should be ProBike
      final bundleNameRegex = RegExp(
          r'<key>CFBundleName</key>\s*<string>([^<]+)</string>');
      final nameMatch = bundleNameRegex.firstMatch(content);
      expect(nameMatch, isNotNull,
          reason: 'CFBundleName must be present with a value');
      expect(nameMatch!.group(1)!.trim(), equals('ProBike'));
    });

    test('8. pubspec.yaml version is 1.1.0+2 or higher', () {
      final content = pubspecFile.readAsStringSync();
      final versionRegex = RegExp(r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)');
      final match = versionRegex.firstMatch(content);
      expect(match, isNotNull, reason: 'pubspec.yaml must have a version field');

      final major = int.parse(match!.group(1)!);
      final minor = int.parse(match.group(2)!);
      final build = int.parse(match.group(4)!);

      // At minimum 1.1.0+2
      expect(major >= 1, isTrue);
      if (major == 1) {
        expect(minor >= 1, isTrue);
        if (minor == 1) {
          expect(build >= 2, isTrue);
        }
      }
    });

    test('9. Both maps use Stadia Alidade Smooth Dark configuration without ColorFiltered wrapper', () {
      final mapFiles = [
        File('lib/screens/live_ride_screen.dart'),
        File('lib/screens/ride_details_screen.dart'),
      ];

      for (final file in mapFiles) {
        expect(file.existsSync(), isTrue, reason: '${file.path} must exist');
        final content = file.readAsStringSync();
        expect(content.contains('StadiaMapConfig.buildTileLayer('), isTrue,
            reason: '${file.path} must use StadiaMapConfig.buildTileLayer()');
        expect(content.contains('StadiaAttributionWidget('), isTrue,
            reason: '${file.path} must declare visible StadiaAttributionWidget');
        expect(content.contains('ColorFiltered('), isFalse,
            reason: '${file.path} must not wrap tiles in ColorFiltered');
      }

      final configFile = File('lib/config/map_config.dart');
      expect(configFile.existsSync(), isTrue, reason: 'map_config.dart must exist');
      final configContent = configFile.readAsStringSync();
      expect(
        configContent.contains('https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png'),
        isTrue,
        reason: 'StadiaMapConfig must define base Alidade Smooth Dark tile URL',
      );
      expect(
        configContent.contains('userAgentPackageName = \'com.probike.tracker\''),
        isTrue,
        reason: 'StadiaMapConfig must specify production user agent',
      );

      final searchableSources = [
        ...Directory('lib').listSync(recursive: true).whereType<File>(),
        ...Directory('ios').listSync(recursive: true).whereType<File>(),
      ].where((file) => file.path.endsWith('.dart') || file.path.endsWith('.plist'));
      for (final file in searchableSources) {
        final content = file.readAsStringSync();
        expect(content.toLowerCase().contains('cartocdn.com'), isFalse,
            reason: '${file.path} must not reference CARTO');
        expect(content.toLowerCase().contains('mapbox'), isFalse,
            reason: '${file.path} must not reference Mapbox');
        expect(content.toLowerCase().contains('google maps'), isFalse,
            reason: '${file.path} must not reference Google Maps');
      }
    });
  });
}
