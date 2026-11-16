import 'dart:io';
import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/models/exercise.dart';
import 'package:bike_track/features/gym/presentation/screens/muscle_detail_screen.dart';
import 'package:bike_track/features/gym/presentation/widgets/exercise_thumbnail_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('Exercise Visual Guide & High-Res Anatomy Tests', () {
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

    test('Exercise asset files exist on disk with valid file size and format', () {
      final anatomyFile = File('assets/exercises/bench_press.png');
      final guideFile = File('assets/exercises/bench_press_guide.jpg');

      expect(anatomyFile.existsSync(), isTrue, reason: 'bench_press.png must exist');
      expect(anatomyFile.lengthSync(), greaterThan(10 * 1024), reason: 'bench_press.png must be non-empty');

      expect(guideFile.existsSync(), isTrue, reason: 'bench_press_guide.jpg must exist');
      expect(guideFile.lengthSync(), greaterThan(10 * 1024), reason: 'bench_press_guide.jpg must be non-empty');
    });

    test('ExerciseThumbnailWidget registers high-res illustrations and guides', () {
      expect(ExerciseThumbnailWidget.getIllustration('bench_press'), equals('assets/exercises/bench_press.png'));
      expect(ExerciseThumbnailWidget.getGuide('bench_press'), equals('assets/exercises/bench_press_guide.jpg'));
      expect(ExerciseThumbnailWidget.getIllustration('unknown_exercise'), isNull);
      expect(ExerciseThumbnailWidget.getGuide('unknown_exercise'), isNull);
    });

    testWidgets('ExerciseThumbnailWidget renders Image for bench_press and vector painter for fallback', (tester) async {
      const benchPress = Exercise(
        id: 'bench_press',
        name: 'Barbell Bench Press',
        loggingType: ExerciseLoggingType.weightAndReps,
        laterality: 'bilateral',
        equipment: 'barbell',
      );

      const pushup = Exercise(
        id: 'pushup',
        name: 'Push-up',
        loggingType: ExerciseLoggingType.bodyweightReps,
        laterality: 'bilateral',
        equipment: 'bodyweight',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ExerciseThumbnailWidget(exercise: benchPress, size: 54),
                ExerciseThumbnailWidget(exercise: pushup, size: 54),
              ],
            ),
          ),
        ),
      );

      // Bench press should include an Image widget
      expect(find.byType(Image), findsOneWidget);
      // Pushup should fall back to CustomPaint
      expect(find.byType(CustomPaint), findsWidgets);
    });

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

    testWidgets('MuscleDetailScreen displays Form Guide and 5 Points of Contact for bench press', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MuscleDetailScreen(muscleId: 'chest', dbService: dbService),
        ),
      );

      await pumpUntilFound(tester, find.byKey(const Key('exercise_card_bench_press')));
      expect(find.byKey(const Key('exercise_card_bench_press')), findsOneWidget);

      // Open bottom sheet
      await tester.tap(find.byKey(const Key('exercise_card_bench_press')));
      await pumpUntilFound(tester, find.byKey(const Key('add_exercise_to_workout_button')));
      await tester.pump(const Duration(milliseconds: 400));

      // Verify the 5 Points of Contact cues are rendered
      expect(find.textContaining('5 POINTS OF CONTACT'), findsOneWidget);
      expect(find.textContaining('Glutes Firmly on Bench'), findsOneWidget);
      expect(find.textContaining('Shoulder Blades Retracted'), findsOneWidget);
      expect(find.textContaining('Feet Planted on Floor'), findsOneWidget);
      expect(find.textContaining('Head Firmly on Bench'), findsOneWidget);
      expect(find.textContaining('Elbows at 45° Angle'), findsOneWidget);

      // Verify the interactive image and zoom prompt are rendered
      expect(find.text('Tap to Zoom'), findsOneWidget);

      // Tap Add to Workout to close the sheet cleanly
      await tester.ensureVisible(find.byKey(const Key('add_exercise_to_workout_button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('add_exercise_to_workout_button')));
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
