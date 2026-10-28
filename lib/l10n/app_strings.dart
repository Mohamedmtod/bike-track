import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppLanguage {
  arabicEgyptian,
  english,
}

class AppStrings {
  final AppLanguage language;

  const AppStrings(this.language);

  bool get isArabic => language == AppLanguage.arabicEgyptian;

  // --- General & Brand ---
  String get appName => 'ProBike';
  String get appSubtitle => isArabic ? 'رفيقك الاحترافي لركوب الدراجة' : 'CYCLING COMPANION PRO';
  String get myBikeModel => 'Galaxy RL600H Hybrid';
  String get myBikeSpecs => isArabic
      ? 'هيكل ألومنيوم تيتانيوم • ناقل سرعات شيمانو 3x7 • قفل ممتص الصدمات'
      : 'Alloy Titanium Frame • Shimano Tourney 3x7 • Suspension Lockout';
  String get appVersion => 'ProBike v1.1.0 (Build 2)';
  String get bikeBadge => isArabic ? 'دراجتي' : 'My Bike';
  String get desktopPreviewLabel =>
      isArabic ? 'معاينة شاشة الهاتف (393 × 852)' : 'iPhone 14 Pro Preview (393 × 852)';

  String themeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.galaxyRl600h:
        return 'Galaxy RL600H';
      case AppThemeMode.classicNeon:
        return isArabic ? 'النيون الكلاسيكي' : 'ProBike Classic';
      case AppThemeMode.editorialAubergine:
        return isArabic ? 'الباذنجاني الهادئ' : 'Editorial Aubergine';
    }
  }

  String themeSubtitle(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.galaxyRl600h:
        return isArabic
            ? 'تيتانيوم رياضي • مستوحى من دراجتك'
            : 'Titanium Sport • Inspired by your bike';
      case AppThemeMode.classicNeon:
        return isArabic
            ? 'نيون كلاسيكي • تباين فائق'
            : 'Neon Lime Cyber • High contrast';
      case AppThemeMode.editorialAubergine:
        return isArabic
            ? 'عاجي دافئ وباذنجاني • تصميم هادئ وراقٍ'
            : 'Warm Ivory & Plum • Refined design';
    }
  }

  // --- Dashboard Screen ---
  String get headerGreeting => isArabic ? 'أهلاً بك! 🚴‍♂️' : 'Welcome back, Rider! 🚴‍♂️';
  String get headerSubtitle => isArabic ? 'هل أنت جاهز لرحلة جديدة اليوم؟' : 'Ready to crush a new ride today?';
  String get todayHeroTitle => isArabic ? 'نشاط اليوم' : "Today's Activity";
  String get weeklyOverviewTitle => isArabic ? 'نظرة أسبوعية (آخر 7 أيام)' : 'Weekly Overview (Last 7 Days)';
  String weeklySummary(String distanceKm, int count) => isArabic
      ? '$count رحلات • $distanceKm كم'
      : '$distanceKm km • $count rides';
  String get activeRideBanner => isArabic
      ? 'الرحلة جارية الآن • اضغط للعودة إلى شاشة العداد'
      : 'Ride in progress right now • Tap for cockpit';
  String get startRideButtonIdle => isArabic ? 'بدء الرحلة' : 'Start Ride';
  String get startRideButtonRiding => isArabic ? 'متابعة الرحلة الحالية' : 'Active Ride (Live View)';
  String get ridesHistoryTitle => isArabic ? 'سجل الرحلات' : 'Ride History';
  String ridesCount(int count) => isArabic ? '$count رحلة' : '$count rides';
  String get emptyHistoryTitle => isArabic ? 'لا توجد رحلات مسجلة بعد' : 'No rides recorded yet!';
  String get emptyHistorySubtitle => isArabic
      ? 'ابدأ أول رحلة لك الآن لتتبع سرعتك ومسافتك!'
      : 'Hop on your bike and start your first ride to track speed & distance!';
  String get syncStatusSynced => isArabic ? 'متزامن سحابياً ☁️' : 'Cloud Synced ☁️';
  String get syncStatusPending => isArabic ? 'قيد المزامنة' : 'Queued for Sync';
  String get manualRideBadge => isArabic ? 'رحلة يدوية' : 'Manual Recovery Ride';
  String get kmUnit => isArabic ? 'كم' : 'km';
  String get kmhUnit => isArabic ? 'كم/س' : 'km/h';
  String get avgMetricShort => isArabic ? 'متوسط' : 'Avg';
  String get maxMetricShort => isArabic ? 'أقصى' : 'Top';
  String get minMetricShort => isArabic ? 'أدنى' : 'Min';

  // --- Dashboard Manual Ride Entry Dialog ---
  String get addManualRideButton => isArabic ? 'إضافة رحلة فائتة' : 'Add Missed Ride';
  String get addManualRideDialogTitle => isArabic ? 'إضافة رحلة يدوياً' : 'Add Missed Ride Manually';
  String get addManualRideDialogSubtitle => isArabic
      ? 'أدخل تفاصيل الرحلة (التاريخ، الوقت، المدة، والمسافة)'
      : 'Enter details of your missed ride (date, time, and distance)';
  String get dateLabel => isArabic ? 'التاريخ' : 'Date';
  String get startTimeLabel => isArabic ? 'وقت البداية' : 'Start Time';
  String get hoursLabel => isArabic ? 'ساعات' : 'Hours';
  String get minutesLabel => isArabic ? 'دقائق' : 'Minutes';
  String get distanceKmLabel => isArabic ? 'المسافة (كم)' : 'Distance (km)';
  String get invalidRideInputError => isArabic ? 'يرجى إدخال مدة ومسافة صحيحة' : 'Please enter valid duration & distance';
  String get saveRideButton => isArabic ? 'حفظ الرحلة' : 'Save Ride';

  // --- Dashboard Reminder Card ---
  String reminderNotificationCardTitle(int minutes) => isArabic
      ? 'تنبيه إيقاف الرحلة: كل $minutes دقيقة'
      : 'Ride reminder: Every $minutes mins';
  String get reminderNotificationCardSubtitle => isArabic
      ? 'تذكير ذكي دوري لضمان إيقاف الرحلة عند الانتهاء'
      : 'Periodic smart reminder to stop ride when finished';

  // --- Swipe-to-Delete Dialog ---
  String get deleteDialogTitle => isArabic ? 'حذف الرحلة' : 'Delete Ride';
  String get deleteDialogBody => isArabic
      ? 'هل أنت متأكد من رغبتك في حذف هذه الرحلة نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'
      : 'Are you sure you want to delete this ride permanently? This action cannot be undone.';
  String get deleteDialogCancel => isArabic ? 'إلغاء' : 'Cancel';
  String get deleteDialogConfirm => isArabic ? 'حذف' : 'Delete';
  String get deleteSuccessSnackbar => isArabic ? 'تم حذف الرحلة بنجاح' : 'Ride deleted successfully';

  // --- Live Ride Cockpit ---
  String get liveTimeElapsed => isArabic ? 'وقت الحركة' : 'Moving Time';
  String get liveCurrentSpeed => isArabic ? 'السرعة الآن' : 'Current Speed';
  String get liveAvgSpeed => isArabic ? 'متوسط السرعة' : 'Avg Speed';
  String get liveDistanceCrushed => isArabic ? 'المسافة' : 'Distance';
  String get liveMaxSpeed => isArabic ? 'أقصى سرعة' : 'Top Speed';
  String get liveMinSpeed => isArabic ? 'أدنى سرعة' : 'Min Speed';
  String get liveFinishButton => isArabic ? 'إنهاء الرحلة' : 'Stop Ride';
  String get livePauseButton => isArabic ? 'إيقاف مؤقت' : 'Pause';
  String get liveResumeButton => isArabic ? 'استئناف' : 'Resume';
  String get liveHoldToStopNotice => isArabic ? 'اضغط مطولاً للإنهاء' : 'Hold to stop';
  String get liveStatusPaused => isArabic ? 'موقوف مؤقتاً' : 'PAUSED';
  String get activeRidePausedBanner => isArabic
      ? 'الرحلة موقوفة مؤقتاً • اضغط للعودة إلى شاشة العداد'
      : 'Ride paused • Tap for cockpit';
  String get recoverRideDialogTitle => isArabic ? 'استعادة رحلة غير مكتملة' : 'Recover Incomplete Ride';
  String get recoverRideDialogBody => isArabic
      ? 'تم العثور على جلسة رحلة سابقة غير مكتملة. هل ترغب في متابعتها أم حفظها في السجل كرحلة منتهية؟'
      : 'An incomplete ride session was found. Would you like to resume it in cockpit or save it to history?';
  String get recoverRideResumeBtn => isArabic ? 'متابعة الرحلة' : 'Resume Ride';
  String get recoverRideFinishBtn => isArabic ? 'حفظ وإنهاء' : 'Save & Finish';
  String get liveRecenterTooltip => isArabic ? 'إعادة التوسيط على الخريطة' : 'Recenter Map';
  String get liveGpsLocked => isArabic ? 'تتبع نظام GPS مباشر' : 'LIVE GPS TRACKING';

  // --- Ride Details Screen ---
  String get rideDetailsTitle => isArabic ? 'تفاصيل الرحلة' : 'Ride Details';
  String get heroDistanceTitle => isArabic ? 'إجمالي المسافة' : 'Total Distance';
  String get metricTotalTime => isArabic ? 'الوقت الإجمالي' : 'Total Duration';
  String get metricAvgSpeed => isArabic ? 'متوسط السرعة' : 'Avg Speed';
  String get metricMaxSpeed => isArabic ? 'أقصى سرعة' : 'Top Speed';
  String get metricMinSpeed => isArabic ? 'أدنى سرعة' : 'Min Speed';
  String get manualRideNotice => isArabic
      ? 'تمت إضافة هذه الرحلة يدوياً كتعويض عن رحلة سابقة غير مسجلة.'
      : 'This ride was added manually as recovery for an unrecorded session.';
  String get manualRideNoMap => isArabic
      ? 'رحلة يدوية - لا توجد بيانات مسار خريطة'
      : 'Manual ride - No GPS route data';
  String get noRoutePointsNotice => isArabic
      ? 'لا تتوفر إحداثيات خريطة لهذه الرحلة'
      : 'No map coordinates available for this ride';

  // --- Settings Screen ---
  String get settingsTitle => isArabic ? 'الإعدادات' : 'Settings';
  
  // Section: Theme
  String get settingsThemeSection => isArabic ? 'مظهر التطبيق' : 'Appearance';
  String get settingsThemeSubtitle => isArabic
      ? 'اختر السمة المفضلة لديك ولدراجتك'
      : 'Choose a theme matching your vibe and rig';
  String get currentThemeLabel => isArabic ? 'السمة الحالية' : 'Active Theme';
  String get changeThemeButton => isArabic ? 'تغيير السمة' : 'Change Theme';

  // Section: Language
  String get settingsLanguageSection => isArabic ? 'لغة التطبيق' : 'App Language';
  String get settingsLanguageSubtitle => isArabic
      ? 'اختر لغة التطبيق المفضلة لديك'
      : 'Choose your preferred language';
  String get langArabic => 'العربية';
  String get langEnglish => 'English';
  String get langArabicEgyptian => langArabic;
  String get langEnglishModern => langEnglish;

  // Section: NFC & Siri Shortcuts
  String get settingsShortcutsSection => isArabic ? 'اختصارات آبل وتقنية NFC ⚡' : 'Apple Shortcuts & NFC ⚡';
  String get settingsShortcutsSubtitle => isArabic
      ? 'إعداد سريع لبدء الرحلات تلقائياً عبر تقنية NFC'
      : 'One-tap setup to launch rides instantly via NFC stickers';
  String get shortcutStartTitle => isArabic ? 'اختصار: بدء الرحلة تلقائياً' : 'Shortcut: Auto-Start Ride';
  String get shortcutStartDesc => isArabic
      ? 'يفتح التطبيق ويبدأ تسجيل الرحلة فوراً'
      : 'Opens ProBike and starts ride immediately';
  String get shortcutStopTitle => isArabic ? 'اختصار: إيقاف وإنهاء الرحلة' : 'Shortcut: Stop & Finish Ride';
  String get shortcutStopDesc => isArabic
      ? 'ينهي الرحلة ويحفظ بياناتها فوراً'
      : 'Stops and saves your ride in seconds';
  String get installShortcutBtn => isArabic ? 'إعداد الاختصار' : 'Setup Shortcut';
  String get copyStartLinkBtn => isArabic ? 'نسخ الرابط' : 'Copy Link';
  String get copyStopLinkBtn => isArabic ? 'نسخ الرابط' : 'Copy Link';
  String get openShortcutsAppBtn => isArabic ? 'فتح تطبيق الاختصارات' : 'Open Shortcuts App';
  String get linkCopiedSnackbar => isArabic ? 'تم نسخ الرابط في الحافظة!' : 'Link copied to clipboard!';
  String get shortcutCopiedModalTitle => isArabic ? 'إعداد الاختصار السريع ⚡' : 'Ready for Instant Shortcuts! ⚡';
  String get shortcutTwoStepDesc => isArabic
      ? 'تم نسخ رابط التشغيل تلقائياً!\n\n١. افتح تطبيق الاختصارات واختر إجراء "فتح العناوين" (Open URLs) والصق الرابط probike://start.\n٢. من تبويب "التحكم التلقائي" اربطه بملصق NFC على دراجتك.'
      : 'URL probike://start copied automatically!\n\n1. In Shortcuts app, add "Open URLs" action and paste the copied link.\n2. In Automation tab, link it to your bike\'s NFC sticker!';
  String get shortcutStopTwoStepDesc => isArabic
      ? 'تم نسخ رابط الإيقاف تلقائياً!\n\n١. افتح تطبيق الاختصارات واختر إجراء "فتح العناوين" (Open URLs) والصق الرابط probike://stop.\n٢. من تبويب "التحكم التلقائي" اربطه بملصق NFC لإنهاء الرحلة فوراً.'
      : 'URL probike://stop copied automatically!\n\n1. In Shortcuts app, add "Open URLs" action and paste the copied link.\n2. Link it to an NFC sticker to stop your ride instantly!';
  String get nfcGuideButton => isArabic ? 'دليل ربط ملصق NFC' : 'How to link to NFC tag? (Guide)';
  String get testDeepLinkBtn => isArabic ? 'تجربة فتح الرابط الآن' : 'Test Deep Link Now';

  // Section: Hydration & Reminder
  String get settingsReminderSection => isArabic ? 'تنبيه شرب الماء والراحة 💧' : 'Hydration & Rest Reminder 💧';
  String get settingsReminderSubtitle => isArabic
      ? 'اهتزاز ذكي ينبهك لشرب الماء والراحة أثناء القيادة'
      : 'Smart haptic pulse reminding you to hydrate while riding';
  String reminderIntervalText(int minutes) => isArabic ? 'كل $minutes دقيقة' : 'Every $minutes minutes';
  String get reminderRangeText => isArabic ? 'نطاق التنبيه: 5 - 180 دقيقة' : 'Range: 5 - 180 minutes';
  String get reminderIncrease => isArabic ? '+ 5 دقائق' : '+ 5 min';
  String get reminderDecrease => isArabic ? '- 5 دقائق' : '- 5 min';
  String speedValue(double speed) => isArabic
      ? '${speed.toStringAsFixed(1)} كم/س'
      : '${speed.toStringAsFixed(1)} km/h';

  // Section: Cloud & Cache Diagnostics
  String get settingsCloudSection => isArabic ? 'المزامنة السحابية ☁️' : 'Cloud Sync & Diagnostics ☁️';
  String get settingsCloudSubtitle => isArabic
      ? 'حالة الاتصال والبيانات المحلية'
      : 'Connection status and offline sync queue';
  String get cloudStatusConnected => isArabic ? 'السحابة متصلة وجاهزة 🟢' : 'Cloud Connected & Live 🟢';
  String pendingSyncCountText(int count) => isArabic
      ? (count == 0 ? 'جميع الرحلات متزامنة سحابياً' : 'رحلات بانتظار المزامنة: $count')
      : (count == 0 ? 'All rides cloud synced' : 'Pending offline rides: $count');
  String get syncNowButton => isArabic ? 'مزامنة السحابة الآن' : 'Sync With Cloud Now';
  String get syncSuccessSnackbar => isArabic ? 'تمت مزامنة كل الرحلات بنجاح!' : 'All rides synced successfully!';
  String get clearCacheButton => isArabic ? 'تفريغ الذاكرة المؤقتة' : 'Clear Cached History';
  String get cacheClearedSnackbar => isArabic ? 'تم تفريغ الذاكرة المؤقتة بنجاح' : 'Cache cleared successfully';

  // Section: Bike Card
  String get settingsBikeSection => isArabic ? 'الدراجة المسجلة 🚲' : 'Registered Bike 🚲';

  // --- NFC Guide Dialog ---
  String get nfcGuideTitle => isArabic ? 'طريقة ربط الاختصار بملصق NFC' : 'Link Shortcut to NFC in 10 Seconds';
  String get nfcStep1 => isArabic
      ? '١. اضغط على "إعداد الاختصار" لنسخ الرابط وفتح تطبيق الاختصارات في آيفون.'
      : '1. Tap "Setup Shortcut" above to copy the link and open the iOS Shortcuts app.';
  String get nfcStep2 => isArabic
      ? '٢. في تطبيق الاختصارات، انتقل إلى تبويب "التحكم التلقائي" واضغط (+) ثم اختر "NFC".'
      : '2. Open Shortcuts app -> Go to "Automation" tab -> Tap (+) and choose "NFC".';
  String get nfcStep3 => isArabic
      ? '٣. قرّب ملصق NFC من أعلى ظهر الآيفون لبرمجته، واجعله يعمل مباشرة دون سؤال.'
      : '3. Scan your bike\'s NFC sticker and set it to run ProBike shortcut immediately!';
  String get nfcGuideDone => isArabic ? 'فهمت، جاهز الآن' : 'Got it, let\'s roll!';

  // --- Date & Time Helpers ---
  String formatTodayHeroDate(DateTime dateTime) {
    if (isArabic) {
      const arabicMonths = [
        '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      const arabicWeekdays = [
        '', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
      ];
      final weekday = arabicWeekdays[dateTime.weekday];
      final month = arabicMonths[dateTime.month];
      return '$weekday، ${dateTime.day} $month';
    } else {
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      const weekdays = [
        '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
      ];
      return '${weekdays[dateTime.weekday]}, ${dateTime.day} ${months[dateTime.month]}';
    }
  }

  String formatWeekdayShort(DateTime dateTime) {
    if (isArabic) {
      const arabicDays = {
        DateTime.monday: 'إث',
        DateTime.tuesday: 'ثل',
        DateTime.wednesday: 'أر',
        DateTime.thursday: 'خم',
        DateTime.friday: 'جم',
        DateTime.saturday: 'سب',
        DateTime.sunday: 'أح',
      };
      return arabicDays[dateTime.weekday] ?? '';
    } else {
      const englishDays = {
        DateTime.monday: 'Mo',
        DateTime.tuesday: 'Tu',
        DateTime.wednesday: 'We',
        DateTime.thursday: 'Th',
        DateTime.friday: 'Fr',
        DateTime.saturday: 'Sa',
        DateTime.sunday: 'Su',
      };
      return englishDays[dateTime.weekday] ?? '';
    }
  }

  String formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final ymd = '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
    final hour12 = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final hourStr = hour12.toString().padLeft(2, '0');
    final minStr = local.minute.toString().padLeft(2, '0');
    final period = isArabic ? (local.hour >= 12 ? 'م' : 'ص') : (local.hour >= 12 ? 'PM' : 'AM');
    return '$ymd • $hourStr:$minStr $period';
  }

  static AppStrings of(BuildContext context) {
    return const AppStrings(AppLanguage.arabicEgyptian);
  }
}
