import 'package:bike_track/features/gym/models/exercise.dart';
import 'package:flutter/material.dart';

/// Rich visual thumbnail widget rendering an illustrated movement figure
/// and equipment badge for any gym exercise.
class ExerciseThumbnailWidget extends StatelessWidget {
  final Exercise exercise;
  final double size;
  final String? primaryMuscleGroup;

  const ExerciseThumbnailWidget({
    super.key,
    required this.exercise,
    this.size = 48,
    this.primaryMuscleGroup,
  });

  @override
  Widget build(BuildContext context) {
    final group = primaryMuscleGroup ?? _detectMuscleGroup(exercise.id);
    final themeColor = _colorForGroup(group);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF14161F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            // Background subtle gradient glow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.85,
                    colors: [
                      themeColor.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Exercise Movement Vector Illustration
            Center(
              child: CustomPaint(
                size: Size(size * 0.72, size * 0.72),
                painter: _ExerciseFigurePainter(
                  exerciseId: exercise.id,
                  muscleGroup: group,
                  accentColor: themeColor,
                ),
              ),
            ),

            // Corner equipment indicator badge
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF090A0F).withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: themeColor.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  _equipmentIcon(exercise.equipment),
                  size: size * 0.22,
                  color: themeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _equipmentIcon(String eq) {
    switch (eq.toLowerCase()) {
      case 'barbell':
        return Icons.fitness_center_rounded;
      case 'dumbbell':
        return Icons.line_weight_rounded;
      case 'cable':
        return Icons.cable_rounded;
      case 'machine':
        return Icons.settings_rounded;
      case 'bodyweight':
        return Icons.accessibility_new_rounded;
      default:
        return Icons.sports_gymnastics_rounded;
    }
  }

  static String _detectMuscleGroup(String id) {
    if (id.contains('press') || id.contains('fly') || id.contains('pushup') || id.contains('dips')) {
      return 'chest';
    }
    if (id.contains('squat') || id.contains('leg') || id.contains('calf') || id.contains('deadlift')) {
      return 'legs';
    }
    if (id.contains('row') || id.contains('pull') || id.contains('lat') || id.contains('shrug')) {
      return 'back';
    }
    if (id.contains('curl') || id.contains('tricep') || id.contains('wrist')) {
      return 'arms';
    }
    if (id.contains('overhead') || id.contains('raise') || id.contains('face_pull')) {
      return 'shoulders';
    }
    if (id.contains('crunch') || id.contains('plank') || id.contains('ab')) {
      return 'core';
    }
    return 'chest';
  }

  static Color _colorForGroup(String group) {
    switch (group.toLowerCase()) {
      case 'chest':
        return const Color(0xFF00E5FF); // Electric Cyan
      case 'legs':
        return const Color(0xFFCCFF00); // Cyber Lime
      case 'back':
        return const Color(0xFFFF9500); // Neon Amber
      case 'arms':
        return const Color(0xFFAF52DE); // Vivid Violet
      case 'shoulders':
        return const Color(0xFFFFCC00); // Solar Yellow
      case 'core':
        return const Color(0xFF30D158); // Mint Green
      default:
        return const Color(0xFF00E5FF);
    }
  }
}

/// CustomPainter rendering recognizable visual silhouettes of exercise forms
class _ExerciseFigurePainter extends CustomPainter {
  final String exerciseId;
  final String muscleGroup;
  final Color accentColor;

  _ExerciseFigurePainter({
    required this.exerciseId,
    required this.muscleGroup,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paintPrimary = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paintFill = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final paintSubtle = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    if (muscleGroup == 'chest') {
      // Bench press / Pushup / Fly movement illustration
      // 1. Horizontal / Incline bench line
      canvas.drawLine(Offset(w * 0.15, h * 0.72), Offset(w * 0.85, h * 0.72), paintSubtle);
      // Bench support legs
      canvas.drawLine(Offset(w * 0.25, h * 0.72), Offset(w * 0.25, h * 0.95), paintSubtle);
      canvas.drawLine(Offset(w * 0.75, h * 0.72), Offset(w * 0.75, h * 0.95), paintSubtle);
      // Torso lying down
      canvas.drawLine(Offset(w * 0.25, h * 0.65), Offset(w * 0.65, h * 0.65), paintPrimary);
      // Head
      canvas.drawCircle(Offset(w * 0.2, h * 0.62), w * 0.08, paintFill);
      // Arms pressing upward
      canvas.drawLine(Offset(w * 0.45, h * 0.65), Offset(w * 0.45, h * 0.35), paintPrimary);
      // Barbell bar across top
      canvas.drawLine(Offset(w * 0.25, h * 0.32), Offset(w * 0.85, h * 0.32), paintPrimary);
      // Weight plates
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.28, h * 0.32), width: 3.5, height: h * 0.32), const Radius.circular(2)),
        paintFill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.82, h * 0.32), width: 3.5, height: h * 0.32), const Radius.circular(2)),
        paintFill,
      );
    } else if (muscleGroup == 'legs') {
      // Squat / Leg Press movement illustration
      // Head
      canvas.drawCircle(Offset(w * 0.5, h * 0.18), w * 0.09, paintFill);
      // Barbell on shoulders
      canvas.drawLine(Offset(w * 0.18, h * 0.28), Offset(w * 0.82, h * 0.28), paintPrimary);
      // Weight plates
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.22, h * 0.28), width: 3.5, height: h * 0.34), const Radius.circular(2)),
        paintFill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.78, h * 0.28), width: 3.5, height: h * 0.34), const Radius.circular(2)),
        paintFill,
      );
      // Torso tilted forward
      canvas.drawLine(Offset(w * 0.5, h * 0.28), Offset(w * 0.42, h * 0.55), paintPrimary);
      // Thighs (squatted angle)
      canvas.drawLine(Offset(w * 0.42, h * 0.55), Offset(w * 0.68, h * 0.58), paintPrimary);
      // Shins down to feet
      canvas.drawLine(Offset(w * 0.68, h * 0.58), Offset(w * 0.58, h * 0.88), paintPrimary);
      // Foot
      canvas.drawLine(Offset(w * 0.55, h * 0.88), Offset(w * 0.72, h * 0.88), paintSubtle);
    } else if (muscleGroup == 'back') {
      // Lat Pulldown / Bent over row movement illustration
      // Overhead cable bar
      canvas.drawLine(Offset(w * 0.18, h * 0.2), Offset(w * 0.82, h * 0.2), paintPrimary);
      // Cable line up to top pulley
      canvas.drawLine(Offset(w * 0.5, h * 0.05), Offset(w * 0.5, h * 0.2), paintSubtle);
      // Head
      canvas.drawCircle(Offset(w * 0.5, h * 0.38), w * 0.09, paintFill);
      // Torso V-taper
      final path = Path()
        ..moveTo(w * 0.36, h * 0.48)
        ..lineTo(w * 0.64, h * 0.48)
        ..lineTo(w * 0.56, h * 0.85)
        ..lineTo(w * 0.44, h * 0.85)
        ..close();
      canvas.drawPath(path, paintFill..color = accentColor.withValues(alpha: 0.3));
      // Arms reaching up to bar
      canvas.drawLine(Offset(w * 0.36, h * 0.48), Offset(w * 0.24, h * 0.22), paintPrimary);
      canvas.drawLine(Offset(w * 0.64, h * 0.48), Offset(w * 0.76, h * 0.22), paintPrimary);
    } else if (muscleGroup == 'shoulders') {
      // Overhead Shoulder Press / Lateral Raise illustration
      // Head
      canvas.drawCircle(Offset(w * 0.5, h * 0.35), w * 0.09, paintFill);
      // Torso upright
      canvas.drawLine(Offset(w * 0.5, h * 0.44), Offset(w * 0.5, h * 0.82), paintPrimary);
      // Arms reaching up & overhead dumbbells
      canvas.drawLine(Offset(w * 0.5, h * 0.48), Offset(w * 0.25, h * 0.32), paintPrimary);
      canvas.drawLine(Offset(w * 0.25, h * 0.32), Offset(w * 0.25, h * 0.18), paintPrimary);
      canvas.drawLine(Offset(w * 0.5, h * 0.48), Offset(w * 0.75, h * 0.32), paintPrimary);
      canvas.drawLine(Offset(w * 0.75, h * 0.32), Offset(w * 0.75, h * 0.18), paintPrimary);
      // Left dumbbell
      canvas.drawCircle(Offset(w * 0.25, h * 0.14), w * 0.07, paintFill);
      canvas.drawCircle(Offset(w * 0.25, h * 0.22), w * 0.07, paintFill);
      // Right dumbbell
      canvas.drawCircle(Offset(w * 0.75, h * 0.14), w * 0.07, paintFill);
      canvas.drawCircle(Offset(w * 0.75, h * 0.22), w * 0.07, paintFill);
    } else if (muscleGroup == 'arms') {
      // Bicep curl / Tricep flex figure
      // Head
      canvas.drawCircle(Offset(w * 0.35, h * 0.25), w * 0.09, paintFill);
      // Torso
      canvas.drawLine(Offset(w * 0.35, h * 0.34), Offset(w * 0.35, h * 0.78), paintPrimary);
      // Upper arm hanging
      canvas.drawLine(Offset(w * 0.35, h * 0.42), Offset(w * 0.55, h * 0.55), paintPrimary);
      // Forearm curled up towards shoulder
      canvas.drawLine(Offset(w * 0.55, h * 0.55), Offset(w * 0.52, h * 0.32), paintPrimary);
      // Dumbbell in curled hand
      canvas.drawCircle(Offset(w * 0.52, h * 0.26), w * 0.07, paintFill);
      canvas.drawCircle(Offset(w * 0.52, h * 0.38), w * 0.07, paintFill);
      canvas.drawLine(Offset(w * 0.52, h * 0.26), Offset(w * 0.52, h * 0.38), paintSubtle);
    } else {
      // Core / Abdominal Crunch illustration
      // Mat / floor
      canvas.drawLine(Offset(w * 0.12, h * 0.85), Offset(w * 0.88, h * 0.85), paintSubtle);
      // Bent knees
      canvas.drawLine(Offset(w * 0.45, h * 0.85), Offset(w * 0.65, h * 0.55), paintPrimary);
      canvas.drawLine(Offset(w * 0.65, h * 0.55), Offset(w * 0.78, h * 0.85), paintPrimary);
      // Torso curling up
      canvas.drawLine(Offset(w * 0.45, h * 0.85), Offset(w * 0.28, h * 0.6), paintPrimary);
      // Head
      canvas.drawCircle(Offset(w * 0.22, h * 0.52), w * 0.09, paintFill);
      // Hands behind head
      canvas.drawLine(Offset(w * 0.28, h * 0.6), Offset(w * 0.18, h * 0.52), paintSubtle);
    }
  }

  @override
  bool shouldRepaint(covariant _ExerciseFigurePainter oldDelegate) {
    return oldDelegate.exerciseId != exerciseId ||
        oldDelegate.muscleGroup != muscleGroup ||
        oldDelegate.accentColor != accentColor;
  }
}
