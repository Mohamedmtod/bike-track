# 📍 ProBike Gym — Project Status (Live Working State)

> **الغرض:** هذا الملف هو أول ما يقرأه الـ AI Agent في بداية أي جلسة لمعرفة مكان وقوفه الحالي والمهمة التالية مباشرة، بدلاً من قراءة وثيقة الخطة الكاملة.
> **آخر تحديث:** 11 نوفمبر 2026.

---

## 🎯 الوضع الحالي (Current State)

| البند | القيمة الحالية |
|---|---|
| **المرحلة الحالية:** | **Phase 2 — Gym Foundation** |
| **المرحلة المكتملة:** | **Phase 1 — 3D Proof of Concept** (تم اعتماد Three.js + BVH) |
| **المهمة قيد التنفيذ:** | `GYM-P2-001` (إعداد قاعدة بيانات SQLite بوضع WAL وجداول العضلات والتمارين) |
| **المهمة التالية:** | `GYM-P2-002` (بذر بيانات التمارين الافتراضية المفضلة) |
| **فرع Git النشط:** | `feature/gym-personal` |
| **حالة البناء (Build):** | مستقر (164/164 Passing Tests بنسبة 100%، 0 أخطاء في flutter analyze) |
| **الحظر الحالي (Blockers):** | لا يوجد موانع حالياً |

---

## 🔒 الثوابت التشغيلية النشطة (Active Invariants)
- **المنصة:** iOS فقط (iPhone 14 Pro وما فوق).
- **المستخدم:** مستخدم شخصي واحد (لا accounts ولا cloud sync ولا App Store).
- **الكود المحظور لمسه:** كل ما يخص الـ Bike (`lib/services/ride_controller.dart` وباقي شاشات الدراجة).
- **نظام التمارين:** Free Selection (بدون جداول مسبقة).
- **الوزن:** كيلوجرام فقط (`kg`) مع أزرار الزيادة السريعة (+2.5, +5, +10).
- **محرك الـ 3D المعتمد:** Three.js عبر InAppLocalhostServer مع تسريع three-mesh-bvh.

---

## ⏭️ التعليمات للمهمة القادمة (Next Step)
تنفيذ المهمة `GYM-P2-001`:
1. إضافة حزمة `sqflite` (أو فحص دعم SQLite المحلي).
2. بناء خدمة إدارة قاعدة البيانات `GymDatabaseService` بوضع WAL وملف منفصل `probike_gym.db`.
3. إنشاء جداول: `MUSCLE`، `MUSCLE_MESH_BINDING`، `EXERCISE`، `EXERCISE_MUSCLE`، `WORKOUT_SESSION`، `SESSION_EXERCISE`، `SET_LOG`.
4. كتابة اختبارات تكامل قاعدة البيانات في `test/gym/database_test.dart`.
