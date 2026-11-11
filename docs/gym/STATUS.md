# 📍 ProBike Gym — Project Status (Live Working State)

> **الغرض:** هذا الملف هو أول ما يقرأه الـ AI Agent في بداية أي جلسة لمعرفة مكان وقوفه الحالي والمهمة التالية مباشرة، بدلاً من قراءة وثيقة الخطة الكاملة.
> **آخر تحديث:** 11 نوفمبر 2026.

---

## 🎯 الوضع الحالي (Current State)

| البند | القيمة الحالية |
|---|---|
| **المرحلة الحالية:** | **Phase 2 — Gym Foundation** |
| **آخر مهمة مكتملة:** | `GYM-P2-004` (شاشة 3D Muscle Map التفاعلية عبر InAppWebView و Three.js بـ 5/5 اختبارات ناجحة) |
| **المهمة قيد التنفيذ:** | `GYM-P2-005` (تلميع شاشة تفاصيل العضلة `MuscleDetailScreen` وربط آخر أداء مسجل) |
| **المهمة التالية:** | `GYM-P3-001` (المرحلة 3: شاشة تسجيل التمرين الفعالة `ActiveWorkoutScreen`) |
| **فرع Git النشط:** | `feature/gym-personal` |
| **حالة البناء (Build):** | مستقر (181/181 Passing Tests بنسبة 100%، 0 أخطاء في flutter analyze) |
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
تنفيذ المهمة `GYM-P2-005`:
1. تلميع شاشة `MuscleDetailScreen` لعرض آخر أداء مسجل (Last Performance: weight x reps) لكل تمرينة.
2. إضافة زر بدء جلسة سريعة أو إضافة التمرين مباشرة إلى الجلسة النشطة `Active Workout Session`.
3. كتابة اختبارات التحقق `test/gym/muscle_detail_screen_test.dart`.
