import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../services/ride_controller.dart';
import '../services/shortcuts_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../theme/theme_selector_sheet.dart';

class SettingsScreen extends StatelessWidget {
  final RideController controller;
  final ThemeController themeController;
  final LocaleController localeController;

  const SettingsScreen({
    super.key,
    required this.controller,
    required this.themeController,
    required this.localeController,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeController, localeController, controller]),
      builder: (context, _) {
        final theme = themeController.currentTheme;
        final strings = localeController.strings;
        final topInset = MediaQuery.of(context).padding.top;
        final bottomInset = MediaQuery.of(context).padding.bottom;

        return Directionality(
          textDirection: localeController.textDirection,
          child: Scaffold(
            backgroundColor: theme.background,
            extendBodyBehindAppBar: true,
            body: Stack(
            children: [
              // Scrollable Settings Content
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, topInset + 76, 16, bottomInset + 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Language Section
                    _buildSectionHeader(
                      icon: Icons.language_rounded,
                      title: strings.settingsLanguageSection,
                      subtitle: strings.settingsLanguageSubtitle,
                      theme: theme,
                    ),
                    const SizedBox(height: 10),
                    _buildLanguageSelector(theme, strings),

                    const SizedBox(height: 24),

                    // 2. Appearance & Theme Section
                    _buildSectionHeader(
                      icon: Icons.palette_outlined,
                      title: strings.settingsThemeSection,
                      subtitle: strings.settingsThemeSubtitle,
                      theme: theme,
                    ),
                    const SizedBox(height: 10),
                    _buildThemeCard(context, theme, strings),

                    const SizedBox(height: 24),

                    // 3. Apple Shortcuts & NFC Automation Section
                    _buildSectionHeader(
                      icon: Icons.nfc_rounded,
                      title: strings.settingsShortcutsSection,
                      subtitle: strings.settingsShortcutsSubtitle,
                      theme: theme,
                    ),
                    const SizedBox(height: 10),
                    _buildShortcutsCard(context, theme, strings),

                    const SizedBox(height: 24),

                    // 4. Hydration & Rest Reminder
                    _buildSectionHeader(
                      icon: Icons.water_drop_outlined,
                      title: strings.settingsReminderSection,
                      subtitle: strings.settingsReminderSubtitle,
                      theme: theme,
                    ),
                    const SizedBox(height: 10),
                    _buildReminderCard(theme, strings),

                    const SizedBox(height: 24),

                    // 5. Cloud Sync & Diagnostics
                    _buildSectionHeader(
                      icon: Icons.cloud_done_outlined,
                      title: strings.settingsCloudSection,
                      subtitle: strings.settingsCloudSubtitle,
                      theme: theme,
                    ),
                    const SizedBox(height: 10),
                    _buildCloudDiagnosticsCard(context, theme, strings),

                    const SizedBox(height: 24),

                    // 6. Registered Bike Specs
                    _buildSectionHeader(
                      icon: Icons.directions_bike_rounded,
                      title: strings.settingsBikeSection,
                      subtitle: strings.myBikeSpecs,
                      theme: theme,
                    ),
                    const SizedBox(height: 10),
                    _buildBikeCard(theme, strings),

                    const SizedBox(height: 20),

                    // App Version Footer
                    Center(
                      child: Text(
                        strings.appVersion,
                        style: TextStyle(
                          color: theme.textSecondary.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Floating Frosted Glass Header
              Positioned(
                top: topInset + 8,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.surface.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.cardBorder),
                          ),
                          child: IconButton(
                            icon: Transform.flip(
                              flipX: Directionality.of(context) == TextDirection.rtl,
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: theme.textPrimary,
                                size: 18,
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ),
                    ),

                    // Title Pill
                    Expanded(
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.surface.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: theme.cardBorder),
                              ),
                              child: Text(
                                strings.settingsTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required AppThemeTokens theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: theme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.primary, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(AppThemeTokens theme, AppStrings strings) {
    final isArabic = localeController.isArabic;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          // Arabic Egyptian Button
          Expanded(
            child: GestureDetector(
              onTap: () => localeController.setLanguage(AppLanguage.arabicEgyptian),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isArabic ? theme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isArabic
                      ? [
                          BoxShadow(
                            color: theme.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    strings.langArabic,
                    style: TextStyle(
                      color: isArabic ? theme.onPrimary : theme.textSecondary,
                      fontSize: 13,
                      fontWeight: isArabic ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // English Button
          Expanded(
            child: GestureDetector(
              onTap: () => localeController.setLanguage(AppLanguage.english),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isArabic ? theme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: !isArabic
                      ? [
                          BoxShadow(
                            color: theme.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    strings.langEnglish,
                    style: TextStyle(
                      color: !isArabic ? theme.onPrimary : theme.textSecondary,
                      fontSize: 13,
                      fontWeight: !isArabic ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context, AppThemeTokens theme, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                // Theme color dots preview
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDot(theme.surface, theme.cardBorder),
                      const SizedBox(width: 4),
                      _buildDot(theme.primary, theme.cardBorder),
                      const SizedBox(width: 4),
                      _buildDot(theme.secondary, theme.cardBorder),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              strings.themeName(theme.mode),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (theme.mode == AppThemeMode.galaxyRl600h) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.primary.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: theme.primary.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                strings.bikeBadge,
                                style: TextStyle(
                                  color: theme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.themeSubtitle(theme.mode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              ThemeSelectorSheet.show(context, themeController,
                  localeController: localeController);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary.withValues(alpha: 0.15),
              foregroundColor: theme.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: theme.primary.withValues(alpha: 0.3)),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                strings.changeThemeButton,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(Color color, Color border) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1),
      ),
    );
  }

  Widget _buildShortcutsCard(BuildContext context, AppThemeTokens theme, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shortcut 1: Start Ride (probike://start)
          _buildShortcutRow(
            context: context,
            icon: Icons.play_arrow_rounded,
            iconColor: theme.primary,
            title: strings.shortcutStartTitle,
            subtitle: strings.shortcutStartDesc,
            scheme: ShortcutsService.schemeStart,
            theme: theme,
            onSetup: () {
              _showShortcutSetupModal(
                context,
                theme,
                strings,
                ShortcutsService.schemeStart,
                strings.shortcutTwoStepDesc,
              );
            },
            strings: strings,
          ),

          const SizedBox(height: 14),
          Divider(color: theme.cardBorder, height: 1),
          const SizedBox(height: 14),

          // Shortcut 2: Stop Ride (probike://stop)
          _buildShortcutRow(
            context: context,
            icon: Icons.stop_rounded,
            iconColor: theme.error,
            title: strings.shortcutStopTitle,
            subtitle: strings.shortcutStopDesc,
            scheme: ShortcutsService.schemeStop,
            theme: theme,
            onSetup: () {
              _showShortcutSetupModal(
                context,
                theme,
                strings,
                ShortcutsService.schemeStop,
                strings.shortcutStopTwoStepDesc,
              );
            },
            strings: strings,
          ),

          const SizedBox(height: 16),

          // 10-Second NFC Guide Button
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showNfcGuideDialog(context, theme, strings);
            },
            icon: Icon(Icons.help_outline_rounded, color: theme.primary, size: 16),
            label: Text(
              strings.nfcGuideButton,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: theme.primary.withValues(alpha: 0.35)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String scheme,
    required AppThemeTokens theme,
    required VoidCallback onSetup,
    required AppStrings strings,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: iconColor.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: theme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Copy link directly button
        IconButton(
          tooltip: strings.copyStartLinkBtn,
          icon: Icon(Icons.copy_rounded, color: theme.textSecondary, size: 16),
          onPressed: () async {
            await ShortcutsService.copySchemeToClipboard(scheme);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${strings.linkCopiedSnackbar} ($scheme)'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: theme.primary,
                ),
              );
            }
          },
          style: IconButton.styleFrom(
            backgroundColor: theme.surfaceContainer,
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(36, 36),
          ),
        ),
        const SizedBox(width: 4),
        // Setup Button
        ElevatedButton(
          onPressed: onSetup,
          style: ElevatedButton.styleFrom(
            backgroundColor: iconColor,
            foregroundColor: (iconColor == theme.primary && theme.mode == AppThemeMode.classicNeon)
                ? Colors.black
                : Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            strings.installShortcutBtn,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  void _showShortcutSetupModal(
    BuildContext context,
    AppThemeTokens theme,
    AppStrings strings,
    String scheme,
    String description,
  ) async {
    // 1. Auto-copy URL to Clipboard
    await ShortcutsService.copySchemeToClipboard(scheme);

    // 2. Open Shortcuts app
    ShortcutsService.openShortcutsApp(createNew: true);

    if (!context.mounted) return;

    // 3. Show Fast 2-step modal dialog in Egyptian cycling slang
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: localeController.textDirection,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AlertDialog(
          backgroundColor: theme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: theme.cardBorder),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.flash_on_rounded, color: theme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.shortcutCopiedModalTitle,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: theme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        scheme,
                        style: TextStyle(
                          color: theme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                description,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                ShortcutsService.copySchemeToClipboard(scheme);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(strings.linkCopiedSnackbar),
                    duration: const Duration(seconds: 2),
                    backgroundColor: theme.primary,
                  ),
                );
              },
              icon: Icon(Icons.copy_rounded, size: 16, color: theme.primary),
              label: Text(
                strings.copyStartLinkBtn,
                style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: theme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                strings.nfcGuideDone,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildReminderCard(AppThemeTokens theme, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timer_outlined, color: Color(0xFF00E676), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.reminderIntervalText(controller.reminderIntervalMinutes),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.reminderRangeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              // Minus 5
              IconButton.filledTonal(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  controller.updateReminderIntervalDelta(-5);
                },
                style: IconButton.styleFrom(
                  backgroundColor: theme.surfaceContainer,
                  foregroundColor: theme.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 6),
              // Plus 5
              IconButton.filledTonal(
                icon: const Icon(Icons.add, size: 16),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  controller.updateReminderIntervalDelta(5);
                },
                style: IconButton.styleFrom(
                  backgroundColor: theme.surfaceContainer,
                  foregroundColor: theme.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCloudDiagnosticsCard(
      BuildContext context, AppThemeTokens theme, AppStrings strings) {
    final pendingCount = controller.pendingSyncCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  strings.cloudStatusConnected,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: pendingCount > 0
                        ? Colors.amber.withValues(alpha: 0.15)
                        : const Color(0xFF0D381E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      strings.pendingSyncCountText(pendingCount),
                      style: TextStyle(
                        color: pendingCount > 0 ? Colors.amber : const Color(0xFF00E676),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Force Sync
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await controller.syncPendingRides();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF1B5E20),
                        content: Text(
                          strings.syncSuccessSnackbar,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: Text(strings.syncNowButton, style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: theme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBikeCard(AppThemeTokens theme, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.directions_bike_rounded, color: theme.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.myBikeModel,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.myBikeSpecs,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNfcGuideDialog(BuildContext context, AppThemeTokens theme, AppStrings strings) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Directionality(
          textDirection: localeController.textDirection,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: theme.cardBorder),
            ),
            title: Row(
              children: [
                Icon(Icons.nfc_rounded, color: theme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.nfcGuideTitle,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGuideStep(strings.nfcStep1, theme),
                  const SizedBox(height: 12),
                  _buildGuideStep(strings.nfcStep2, theme),
                  const SizedBox(height: 12),
                  _buildGuideStep(strings.nfcStep3, theme),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: theme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  strings.nfcGuideDone,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildGuideStep(String stepText, AppThemeTokens theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Text(
        stepText,
        style: TextStyle(
          color: theme.textPrimary,
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
