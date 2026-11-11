# 📍 ProBike Gym — Project Status (Live Working State)

> **الغرض:** هذا الملف هو أول ما يقرأه الـ AI Agent في بداية أي جلسة لمعرفة مكان وقوفه الحالي والمهمة التالية مباشرة، بدلاً من قراءة وثيقة الخطة الكاملة.
> **آخر تحديث:** 11 نوفمبر 2026.

---

## 🎯 الوضع الحالي (Current State)

| البند | القيمة الحالية |
|---|---|
| **المرحلة الحالية:** | **Phase 4 — Polish, Analytics & Integration (التحليلات، خريطة الإجهاد، والتلميع)** |
| **آخر مهمة مكتملة:** | `GYM-P4-002` و `GYM-P4-003` (خريطة إجهاد العضلات 3D Muscle Load Heatmap مع تلوين Three.js وجسر أحمال العجلة `GymBikeBridge`، وأشرطة تصفية فئات العضلات Quick Chips للوصول اللحظي للعضلات العميقة بـ 5/5 اختبارات جديدة) |
| **المهمة قيد التنفيذ:** | `GYM-P4-004` (ميزة تصدير الداتابيز اليدوي Backup to Files / AirDrop لحفظ قاعدة بيانات الجيم) |
| **المهمة التالية:** | `GYM-P4-005` (فحص الـ 13 سيناريو حرج المشترك بين الجيم والدراجة Edge Cases Verification) |
| **فرع Git النشط:** | `feature/gym-personal` |
| **حالة البناء (Build):** | مستقر (208/208 Passing Tests بنسبة 100%، 0 أخطاء في flutter analyze) |
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
تنفيذ المهمة `GYM-P4-004`:
1. إضافة زر تصدير قاعدة البيانات (Export Database Backup) في شاشة `GymDashboardScreen`.
2. استخدام مسار تخزين `probike_gym.db` وتصدير الملف بصيغة صالحة للمشاركة عبر iOS Files / AirDrop / iCloud Drive.
3. كتابة اختبارات التحقق المؤتمتة `test/gym/database_backup_test.dart`.
