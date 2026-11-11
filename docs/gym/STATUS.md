# 📍 ProBike Gym — Project Status (Live Working State)

> **الغرض:** هذا الملف هو أول ما يقرأه الـ AI Agent في بداية أي جلسة لمعرفة مكان وقوفه الحالي والمهمة التالية مباشرة، بدلاً من قراءة وثيقة الخطة الكاملة.
> **آخر تحديث:** 11 نوفمبر 2026.

---

## 🎯 الوضع الحالي (Current State)

| البند | القيمة الحالية |
|---|---|
| **المرحلة الحالية:** | **Phase 2 — Gym Foundation** |
| **آخر مهمة مكتملة:** | `GYM-P2-001` (بناء خدمة SQLite بوضع WAL وإنشاء الجداول الـ 7 وفحوصات التكامل) |
| **المهمة قيد التنفيذ:** | `GYM-P2-002` (بذر بيانات العضلات الـ 126 والتمارين الشائعة والصور/الـ Assets) |
| **المهمة التالية:** | `GYM-P2-003` (بناء شاشة Gym Dashboard والتنقل الحر Free Selection) |
| **فرع Git النشط:** | `feature/gym-personal` |
| **حالة البناء (Build):** | مستقر (167/167 Passing Tests بنسبة 100%، 0 أخطاء في flutter analyze) |
| **الحظر الحالي (Blockers):** | لا يوجد موانع حالياً |

---

## 🔒 الثوابت التشغيلية النشطة (Active Invariants)
- **المنصة:** iOS فقط (iPhone 14 Pro وما فوق).
- **المستخدم:** مستخدم شخصي واحد (لا accounts ولا cloud sync ولا App Store).
- **الكود المحظور لمسه:** كل ما يخص الـ Bike (`lib/services/ride_controller.dart` وباقي شاشات الدراجة).
- **نظام التمارين:** Free Selection (بدون جداول مسبقة).
- **الوزن:** كيلوجرام فقط (`kg`) مع أزرار الزيادة السريعة (+2.5, +5, +10).
- **محرك الـ 3D المعتمد:** Three.js عبر InAppLocalhostServer مع تسريع three-mesh-bvh.
- **قاعدة البيانات:** SQLite (`probike_gym.db`) في وضع WAL (`journal_mode = WAL`) مع `foreign_keys = ON`.

---

## ⏭️ التعليمات للمهمة القادمة (Next Step)
تنفيذ المهمة `GYM-P2-002`:
1. إنشاء ملف بذر البيانات `lib/features/gym/data/gym_seed_data.dart` المحتوي على العضلات الـ 126 من `manifest.json`.
2. إضافة التمارين المفضلة الأساسية مقسمة حسب العضلات مع تحديد `logging_type` و `equipment`.
3. ربط التمارين بجدول `EXERCISE_MUSCLE` (Primary و Secondary).
4. كتابة اختبار بذر البيانات `test/gym/seed_data_test.dart` والتحقق منه.
