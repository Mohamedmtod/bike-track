import 'dart:io';
import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/presentation/screens/gym_dashboard_screen.dart';
import 'package:bike_track/features/gym/services/gym_backup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('TEST-DB-04 — Database Backup & Export Tests', () {
    late GymDatabaseService dbService;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('probike_backup_test_');
      dbService = GymDatabaseService(databaseFactory: databaseFactoryFfi);
      await dbService.initialize(inMemory: true);
      GymDatabaseService.defaultInstance = dbService;
    });

    tearDown(() async {
      await dbService.close();
      GymDatabaseService.defaultInstance = null;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Widget createTestApp(Widget home) {
      return MaterialApp(
        home: home,
      );
    }

    Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {int maxRounds = 30}) async {
      for (int i = 0; i < maxRounds; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 60));
        if (finder.evaluate().isNotEmpty) {
          return;
        }
      }
      await tester.pump();
    }

    test('GymBackupService creates timestamped backup file with flushed content', () async {
      final service = GymBackupService(dbService: dbService);
      final backup = await service.createBackupFile(customTargetDir: tempDir);

      expect(backup.existsSync(), isTrue);
      expect(backup.path.contains('probike_gym_backup_'), isTrue);
      expect(backup.path.endsWith('.db'), isTrue);

      final content = await backup.readAsString();
      expect(content.isNotEmpty, isTrue);
    });

    test('GymBackupService invokes share handler with XFile application/x-sqlite3', () async {
      ShareParams? capturedParams;

      final service = GymBackupService(
        dbService: dbService,
        customShareHandler: (params) async {
          capturedParams = params;
          return const ShareResult('success', ShareResultStatus.success);
        },
      );

      final result = await service.exportBackupToFiles();

      expect(result.status, equals(ShareResultStatus.success));
      expect(capturedParams, isNotNull);
      expect(capturedParams!.files, isNotNull);
      expect(capturedParams!.files!.length, equals(1));
      expect(capturedParams!.files!.first.path.endsWith('.db'), isTrue);
      expect(capturedParams!.files!.first.mimeType, equals('application/x-sqlite3'));
      expect(capturedParams!.subject, contains('ProBike Gym'));
    });

    testWidgets('Tapping gym_backup_button in AppBar executes backup and displays SnackBar', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool shareInvoked = false;
      final backupService = GymBackupService(
        dbService: dbService,
        customShareHandler: (params) async {
          shareInvoked = true;
          return const ShareResult('success', ShareResultStatus.success);
        },
      );

      await tester.pumpWidget(createTestApp(
        GymDashboardScreen(
          dbService: dbService,
          backupService: backupService,
        ),
      ));

      await pumpUntilFound(tester, find.byKey(const Key('gym_backup_button')));
      expect(find.byKey(const Key('gym_backup_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('gym_backup_button')));
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (shareInvoked) break;
      }

      expect(shareInvoked, isTrue);
      expect(find.textContaining('Backup created:'), findsOneWidget);
    });

    testWidgets('Tapping export_backup_card_button in Dashboard executes backup cleanly', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool cardShareInvoked = false;
      final backupService = GymBackupService(
        dbService: dbService,
        customShareHandler: (params) async {
          cardShareInvoked = true;
          return const ShareResult('success', ShareResultStatus.success);
        },
      );

      await tester.pumpWidget(createTestApp(
        GymDashboardScreen(
          dbService: dbService,
          backupService: backupService,
        ),
      ));

      await pumpUntilFound(tester, find.text('ProBike Gym'));

      final scrollableFinder = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('export_backup_card_button')),
        200.0,
        scrollable: scrollableFinder,
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('export_backup_card_button')));
      for (int i = 0; i < 20; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
        if (cardShareInvoked) break;
      }

      expect(cardShareInvoked, isTrue);
      expect(find.textContaining('Backup created:'), findsOneWidget);
    });
  });
}
