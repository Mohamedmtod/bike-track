# 📓 ProBike Gym — AI Agent Decision Log (`AGENT_LOG.md`)

> **الغرض:** تسجيل القرارات المعمارية السريعة والخيارات التقنية التي يتخذها الـ Agent مع أسبابها لضمان عدم نسيانها في الجلسات القادمة.

---

### [2026-11-11] — Initial Project Calibration
- **القرار:** اعتماد معمارية "المستخدم الشخصي الواحد" (Personal Single-User Edition).
- **السبب:** تقليل التعقيد المعماري وتوفير التوكنز وتجنب كود التراخيص، الأندرويد، وتعدد العملات.
- **القرار:** استخدام نمط السياق المتدرج (Hierarchical Context) عبر ملفات `docs/gym/` الخفيفة.
- **السبب:** تجنب قراءة الـ 700 سطر مع كل رسالة، وتوجيه تركيز الموديل نحو المهمة المحددة فقط.

### [2026-11-11] — Phase 0: Technical Audit Discoveries
- **القرار:** عدم المساس بـ `SharedPreferences` المستخدم في تتبع الدراجة والاعتماد الحصري على SQLite (sqflite) لموديل الجيم بملف داتابيز منفصل تماماً (`probike_gym.db`).
- **السبب:** عزل تام بنسبة 100% يمنع أي تأثير متبادل بين بيانات الرحلات وبيانات التمارين، وتفادي أي تعارض في التهيئة.
- **القرار:** إنشاء فرع منفصل `feature/gym-personal` لتنفيذ كافة مراحل الجيم مع الحفاظ على `main` كملاذ آمن.

### [2026-11-11] — Phase 1: 3D Engine Selection & Asset Pipeline
- **القرار:** اعتماد Three.js + `three-mesh-bvh` محلياً عبر `InAppLocalhostServer` واستبعاد Apple RealityKit.
- **السبب:**
  1. يدعم موديل الـ GLB مباشرة مع Meshopt Compression (حجم 5.07 MB) بدون الحاجة لأي تحويلات إلى USDZ.
  2. زمن الـ Raycasting أقل من 0.4ms بفضل تسريع BVH داخل WebGL، مما يتيح الـ Touch Scrubbing بسلاسة 120 FPS دون إغراق جسر Flutter Platform Channels بأحداث اللمس.
  3. عزل تام لكود الـ iOS الأصلي في `ios/Runner/` دون إضافة PlatformView Swift factories معقدة قد تؤثر على تتبع الـ GPS أو خدمات الخلفية.

### [2026-11-11] — Phase 2: Gym Foundation & Dashboard Navigation
- **القرار:** إنشاء نقطة دخول وحيدة ومعزولة (`gym_button`) في شريط أدوات `DashboardScreen` ونقل التحكم إلى `GymDashboardScreen`.
- **السبب:** الامتثال لثوابت `BIKE_TRACKING_INVARIANTS.md` التي تحظر المساس بمنطق الـ GPS أو رحلات الدراجة مع توفير وصول بديهي وسلس لموديل الجيم.
- **القرار:** استخدام `pumpUntilFound` مع `tester.runAsync` وتهيئة `RideController(autoFetchHistory: false, autoLoadPreferences: false)` في اختبارات الواجهة.
- **السبب:** يضمن تزامن رسائل الـ isolates في مكتبة `sqflite_common_ffi` ويمنع تسرب الـ background timers الخاصة بمزامنة رحلات الدراجة في بيئة الاختبار.

### [2026-11-11] — Phase 2: 3D Muscle Map Interactive View
- **القرار:** دعم آلية `InAppWebViewPlatform.instance == null` التلقائية للبيئات عديمة الواجهة الرسومية (Headless Tests).
- **السبب:** يسمح بتشغيل كافة اختبارات واجهة الـ 3D (الأزرار، التبديل بين Explore و Orbit، قلب الكاميرا، واختيار العضلات) على أجهزة المطور وسيرفرات CI دون الحاجة لمتصفح WebKit أصلي أثناء اختبارات الفلاتر.
- **القرار:** استخدام `SingleChildScrollView` أفقي لشريط العضلات الـ 18 السريعة بدلاً من `ListView.separated`.
- **السبب:** يضمن تحميل كافة العضلات الـ 18 فوراً في شجرة العناصر وتجنب مشاكل Lazy Unmount أثناء الفحص المؤتمت أو التمرير السريع.
