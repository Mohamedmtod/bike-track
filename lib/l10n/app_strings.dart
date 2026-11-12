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
  String syncCardTitle(int count) => isArabic
      ? (count == 1 ? 'رحلة بانتظار المزامنة' : '$count رحلات بانتظار المزامنة')
      : (count == 1 ? '1 ride pending sync' : '$count rides pending sync');
  String get syncCardSubtitle => isArabic
      ? 'محفوظة محلياً وسيتم الرفع تلقائياً عند توفر الإنترنت'
      : 'Saved locally; will sync automatically when online';
  String get syncingInProgress => isArabic ? 'جارٍ المزامنة...' : 'Syncing...';
  String get rideSavedOfflineNotice => isArabic
      ? 'تم حفظ الرحلة محلياً وستتم المزامنة تلقائياً عند توفر الإنترنت 📡'
      : 'Ride saved locally; will sync automatically when online 📡';
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
  String get syncNowButton => isArabic ? 'مزامنة الآن' : 'Sync Now';
  String get syncSuccessSnackbar => isArabic ? 'تمت مزامنة جميع الرحلات مع السحابة بنجاح ☁️' : 'All rides synced successfully ☁️';
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

  // --- Analytics & Daily Stats Screens ---
  String get dailyStatsTitle => isArabic ? 'إحصائيات اليوم' : 'Daily Analytics';
  String get overallStatsTitle => isArabic ? 'مركز الإحصائيات' : 'Analytics Hub';
  String get dayHeroSummary => isArabic ? 'ملخص النشاط اليومي' : 'Daily Activity Summary';
  String get dayTotalDistance => isArabic ? 'إجمالي المسافة' : 'Total Distance';
  String get dayMovingTime => isArabic ? 'وقت الحركة' : 'Moving Time';
  String get dayAvgSpeed => isArabic ? 'متوسط السرعة' : 'Avg Speed';
  String get dayMaxSpeed => isArabic ? 'أقصى سرعة' : 'Top Speed';
  String get dayMinSpeed => isArabic ? 'أدنى سرعة' : 'Min Speed';
  String dayRidesCountText(int count) => isArabic ? '$count رحلات' : '$count rides';
  String get dayRidesListTitle => isArabic ? 'رحلات هذا اليوم' : "Day's Rides";
  String get dayUnifiedMapTitle => isArabic ? 'خريطة مسارات اليوم' : "Day's Unified Routes";
  String get allRoutesChip => isArabic ? 'كل المسارات' : 'All Routes';
  String rideChipLabel(int index, String time) => isArabic ? 'رحلة $index ($time)' : 'Ride $index ($time)';
  String get restDayTitle => isArabic ? 'يوم راحة واستشفاء 🧘‍♂️' : 'Rest & Recovery Day 🧘‍♂️';
  String get restDaySubtitle => isArabic
      ? 'لم تسجل أي رحلات بالدراجة في هذا اليوم. الراحة جزء أساسي من بناء لياقتك واستمرارية أدائك!'
      : 'No rides recorded on this day. Recovery is essential for building your endurance!';
  String get noGpsRoutesDayNotice => isArabic
      ? 'جميع رحلات هذا اليوم مسجلة يدوياً بدون مسار GPS.'
      : 'All rides on this day were recorded manually without GPS route tracks.';
  String get shareDaySummaryTooltip => isArabic ? 'مشاركة ملخص اليوم' : 'Share Day Summary';
  String get shareDaySummarySubject => isArabic ? 'نشاط الدراجة في ProBike 🚴‍♂️' : 'ProBike Cycling Day Summary 🚴‍♂️';
  String shareDaySummaryText(String date, String dist, String dur) => isArabic
      ? 'حققت $dist كم في $dur يوم $date عبر تطبيق ProBike 🚴‍♂️'
      : 'Crushed $dist km in $dur on $date with ProBike 🚴‍♂️';
  String get liveRideIncludedNotice => isArabic
      ? 'يتضمن هذا الملخص بيانات الرحلة الجارية حالياً 🔴'
      : 'Includes ongoing active ride metrics 🔴';
  String get shareFailedSnackbar => isArabic ? 'تعذر فتح نافذة المشاركة' : 'Unable to open share sheet';

  // Overnight Ride Badge
  String get overnightRideBadge => isArabic ? '🌙 رحلة ليلية' : '🌙 Overnight';
  String get overnightRideTooltip => isArabic
      ? 'بدأت هذه الرحلة قبل منتصف الليل وامتدت لليوم التالي، ومسجلة في يوم بدئها'
      : 'This ride started before midnight and crossed into the next day, attributed to its start day';

  // Periods
  String get periodDay => isArabic ? 'يوم' : 'Day';
  String get periodWeek => isArabic ? 'أسبوع' : 'Week';
  String get periodMonth => isArabic ? 'شهر' : 'Month';
  String get periodYear => isArabic ? 'سنة' : 'Year';
  String get periodAll => isArabic ? 'الكل' : 'All';

  // Metrics
  String get metricDistance => isArabic ? 'المسافة' : 'Distance';
  String get metricDuration => isArabic ? 'المدة' : 'Duration';
  String get metricSpeed => isArabic ? 'السرعة' : 'Speed';
  String get metricRideCount => isArabic ? 'الرحلات' : 'Rides';

  // Records
  String get recordsSectionTitle => isArabic ? 'أرقامك القياسية 🏆' : 'Personal Records 🏆';
  String get recordLongestRide => isArabic ? 'أطول رحلة' : 'Longest Ride';
  String get recordFastestRide => isArabic ? 'أسرع رحلة (متوسط)' : 'Fastest Ride (Avg)';
  String get recordMostActiveDay => isArabic ? 'اليوم الأكثر نشاطاً' : 'Most Active Day';
  String get allTimeOdometer => isArabic ? 'العداد التراكمي الشامل' : 'All-Time Odometer';
  String get periodBreakdownTitle => isArabic ? 'توزيع النشاط خلال الفترة' : 'Activity Breakdown';
  String get noDataForPeriod => isArabic ? 'لا توجد رحلات مسجلة في هذه الفترة' : 'No rides recorded in this period';
  String get previousPeriodTooltip => isArabic ? 'الفترة السابقة' : 'Previous Period';
  String get nextPeriodTooltip => isArabic ? 'الفترة التالية' : 'Next Period';
  String get metricToday => isArabic ? 'اليوم' : 'Today';

  String formatDateShort(DateTime dateTime) {
    final local = dateTime.toLocal();
    const arabicMonths = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    const englishMonths = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (isArabic) {
      return '${local.day} ${arabicMonths[local.month]} ${local.year}';
    } else {
      return '${englishMonths[local.month]} ${local.day}, ${local.year}';
    }
  }

  // Date formatting helpers
  String formatDateFull(DateTime dateTime) {
    final local = dateTime.toLocal();
    const arabicMonths = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    const englishMonths = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const arabicDaysFull = {
      DateTime.monday: 'الإثنين',
      DateTime.tuesday: 'الثلاثاء',
      DateTime.wednesday: 'الأربعاء',
      DateTime.thursday: 'الخميس',
      DateTime.friday: 'الجمعة',
      DateTime.saturday: 'السبت',
      DateTime.sunday: 'الأحد',
    };
    const englishDaysFull = {
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };

    if (isArabic) {
      final dayName = arabicDaysFull[local.weekday] ?? '';
      final monthName = arabicMonths[local.month];
      return '$dayName، ${local.day} $monthName ${local.year}';
    } else {
      final dayName = englishDaysFull[local.weekday] ?? '';
      final monthName = englishMonths[local.month];
      return '$dayName, $monthName ${local.day}, ${local.year}';
    }
  }

  String formatMonthYear(DateTime dateTime) {
    final local = dateTime.toLocal();
    const arabicMonths = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    const englishMonths = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    if (isArabic) {
      return '${arabicMonths[local.month]} ${local.year}';
    } else {
      return '${englishMonths[local.month]} ${local.year}';
    }
  }

  // --- Gym & Anatomy Localized Strings ---
  String get gymTitle => isArabic ? 'تمارين الجيم' : 'Gym & Workouts';
  String get gym3dMuscleMap => isArabic ? 'خريطة العضلات 3D' : '3D Muscle Map';
  String get diagnosticsHudTooltip => isArabic ? 'مؤشرات الأداء و120 إطار' : '120 FPS & Diagnostics HUD';
  String get fatigueHeatmapTooltip => isArabic ? 'خريطة الإجهاد العضلي' : 'Fatigue Heatmap';
  String get cameraAngleFront => isArabic ? 'أمامي' : 'FRONT';
  String get cameraAngleBack => isArabic ? 'خلفي' : 'BACK';
  String get modeExplore => isArabic ? 'تحديد العضلات' : 'Select Muscles';
  String get modeOrbit => isArabic ? 'تدوير 360°' : 'Orbit 360°';
  String get gestureHint => isArabic
      ? 'إصبع واحد للاختيار • إصبعان للتدوير والتكبير'
      : '1-Finger: Select / 2-Fingers: Rotate & Zoom';
  String get loading3dModel => isArabic
      ? 'جارٍ تحميل مجسم التشريح 3D...'
      : 'Loading 3D Anatomy Model...';

  // Category labels
  String get allCategories => isArabic ? 'الكل' : 'All';
  String get chestCategory => isArabic ? 'الصدر' : 'Chest';
  String get backCategory => isArabic ? 'الظهر' : 'Back';
  String get legsCategory => isArabic ? 'الأرجل' : 'Legs';
  String get armsCategory => isArabic ? 'الأذرع' : 'Arms';
  String get shouldersCategory => isArabic ? 'الأكتاف' : 'Shoulders';
  String get coreCategory => isArabic ? 'البطن' : 'Core';

  // Localized Muscle Names
  String localizedMuscleName(String muscleId, [String? fallback]) {
    final Map<String, String> arabicNames = {
      'chest': 'عضلات الصدر',
      'front-shoulders': 'الكتف الأمامي',
      'rear-shoulders': 'الكتف الخلفي',
      'biceps': 'عضلة البايسبس',
      'triceps': 'عضلة الترايسبس',
      'forearms': 'عضلات الساعد',
      'abdominals': 'عضلات البطن',
      'obliques': 'عضلات الخواصر',
      'traps': 'الترابيس العلوية',
      'traps-middle': 'الترابيس الوسطى',
      'lats': 'عضلات الظهر (المجانس)',
      'lowerback': 'أسفل الظهر (القطنية)',
      'glutes': 'عضلات الأرداف (الجلوتس)',
      'quads': 'عضلة الفخذ الأمامية',
      'hamstrings': 'عضلة الفخذ الخلفية',
      'calves': 'عضلات السمانة',
      'tibialis': 'عضلة قصبة الساق',
      'adductors': 'عضلات الفخذ الضامة',
    };

    final Map<String, String> englishNames = {
      'chest': 'Chest (Pectorals)',
      'front-shoulders': 'Front Shoulders',
      'rear-shoulders': 'Rear Shoulders',
      'biceps': 'Biceps',
      'triceps': 'Triceps',
      'forearms': 'Forearms',
      'abdominals': 'Abs (Core)',
      'obliques': 'Obliques',
      'traps': 'Upper Trapezius',
      'traps-middle': 'Middle Trapezius',
      'lats': 'Lats (Upper Back)',
      'lowerback': 'Lower Back',
      'glutes': 'Glutes',
      'quads': 'Quadriceps',
      'hamstrings': 'Hamstrings',
      'calves': 'Calves',
      'tibialis': 'Tibialis Anterior',
      'adductors': 'Hip Adductors',
    };

    if (isArabic) {
      if (arabicNames.containsKey(muscleId)) return arabicNames[muscleId]!;
    } else {
      if (englishNames.containsKey(muscleId)) return englishNames[muscleId]!;
    }

    if (fallback != null) {
      return _cleanBilingualString(fallback, isArabic);
    }
    return muscleId;
  }

  String muscleName(String muscleId, [String? fallback]) => localizedMuscleName(muscleId, fallback);

  // Localized Exercise Names
  String localizedExerciseName(String exerciseId, [String? fallback]) {
    final Map<String, String> arabicExercises = {
      'bench_press': 'بنش برس بالبار',
      'incline_db_press': 'تجميع دمبل عالي مائل',
      'cable_chest_fly': 'فراشة بالكابل',
      'pushup': 'تمرين الضغط',
      'dips': 'تمرين المتوازي',
      'lat_pulldown': 'سحب عالي واسع',
      'seated_cable_row': 'سحب أرضي بالكابل',
      'bent_over_row': 'تجديف بالبار',
      'pullup': 'تمرين العقلة',
      'db_shrug': 'ترابيس بالدمبل',
      'overhead_press': 'كتف بالدمبل جالس',
      'lateral_raise': 'رفرفة كتف جانبي',
      'face_pull': 'فيس بول بالحبل',
      'reverse_pec_deck': 'خلفيات فراشة بالجهاز',
      'barbell_curl': 'باي بالبار المستقيم',
      'incline_db_curl': 'باي دمبل بنش مائل',
      'hammer_curl': 'شاكوش بالدمبل',
      'tricep_pushdown': 'تراي كابل بالحبل',
      'skull_crushers': 'تراي بالبار الفرنسي',
      'overhead_tricep_ext': 'تراي دمبل فرنساوي فردي',
      'wrist_curl': 'رست ساعد بالبار',
      'squat': 'سكوات بالبار',
      'leg_press': 'دفع أرجل بالجهاز',
      'romanian_deadlift': 'ديدليفت روماني',
      'leg_extension': 'فرد أرجل أمامي بالجهاز',
      'leg_curl': 'ثني أرجل خلفي بالجهاز',
      'standing_calf_raise': 'سمانة واقفاً بالجهاز',
      'tibialis_raise': 'رفع قصبة الساق',
      'cable_crunch': 'طحن بطن بالكابل',
      'hanging_leg_raise': 'رفع أرجل معلق',
      'plank': 'تمرين البلانك',
      'deadlift': 'ديدليفت تقليدي',
    };

    final Map<String, String> englishExercises = {
      'bench_press': 'Barbell Bench Press',
      'incline_db_press': 'Incline Dumbbell Press',
      'cable_chest_fly': 'Cable Chest Fly',
      'pushup': 'Push-up',
      'dips': 'Chest Dips',
      'lat_pulldown': 'Lat Pulldown',
      'seated_cable_row': 'Seated Cable Row',
      'bent_over_row': 'Barbell Bent-Over Row',
      'pullup': 'Pull-up',
      'db_shrug': 'Dumbbell Shrug',
      'overhead_press': 'Overhead DB Press',
      'lateral_raise': 'Dumbbell Lateral Raise',
      'face_pull': 'Face Pull',
      'reverse_pec_deck': 'Reverse Pec Deck',
      'barbell_curl': 'Barbell Bicep Curl',
      'incline_db_curl': 'Incline Dumbbell Curl',
      'hammer_curl': 'Hammer Curl',
      'tricep_pushdown': 'Triceps Rope Pushdown',
      'skull_crushers': 'Skull Crushers',
      'overhead_tricep_ext': 'Overhead DB Tricep Ext',
      'wrist_curl': 'Barbell Wrist Curl',
      'squat': 'Barbell Back Squat',
      'leg_press': 'Leg Press',
      'romanian_deadlift': 'Romanian Deadlift',
      'leg_extension': 'Leg Extension',
      'leg_curl': 'Lying Leg Curl',
      'standing_calf_raise': 'Standing Calf Raise',
      'tibialis_raise': 'Tibialis Raise',
      'cable_crunch': 'Cable Crunch',
      'hanging_leg_raise': 'Hanging Leg Raise',
      'plank': 'Plank',
      'deadlift': 'Conventional Deadlift',
    };

    if (isArabic) {
      if (arabicExercises.containsKey(exerciseId)) return arabicExercises[exerciseId]!;
    } else {
      if (englishExercises.containsKey(exerciseId)) return englishExercises[exerciseId]!;
    }

    if (fallback != null) {
      return _cleanBilingualString(fallback, isArabic);
    }
    return exerciseId;
  }

  // Equipment & Laterality
  String localizedEquipment(String equipment) {
    switch (equipment.toLowerCase()) {
      case 'barbell':
        return isArabic ? 'باربل' : 'Barbell';
      case 'dumbbell':
        return isArabic ? 'دمبل' : 'Dumbbell';
      case 'cable':
        return isArabic ? 'كابل' : 'Cable';
      case 'machine':
        return isArabic ? 'جهاز' : 'Machine';
      case 'bodyweight':
        return isArabic ? 'وزن الجسم' : 'Bodyweight';
      default:
        return equipment;
    }
  }

  String localizedLaterality(String laterality) {
    switch (laterality.toLowerCase()) {
      case 'bilateral':
        return isArabic ? 'ثنائي' : 'Bilateral';
      case 'unilateral':
        return isArabic ? 'فردي' : 'Unilateral';
      default:
        return laterality;
    }
  }

  // Utility to extract pure language part if a bilingual string "English (عربي)" is encountered
  static String _cleanBilingualString(String input, bool isArabic) {
    final match = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(input.trim());
    if (match != null) {
      final engPart = match.group(1)?.trim() ?? '';
      final arPart = match.group(2)?.trim() ?? '';
      return isArabic ? (arPart.isNotEmpty ? arPart : engPart) : (engPart.isNotEmpty ? engPart : arPart);
    }
    return input;
  }

  static AppStrings fromIsArabic(bool isArabic) {
    return AppStrings(isArabic ? AppLanguage.arabicEgyptian : AppLanguage.english);
  }

  static AppStrings of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    if (locale?.languageCode == 'ar') {
      return const AppStrings(AppLanguage.arabicEgyptian);
    } else if (locale?.languageCode == 'en') {
      return const AppStrings(AppLanguage.english);
    }
    return const AppStrings(AppLanguage.arabicEgyptian);
  }
}
