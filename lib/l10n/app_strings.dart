import 'package:flutter/material.dart';

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
  String get appSubtitle => 'CYCLING COMPANION PRO';
  String get myBikeModel => 'Galaxy RL600H Hybrid';
  String get myBikeSpecs => isArabic
      ? 'شاسيه ألومنيوم تيتانيوم • سرعات Shimano Tourney 3x7 • قفل مساعدين'
      : 'Alloy Titanium Frame • Shimano Tourney 3x7 • Suspension Lockout';
  String get appVersion => 'ProBike v1.1.0 (Build 2)';

  // --- Dashboard Screen ---
  String get headerGreeting => isArabic ? 'يا هلا يا كابتن! 🚴‍♂️' : 'Welcome back, Rider! 🚴‍♂️';
  String get headerSubtitle => isArabic ? 'جاهز لطلعة جديدة النهاردة؟' : 'Ready to crush a new ride today?';
  String get activeRideBanner => isArabic
      ? 'الرحلة جارية الآن • اضغط للعودة إلى العداد'
      : 'Ride in progress right now • Tap for cockpit';
  String get startRideButtonIdle => isArabic ? '🚴 ابدأ رايد دلوقتي (Start)' : '🚴 Let\'s Roll (Start Ride)';
  String get startRideButtonRiding => isArabic ? 'متابعة الرحلة الحالية (Live View)' : 'Active Ride (Live View)';
  String get ridesHistoryTitle => isArabic ? 'سجل الرحلات' : 'Ride History';
  String ridesCount(int count) => isArabic ? '$count رحلة' : '$count rides';
  String get emptyHistoryTitle => isArabic ? 'لا توجد رحلات مسجلة بعد' : 'No rides recorded yet!';
  String get emptyHistorySubtitle => isArabic
      ? 'ابدأ أول رحلة لك الآن لتتبع سرعتك ومسافتك!'
      : 'Hop on your bike and start your first ride to track speed & distance!';
  String get syncStatusSynced => isArabic ? 'متزامن سحابياً ☁️' : 'Cloud Synced ☁️';
  String get syncStatusPending => isArabic ? 'قيد المزامنة' : 'Queued for Sync';
  String get manualRideBadge => isArabic ? 'طلعة يدوية تعويضية' : 'Manual Recovery Ride';
  String get kmUnit => isArabic ? 'كم' : 'km';
  String get kmhUnit => isArabic ? 'كم/س' : 'km/h';

  // --- Swipe-to-Delete Dialog ---
  String get deleteDialogTitle => isArabic ? 'حذف الرحلة' : 'Delete Ride';
  String get deleteDialogBody => isArabic
      ? 'هل أنت متأكد من رغبتك في حذف هذه الرحلة نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'
      : 'Are you sure you want to delete this ride permanently? This action cannot be undone.';
  String get deleteDialogCancel => isArabic ? 'إلغاء' : 'Cancel';
  String get deleteDialogConfirm => isArabic ? 'حذف' : 'Delete';
  String get deleteSuccessSnackbar => isArabic ? 'تم حذف الرحلة بنجاح' : 'Ride deleted successfully';

  // --- Live Ride Cockpit ---
  String get liveTimeElapsed => isArabic ? 'وقت البدال' : 'Moving Time';
  String get liveCurrentSpeed => isArabic ? 'السرعة الآن' : 'Current Speed';
  String get liveAvgSpeed => isArabic ? 'متوسط السرعة' : 'Avg Speed';
  String get liveDistanceCrushed => isArabic ? 'المسافة' : 'Distance';
  String get liveMaxSpeed => isArabic ? 'أقصى سرعة' : 'Top Speed';
  String get liveMinSpeed => isArabic ? 'أدنى سرعة' : 'Min Speed';
  String get liveFinishButton => isArabic ? 'إيقاف الرحلة (STOP RIDE)' : 'Stop Ride (STOP RIDE)';
  String get liveRecenterTooltip => isArabic ? 'سنترني ع الخريطة' : 'Recenter Map';
  String get liveGpsLocked => isArabic ? 'LIVE GPS TRACKING' : 'LIVE GPS TRACKING';

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
  String get settingsTitle => isArabic ? 'الإعدادات والتحكم' : 'Settings & Controls';
  
  // Section: Theme
  String get settingsThemeSection => isArabic ? 'مظهر التطبيق والثيمات' : 'Appearance & Themes';
  String get settingsThemeSubtitle => isArabic
      ? 'اختر الثيم اللي يليق مع مودك وعجلتك'
      : 'Choose a theme matching your vibe and rig';
  String get currentThemeLabel => isArabic ? 'الثيم الحالي' : 'Active Theme';
  String get changeThemeButton => isArabic ? 'تغيير الثيم' : 'Change Theme';

  // Section: Language
  String get settingsLanguageSection => isArabic ? 'لغة التطبيق (Language)' : 'App Language';
  String get settingsLanguageSubtitle => isArabic
      ? 'اختر اللهجة واللغة المفضلة لديك'
      : 'Choose your preferred language';
  String get langArabicEgyptian => 'مِصري روش ودارج 🇪🇬';
  String get langEnglishModern => 'English (Modern Cycling) 🇬🇧';

  // Section: NFC & Siri Shortcuts
  String get settingsShortcutsSection => isArabic ? 'اختصارات الآيفون والـ NFC ⚡' : 'Apple Shortcuts & NFC ⚡';
  String get settingsShortcutsSubtitle => isArabic
      ? 'بضغطة واحدة ثبت الاختصار وشغله أول ما تقرب الموبايل من العجلة'
      : 'One-tap setup to launch rides instantly via NFC stickers';
  String get shortcutStartTitle => isArabic ? 'اختصار: ابدأ الرايد تلقائياً' : 'Shortcut: Auto-Start Ride';
  String get shortcutStartDesc => isArabic
      ? 'يفتح ProBike ويبدأ التسجيل فوراً برابط probike://start'
      : 'Opens ProBike and starts ride immediately via probike://start';
  String get shortcutStopTitle => isArabic ? 'اختصار: فرمل ووقّف الرايد' : 'Shortcut: Stop & Finish Ride';
  String get shortcutStopDesc => isArabic
      ? 'ينهي الرحلة ويحفظها في ثواني برابط probike://stop'
      : 'Stops and saves your ride in seconds via probike://stop';
  String get installShortcutBtn => isArabic ? 'تثبيت الاختصار 📲' : 'Install Shortcut 📲';
  String get nfcGuideButton => isArabic ? 'ازاي أربطه باستيكر NFC؟ (دليل 10 ثواني)' : 'How to link to NFC tag? (10s Guide)';
  String get testDeepLinkBtn => isArabic ? 'تجربة فتح الرابط الآن' : 'Test Deep Link Now';

  // Section: Hydration & Reminder
  String get settingsReminderSection => isArabic ? 'منبه شرب المية والراحة 💧' : 'Hydration & Rest Reminder 💧';
  String get settingsReminderSubtitle => isArabic
      ? 'اهتزاز ذكي ينبهك تشرب وتريح كل فترة وأنت سايق'
      : 'Smart haptic pulse reminding you to hydrate while riding';
  String reminderIntervalText(int minutes) => isArabic ? 'كل $minutes دقيقة' : 'Every $minutes minutes';
  String get reminderIncrease => '+ 5 دقايق';
  String get reminderDecrease => '- 5 دقايق';

  // Section: Cloud & Cache Diagnostics
  String get settingsCloudSection => isArabic ? 'السحابة والمزامنة (Supabase) ☁️' : 'Cloud Sync & Diagnostics ☁️';
  String get settingsCloudSubtitle => isArabic
      ? 'حالة الاتصال والبيانات المحلية'
      : 'Connection status and offline sync queue';
  String get cloudStatusConnected => isArabic ? 'السحابة: متصلة وجاهزة 🟢' : 'Supabase: Connected & Live 🟢';
  String pendingSyncCountText(int count) => isArabic
      ? 'رحلات قيد المزامنة أوفلاين: $count'
      : 'Pending offline rides: $count';
  String get syncNowButton => isArabic ? 'مزامنة السحابة الآن' : 'Sync With Cloud Now';
  String get syncSuccessSnackbar => isArabic ? 'تمت مزامنة كل الرحلات بنجاح!' : 'All rides synced successfully!';
  String get clearCacheButton => isArabic ? 'تفريغ الذاكرة المؤقتة (Cache)' : 'Clear Cached History';
  String get cacheClearedSnackbar => isArabic ? 'تم تنظيف الكاش بنجاح' : 'Cache cleared successfully';

  // Section: Bike Card
  String get settingsBikeSection => isArabic ? 'دراجتك المسجلة 🚲' : 'Registered Bike 🚲';

  // --- NFC Guide Dialog ---
  String get nfcGuideTitle => isArabic ? 'طريقة ربط الاختصار بالـ NFC في 10 ثواني' : 'Link Shortcut to NFC in 10 Seconds';
  String get nfcStep1 => isArabic
      ? '1. اضغط على "تثبيت الاختصار" فوق لتنزيله وفتحه داخل تطبيق Shortcuts في الآيفون.'
      : '1. Tap "Install Shortcut" above to import it into your iPhone Shortcuts app.';
  String get nfcStep2 => isArabic
      ? '2. افتح تطبيق Shortcuts واذهب لتبويب "التحكم التلقائي" (Automation) ثم اضغط (+) واشترط "NFC".'
      : '2. Open Shortcuts app -> Go to "Automation" tab -> Tap (+) and choose "NFC".';
  String get nfcStep3 => isArabic
      ? '3. قرّب استيكر الـ NFC من أعلى ظهر الآيفون لمسحه، واختر تشغيل اختصار ProBike بدون سؤال (Run Immediately).'
      : '3. Scan your bike\'s NFC sticker and set it to run ProBike shortcut immediately!';
  String get nfcGuideDone => isArabic ? 'فهمت، جاهز للتجربة! 🔥' : 'Got it, let\'s roll! 🔥';

  static AppStrings of(BuildContext context) {
    return const AppStrings(AppLanguage.arabicEgyptian);
  }
}
