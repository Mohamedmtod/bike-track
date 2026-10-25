import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../models/ride_model.dart';
import '../services/ride_controller.dart';
import '../theme/theme_controller.dart';
import '../theme/theme_selector_sheet.dart';
import 'live_ride_screen.dart';
import 'ride_details_screen.dart';
import 'settings_screen.dart';

/// Manual ride entry dialog for adding missed/lost rides.

class DashboardScreen extends StatelessWidget {
  final RideController controller;
  final ThemeController? themeController;
  final LocaleController? localeController;

  const DashboardScreen({
    super.key,
    required this.controller,
    this.themeController,
    this.localeController,
  });

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveThemeController =
        themeController ?? ThemeController(autoLoad: false);
    final effectiveLocaleController =
        localeController ?? LocaleController(autoLoad: false);
    final listenable =
        Listenable.merge([controller, effectiveThemeController, effectiveLocaleController]);

    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final theme = effectiveThemeController.currentTheme;
        final strings = effectiveLocaleController.strings;
        final oledBlack = theme.background;
        final cardSurface = theme.surface;
        final neonLime = theme.primary;
        final cardBorder = theme.cardBorder;

        final topPadding = MediaQuery.of(context).padding.top + 12;
        final bottomPadding = MediaQuery.of(context).padding.bottom + 16;

        return Scaffold(
          backgroundColor: oledBlack,
          body: Stack(
            children: [
              // Scrollable Content
              RefreshIndicator(
                color: neonLime,
                backgroundColor: cardSurface,
                onRefresh: () => controller.fetchHistory(),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    topPadding,
                    16,
                    bottomPadding + 76,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // iOS Pro Header (Dynamic Island Safe)
                      _buildHeader(neonLime, context, effectiveThemeController,
                          effectiveLocaleController),

                      const SizedBox(height: 16),

                      // Active Ride Banner (if currently tracking)
                      if (controller.isRiding) ...[
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    LiveRideScreen(
                                      controller: controller,
                                      themeController: effectiveThemeController,
                                      localeController: effectiveLocaleController,
                                    ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0D381E), Color(0xFF1B5E20)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: neonLime.withValues(alpha: 0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: neonLime.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: neonLime,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    strings.activeRideBanner,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios,
                                    color: Colors.white70, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // 1. Today's Hero Card (OLED Fitness+ Style)
                      _buildTodayHeroCard(
                          neonLime, cardSurface, cardBorder, context, strings),

                      const SizedBox(height: 16),

                      // 2. Weekly Overview Card (Last 7 Days)
                      _buildWeeklyOverviewCard(
                          neonLime, cardSurface, cardBorder, strings),

                      const SizedBox(height: 16),

                      // 3. Reminder Interval Control Card
                      _buildReminderCard(neonLime, cardSurface, cardBorder, strings),

                      const SizedBox(height: 24),

                      // 4. Recent Rides History Header (Overflow-proof)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              strings.ridesHistoryTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          // Manual ride entry button
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showAddManualRideDialog(context, controller, neonLime, cardSurface, cardBorder, strings);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: neonLime.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: neonLime.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_circle_outline, color: neonLime, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    strings.addManualRideButton,
                                    style: TextStyle(
                                      color: neonLime,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: cardSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Text(
                              strings.ridesCount(controller.ridesHistory.length),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Rides List
                      _buildRidesList(
                          cardSurface, cardBorder, neonLime, effectiveThemeController, effectiveLocaleController, strings),
                    ],
                  ),
                ),
              ),

              // Fixed Bottom Action Bar (Home Indicator Safe)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        oledBlack.withValues(alpha: 0.0),
                        oledBlack.withValues(alpha: 0.85),
                        oledBlack,
                      ],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      HapticFeedback.heavyImpact();
                      if (!controller.isRiding) {
                        final started = await controller.startRide();
                        if (!started && !controller.isRiding) {
                          return;
                        }
                      }
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LiveRideScreen(
                            controller: controller,
                            themeController: effectiveThemeController,
                            localeController: effectiveLocaleController,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: neonLime,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(56),
                      elevation: 10,
                      shadowColor: neonLime.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.pedal_bike,
                              color: Colors.black, size: 26),
                          const SizedBox(width: 10),
                          Text(
                            controller.isRiding
                                ? strings.startRideButtonRiding
                                : strings.startRideButtonIdle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
      Color neonLime,
      BuildContext context,
      ThemeController effectiveThemeController,
      LocaleController effectiveLocaleController) {
    final theme = effectiveThemeController.currentTheme;
    final strings = effectiveLocaleController.strings;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: neonLime.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: neonLime.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.directions_bike, color: neonLime, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROBIKE',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'CYCLING COMPANION PRO',
                      style: TextStyle(
                        color: neonLime.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('settings_button'),
          icon: Icon(Icons.settings_outlined, color: theme.textSecondary),
          tooltip: strings.settingsTitle,
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  controller: controller,
                  themeController: effectiveThemeController,
                  localeController: effectiveLocaleController,
                ),
              ),
            );
          },
        ),
        IconButton(
          key: const Key('theme_palette_button'),
          icon: Icon(Icons.palette_outlined, color: theme.textSecondary),
          tooltip: strings.settingsThemeSection,
          onPressed: () {
            HapticFeedback.lightImpact();
            ThemeSelectorSheet.show(context, effectiveThemeController,
                localeController: effectiveLocaleController);
          },
        ),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: theme.textSecondary),
          tooltip: strings.syncNowButton,
          onPressed: () {
            HapticFeedback.lightImpact();
            controller.fetchHistory();
          },
        ),
      ],
    );
  }

  Widget _buildTodayHeroCard(
      Color neonLime, Color cardSurface, Color cardBorder, BuildContext context, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: neonLime.withValues(alpha: 0.06),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: neonLime,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  strings.todayHeroTitle,
                  style: TextStyle(
                    color: neonLime,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: neonLime.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('EEE, d MMM').format(DateTime.now()),
                    style: TextStyle(
                      color: neonLime,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Big Glowing Number with FittedBox & Tabular Figures
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  controller.todayDistanceKm.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'KM',
                  style: TextStyle(
                    color: Color(0xFFCCFF00),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0F17),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _buildHeroSubStat(
                    Icons.timer_outlined,
                    strings.metricTotalTime,
                    _formatDuration(controller.todayDurationSeconds),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: cardBorder,
                ),
                Expanded(
                  child: _buildHeroSubStat(
                    Icons.bolt_rounded,
                    strings.metricMaxSpeed,
                    strings.speedValue(controller.todayMaxSpeedKmh),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSubStat(IconData icon, String label, String value) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white38, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyOverviewCard(
      Color neonLime, Color cardSurface, Color cardBorder, AppStrings strings) {
    final dailyStats = controller.weeklyDailyStats;
    double maxKm = 1.0;
    for (final s in dailyStats) {
      if (s.distanceKm > maxKm) maxKm = s.distanceKm;
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.weeklyOverviewTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    strings.weeklySummary(
                        controller.weeklyDistanceKm.toStringAsFixed(1),
                        controller.weeklyRidesCount),
                    style: const TextStyle(
                      color: Color(0xFFCCFF00),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 7-day Bar Chart
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dailyStats.map((stat) {
                final ratio = (stat.distanceKm / maxKm).clamp(0.06, 1.0);
                final isToday = stat.date.day == DateTime.now().day &&
                    stat.date.month == DateTime.now().month &&
                    stat.date.year == DateTime.now().year;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (stat.distanceKm > 0)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              stat.distanceKm.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 80 * ratio,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: stat.distanceKm > 0
                                    ? (isToday
                                        ? neonLime
                                        : neonLime.withValues(alpha: 0.6))
                                    : const Color(0xFF222634),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: stat.distanceKm > 0 && isToday
                                    ? [
                                        BoxShadow(
                                          color:
                                              neonLime.withValues(alpha: 0.4),
                                          blurRadius: 10,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('E').format(stat.date).substring(0, 2),
                          style: TextStyle(
                            color: isToday ? neonLime : Colors.white38,
                            fontSize: 11,
                            fontWeight:
                                isToday ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(
      Color neonLime, Color cardSurface, Color cardBorder, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: neonLime.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.notifications_active, color: neonLime, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        strings.reminderNotificationCardTitle(controller.reminderMinutes),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.reminderNotificationCardSubtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    controller.changeReminderMinutes(-5);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cardBorder),
                    backgroundColor: const Color(0xFF0D0F17),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    strings.reminderDecrease,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    controller.changeReminderMinutes(5);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: neonLime.withValues(alpha: 0.18),
                    foregroundColor: neonLime,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: neonLime.withValues(alpha: 0.4)),
                    ),
                  ),
                  child: Text(
                    strings.reminderIncrease,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRidesList(Color cardSurface, Color cardBorder, Color neonLime,
      ThemeController effectiveThemeController, LocaleController effectiveLocaleController, AppStrings strings) {
    if (controller.isLoadingHistory) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: CircularProgressIndicator(color: neonLime),
        ),
      );
    }

    if (controller.ridesHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          children: [
            Icon(Icons.directions_bike_outlined,
                color: Colors.white.withValues(alpha: 0.25), size: 48),
            const SizedBox(height: 12),
            Text(
              strings.emptyHistoryTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.emptyHistorySubtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: controller.ridesHistory.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ride = controller.ridesHistory[index];
        return _buildDismissibleRideCard(
            context, ride, cardSurface, cardBorder, neonLime, effectiveThemeController, effectiveLocaleController, strings);
      },
    );
  }

  Widget _buildDismissibleRideCard(
    BuildContext context,
    RideModel ride,
    Color cardSurface,
    Color cardBorder,
    Color neonLime,
    ThemeController effectiveThemeController,
    LocaleController effectiveLocaleController,
    AppStrings strings,
  ) {
    const stopRed = Color(0xFFFF2D55);
    final deleteBackground = Container(
      decoration: BoxDecoration(
        color: stopRed,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 8),
          Text(
            strings.deleteDialogConfirm,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );

    final secondaryDeleteBackground = Container(
      decoration: BoxDecoration(
        color: stopRed,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strings.deleteDialogConfirm,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 26),
        ],
      ),
    );

    return Dismissible(
      key: Key('ride_${ride.clientId}'),
      direction: DismissDirection.horizontal,
      background: deleteBackground,
      secondaryBackground: secondaryDeleteBackground,
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        return await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: const Color(0xFF14161F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            title: Row(
              children: [
                const Icon(Icons.delete_outline_rounded, color: stopRed, size: 22),
                const SizedBox(width: 8),
                Text(
                  strings.deleteDialogTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Text(
              strings.deleteDialogBody,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(
                  strings.deleteDialogCancel,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: stopRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  strings.deleteDialogConfirm,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await controller.deleteRide(ride.clientId, ride.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF14161F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF00E676), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    strings.deleteSuccessSnackbar,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RideDetailsScreen(
                ride: ride,
                themeController: effectiveThemeController,
                localeController: effectiveLocaleController,
              ),
            ),
          );
        },
        child: _buildRideHistoryCard(ride, cardSurface, cardBorder, neonLime, strings),
      ),
    );
  }

  Widget _buildRideHistoryCard(RideModel ride, Color cardSurface,
      Color cardBorder, Color neonLime, AppStrings strings) {
    final distanceKm = ride.distanceMeters / 1000.0;
    final dateFormatted =
        DateFormat('yyyy/MM/dd • hh:mm a').format(ride.startTime.toLocal());
    final isPending = ride.syncStatus == SyncStatus.pending;
    final isManual = ride.isManual;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isPending)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.cloud_upload_outlined,
                            color: Colors.amber.withValues(alpha: 0.7), size: 14),
                      ),
                    if (isManual)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.edit_note_rounded,
                            color: neonLime.withValues(alpha: 0.6), size: 14),
                      ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        dateFormatted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0F17),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cardBorder),
                ),
                child: Text(
                  _formatDuration(ride.durationSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Text(
                  distanceKm.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  strings.kmUnit,
                  style: const TextStyle(
                    color: Color(0xFFCCFF00),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0F17),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildStatColumn(
                      strings.avgMetricShort, strings.speedValue(ride.avgSpeedKmh)),
                ),
                Expanded(
                  child: _buildStatColumn(
                      strings.maxMetricShort, strings.speedValue(ride.maxSpeedKmh)),
                ),
                Expanded(
                  child: _buildStatColumn(
                      strings.minMetricShort, strings.speedValue(ride.minSpeedKmh)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddManualRideDialog(
    BuildContext context,
    RideController controller,
    Color neonLime,
    Color cardSurface,
    Color cardBorder,
    AppStrings strings,
  ) {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    final hoursController = TextEditingController(text: '0');
    final minutesController = TextEditingController(text: '0');
    final distanceController = TextEditingController(text: '0.0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.edit_note_rounded, color: neonLime, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          strings.addManualRideDialogTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.addManualRideDialogSubtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: neonLime,
                                  onPrimary: Colors.black,
                                  surface: cardSurface,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: _buildDialogField(
                        icon: Icons.calendar_today,
                        label: strings.dateLabel,
                        value: DateFormat('yyyy/MM/dd').format(selectedDate),
                        neonLime: neonLime,
                        cardBorder: cardBorder,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Time picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: neonLime,
                                  onPrimary: Colors.black,
                                  surface: cardSurface,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setModalState(() => selectedTime = picked);
                        }
                      },
                      child: _buildDialogField(
                        icon: Icons.access_time,
                        label: strings.startTimeLabel,
                        value: selectedTime.format(context),
                        neonLime: neonLime,
                        cardBorder: cardBorder,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Duration (hours + minutes)
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialogTextField(
                            controller: hoursController,
                            label: strings.hoursLabel,
                            icon: Icons.timer_outlined,
                            neonLime: neonLime,
                            cardBorder: cardBorder,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDialogTextField(
                            controller: minutesController,
                            label: strings.minutesLabel,
                            icon: Icons.timer_outlined,
                            neonLime: neonLime,
                            cardBorder: cardBorder,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Distance
                    _buildDialogTextField(
                      controller: distanceController,
                      label: strings.distanceKmLabel,
                      icon: Icons.straighten,
                      neonLime: neonLime,
                      cardBorder: cardBorder,
                      isDecimal: true,
                    ),
                    const SizedBox(height: 20),

                    // Submit button
                    ElevatedButton(
                      onPressed: () {
                        final hours = int.tryParse(hoursController.text) ?? 0;
                        final mins = int.tryParse(minutesController.text) ?? 0;
                        final distKm = double.tryParse(distanceController.text) ?? 0.0;
                        final totalSeconds = (hours * 3600) + (mins * 60);

                        if (totalSeconds <= 0 || distKm <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(strings.invalidRideInputError),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                          return;
                        }

                        final rideStart = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );

                        controller.addManualRide(
                          startTime: rideStart,
                          durationSeconds: totalSeconds,
                          distanceMeters: distKm * 1000.0,
                        );

                        Navigator.of(ctx).pop();
                        HapticFeedback.mediumImpact();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: neonLime,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        strings.saveRideButton,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogField({
    required IconData icon,
    required String label,
    required String value,
    required Color neonLime,
    required Color cardBorder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F17),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: neonLime, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const Spacer(),
          Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 18),
        ],
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color neonLime,
    required Color cardBorder,
    bool isDecimal = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F17),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: neonLime, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
