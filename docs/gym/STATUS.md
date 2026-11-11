# 📍 ProBike Gym — Project Status (Live Working State)

> **الغرض:** هذا الملف هو أول ما يقرأه الـ AI Agent في بداية أي جلسة لمعرفة مكان وقوفه الحالي والمهمة التالية مباشرة، بدلاً من قراءة وثيقة الخطة الكاملة.
> **آخر تحديث:** 11 نوفمبر 2026.

---

## 🎯 الوضع الحالي (Current State)

| البند | القيمة الحالية |
|---|---|
| **المرحلة الحالية:** | **Phase 3 — Workout Engine (محرك تسجيل التمرين اللحظي)** |
| **آخر مهمة مكتملة:** | إنجاز `GYM-P3-002`, `003`, `004`, `007`, `008` (خوارزمية Ghost Pre-fill، أزرار الوزن والعدات، أنواع Sets، التمارين الأحادية والزمنية، مؤقت الراحة Monotonic، الحفظ اللحظي المباشر، وميزة استبدال التمرينة Swap بـ 10/10 اختبارات ناجحة) |
| **المهمة قيد التنفيذ:** | `GYM-P3-006` (منسق جلسات الصوت `AppAudioSessionCoordinator` لدعم mixWithOthers وعدم مقاطعة Spotify) |
| **المهمة التالية:** | `GYM-P3-005` (جسر Live Activities و Dynamic Island للآيفون 14 برو) |
| **فرع Git النشط:** | `feature/gym-personal` |
| **حالة البناء (Build):** | مستقر (194/194 Passing Tests بنسبة 100%، 0 أخطاء في flutter analyze) |
| **الحظر الحالي (Blockers):** | لا يوجد موانع حالياً |

---

## 🔒 الثوابت التشغيلية النشطة (Active Invariants)
- **المنصة والعتاد:** iOS 16.1+ حصرياً (iPhone 14 Pro لدعم Live Activities والجزيرة التفاعلية Dynamic Island).
- **المستخدم:** مستخدم شخصي واحد (لا accounts ولا cloud sync ولا App Store).
- **كود الدراجة وتيليمتري الـ GPS:** محظور لمس منطق الدراجة، مع وجود نقطة دخول تنقل محكومة (`gym_button`) في شريط أدوات `DashboardScreen`.
- **عزل التخزين:** قاعدة بيانات SQLite (`probike_gym.db`) خاصة بالجيم فقط، وربط الدراجة لقراءة أحمال الـ Heatmap يتم كـ Read-Only عبر `GymBikeBridge` دون داتابيز مشتركة.
- **نطاق العمل دون اتصال:** موديول الجيم يعمل 100% Offline-First.
- **نظام التمارين:** Free Selection (بدون جداول مسبقة).
- **الوزن:** كيلوجرام فقط (`kg`) مع أزرار الزيادة السريعة (+2.5, +5, +10).
- **محرك الـ 3D المعتمد:** Three.js محلياً عبر InAppLocalhostServer مع تسريع three-mesh-bvh وموديل Z-Anatomy المرخص (CC-BY-SA-4.0).

---

## ⏭️ التعليمات للمهمة القادمة (Next Step)
تنفيذ المهمة `GYM-P3-006` و `GYM-P3-005`:
1. بناء `AppAudioSessionCoordinator` بضبط `mixWithOthers: true` و `duckOthers: true` لتشغيل صافرة انتهاء الراحة مع خفض مؤقت لموسيقى Spotify/Apple Music وإعادتها فوراً دون مقاطعة.
2. بناء جسر `GymLiveActivityService` للاتصال بـ ActivityKit وعرض عداد الراحة على Dynamic Island وشاشة القفل في iPhone 14 Pro مع fallback أنيق للمنصات غير المدعومة.
3. كتابة اختبارات التحقق الشاملة والتأكد من اجتياز 100% من الاختبارات وخلو الكود من التحذيرات.
