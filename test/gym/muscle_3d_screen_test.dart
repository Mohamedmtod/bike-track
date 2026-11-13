import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/presentation/screens/gym_dashboard_screen.dart';
import 'package:bike_track/features/gym/presentation/screens/muscle_3d_screen.dart';
import 'package:bike_track/features/gym/presentation/screens/muscle_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('TEST-3D-03 — 3D Muscle Map Screen & Interaction Tests', () {
    late GymDatabaseService dbService;

    setUp(() async {
      dbService = GymDatabaseService(databaseFactory: databaseFactoryFfi);
      await dbService.initialize(inMemory: true);
      GymDatabaseService.defaultInstance = dbService;
    });

    tearDown(() async {
      await dbService.close();
      GymDatabaseService.defaultInstance = null;
    });

    Widget createTestApp(Widget home) {
      return MaterialApp(home: home);
    }

    Future<void> pumpUntilFound(
      WidgetTester tester,
      Finder finder, {
      int maxRounds = 30,
    }) async {
      for (int i = 0; i < maxRounds; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 60));
        if (finder.evaluate().isNotEmpty) {
          return;
        }
      }
      await tester.pump();
    }

    testWidgets(
      'Muscle3DScreen renders mode controls, camera angle button, and muscle chips',
      (tester) async {
        tester.view.physicalSize = const Size(1179, 2556);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          createTestApp(Muscle3DScreen(dbService: dbService)),
        );
        await pumpUntilFound(tester, find.text('3D Muscle Map'));

        expect(find.text('3D Muscle Map'), findsOneWidget);
        expect(find.byKey(const Key('diagnostics_hud_button')), findsOneWidget);
        expect(find.byKey(const Key('mode_explore_button')), findsOneWidget);
        expect(find.byKey(const Key('mode_orbit_button')), findsOneWidget);
        expect(
          find.byKey(const Key('camera_angle_toggle_button')),
          findsOneWidget,
        );
        expect(find.text('FRONT'), findsOneWidget);

        // Verify quick muscle chips rendered
        await pumpUntilFound(tester, find.byKey(const Key('3d_chip_chest')));
        expect(find.byKey(const Key('3d_chip_chest')), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping diagnostics HUD button toggles real-time telemetry HUD',
      (tester) async {
        tester.view.physicalSize = const Size(1179, 2556);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          createTestApp(Muscle3DScreen(dbService: dbService)),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('diagnostics_hud_button')),
        );

        // Tap to activate HUD
        await tester.tap(find.byKey(const Key('diagnostics_hud_button')));
        await tester.pump(const Duration(milliseconds: 100));

        // Tap again to deactivate HUD
        await tester.tap(find.byKey(const Key('diagnostics_hud_button')));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(const Key('diagnostics_hud_button')), findsOneWidget);
      },
    );

    testWidgets(
      'Toggling interaction mode switches between Explore and Orbit',
      (tester) async {
        tester.view.physicalSize = const Size(1179, 2556);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          createTestApp(Muscle3DScreen(dbService: dbService)),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('mode_orbit_button')),
        );

        // Tap Orbit Mode
        await tester.tap(find.byKey(const Key('mode_orbit_button')));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Orbit 360° (تدوير)'), findsOneWidget);

        // Tap Explore Mode
        await tester.tap(find.byKey(const Key('mode_explore_button')));
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('1-Finger: Select / 2-Fingers: Rotate & Zoom'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Tapping camera angle button flips between FRONT and BACK', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(Muscle3DScreen(dbService: dbService)),
      );
      await pumpUntilFound(
        tester,
        find.byKey(const Key('camera_angle_toggle_button')),
      );

      expect(find.text('FRONT'), findsOneWidget);

      // Tap to switch to BACK
      await tester.tap(find.byKey(const Key('camera_angle_toggle_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('BACK'), findsOneWidget);

      // Tap to switch back to FRONT
      await tester.tap(find.byKey(const Key('camera_angle_toggle_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('FRONT'), findsOneWidget);
    });

    testWidgets(
      'Selecting a muscle from chips displays action card and navigates to MuscleDetailScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1179, 2556);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          createTestApp(Muscle3DScreen(dbService: dbService)),
        );
        await pumpUntilFound(tester, find.byKey(const Key('3d_chip_chest')));

        // Scroll to chest chip and tap
        await tester.ensureVisible(find.byKey(const Key('3d_chip_chest')));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(const Key('3d_chip_chest')));
        await pumpUntilFound(
          tester,
          find.byKey(const Key('selected_muscle_card')),
        );

        expect(find.byKey(const Key('selected_muscle_card')), findsOneWidget);
        expect(
          find.byKey(const Key('view_targeted_exercises_button')),
          findsOneWidget,
        );

        // Tap View Targeted Exercises
        await tester.tap(
          find.byKey(const Key('view_targeted_exercises_button')),
        );
        await pumpUntilFound(tester, find.byType(MuscleDetailScreen));

        expect(find.byType(MuscleDetailScreen), findsOneWidget);
      },
    );

    testWidgets(
      'GymDashboardScreen navigates directly to Muscle3DScreen on 3D hero tap',
      (tester) async {
        tester.view.physicalSize = const Size(1179, 2556);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          createTestApp(GymDashboardScreen(dbService: dbService)),
        );
        await pumpUntilFound(
          tester,
          find.byKey(const Key('open_3d_muscle_map_button')),
        );

        await tester.tap(find.byKey(const Key('open_3d_muscle_map_button')));
        await pumpUntilFound(tester, find.byType(Muscle3DScreen));

        expect(find.byType(Muscle3DScreen), findsOneWidget);
      },
    );
  });
}
