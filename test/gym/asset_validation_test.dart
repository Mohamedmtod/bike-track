import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GYM-P1-001 — 3D Asset Validation & Model Integrity Tests', () {
    final modelsDir = Directory('assets/gym/models');
    final glbFile = File('assets/gym/models/male_anatomy.glb');
    final manifestFile = File('assets/gym/models/manifest.json');
    final licenseFile = File('assets/gym/models/LICENSE.txt');
    final noticeFile = File('assets/gym/models/NOTICE.txt');

    test('All required 3D model and license files exist', () {
      expect(modelsDir.existsSync(), isTrue, reason: 'Models directory must exist');
      expect(glbFile.existsSync(), isTrue, reason: 'male_anatomy.glb must exist');
      expect(manifestFile.existsSync(), isTrue, reason: 'manifest.json must exist');
      expect(licenseFile.existsSync(), isTrue, reason: 'LICENSE.txt must exist');
      expect(noticeFile.existsSync(), isTrue, reason: 'NOTICE.txt must exist');
    });

    test('GLB file size is optimized for mobile (< 10MB)', () {
      final sizeInBytes = glbFile.lengthSync();
      final sizeInMB = sizeInBytes / (1024 * 1024);
      expect(sizeInMB, lessThan(10.0), reason: 'Model size should be below 10MB for fast load and low RAM footprint');
      expect(sizeInMB, greaterThan(1.0), reason: 'Model size should be reasonable for a 126-muscle segmented model');
    });

    test('GLB binary header is valid glTF 2.0', () {
      final bytes = glbFile.readAsBytesSync();
      expect(bytes.length, greaterThan(20), reason: 'GLB must have valid header');

      // Magic: 'glTF' in ASCII = 0x46546C67
      final magic = ByteData.sublistView(bytes, 0, 4).getUint32(0, Endian.little);
      expect(magic, equals(0x46546C67), reason: 'Invalid glTF magic number');

      // Version: 2
      final version = ByteData.sublistView(bytes, 4, 8).getUint32(0, Endian.little);
      expect(version, equals(2), reason: 'Expected glTF version 2');

      // Total file length matches header length
      final declaredLength = ByteData.sublistView(bytes, 8, 12).getUint32(0, Endian.little);
      expect(declaredLength, equals(bytes.length), reason: 'Declared length in header must match actual file size');
    });

    test('manifest.json contains valid 18 muscle groups and 126 anatomical regions', () {
      final jsonStr = manifestFile.readAsStringSync();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(data['version'], equals(1));
      expect(data['model']['id'], equals('male'));

      final regions = data['regions'] as List<dynamic>;
      expect(regions.length, equals(126), reason: 'Must have exactly 126 anatomical regions');

      final muscleGroups = <String>{};
      for (final r in regions) {
        expect(r['id'], isNotNull);
        expect(r['muscle'], isNotNull);
        expect(r['side'], anyOf('left', 'right', 'both'));
        muscleGroups.add(r['muscle'] as String);
      }

      // Check essential muscle groups
      expect(muscleGroups, containsAll([
        'chest',
        'biceps',
        'triceps',
        'quads',
        'hamstrings',
        'glutes',
        'lats',
        'abdominals',
        'calves',
        'front-shoulders',
        'rear-shoulders',
        'traps',
        'lowerback',
      ]));
      expect(muscleGroups.length, equals(18), reason: 'Must cover 18 distinct anatomical muscle groups');
    });

    test('GLB internal nodes contain mesh targets matching anatomical manifest', () {
      final bytes = glbFile.readAsBytesSync();
      // First chunk is JSON
      final chunkLength = ByteData.sublistView(bytes, 12, 16).getUint32(0, Endian.little);
      final chunkType = ByteData.sublistView(bytes, 16, 20).getUint32(0, Endian.little);
      // 'JSON' chunk type = 0x4E4F534A
      expect(chunkType, equals(0x4E4F534A));

      final jsonBytes = bytes.sublist(20, 20 + chunkLength);
      final gltf = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;

      final nodes = (gltf['nodes'] as List<dynamic>).cast<Map<String, dynamic>>();
      final nodeNames = nodes.map((n) => n['name'] as String? ?? '').toList();

      expect(nodeNames.length, greaterThanOrEqualTo(126));

      // Check key muscle node names are present in the GLB
      final sampleExpectedSubstrings = [
        'pectoralis-major',
        'anterior-deltoid',
        'lateral-deltoid',
        'posterior-deltoid',
        'biceps',
        'triceps',
        'rectus-abdominis',
        'latissimus-dorsi',
        'rectus-femoris',
        'gluteus-maximus',
        'gastrocnemius',
      ];

      for (final expected in sampleExpectedSubstrings) {
        final matches = nodeNames.where((name) => name.contains(expected));
        expect(
          matches.isNotEmpty,
          isTrue,
          reason: 'Expected node containing "$expected" to be present in GLB, found none',
        );
      }
    });
  });
}

