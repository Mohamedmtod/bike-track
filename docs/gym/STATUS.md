# 📍 ProBike Gym — Project Status (Live Working State)

> **الغرض:** هذا الملف هو أول ما يقرأه الـ AI Agent في بداية أي جلسة لمعرفة مكان وقوفه الحالي والمهمة التالية مباشرة، بدلاً من قراءة وثيقة الخطة الكاملة.
> **آخر تحديث:** 11 نوفمبر 2026.

---

## 🎯 الوضع الحالي (Current State)

| البند | القيمة الحالية |
|---|---|
| **المرحلة الحالية:** | **Phase 1 — 3D Proof of Concept** |
| **آخر مهمة مكتملة:** | `GYM-P1-001` (تجهيز وفحص الموديل ثلاثي الأبعاد male_anatomy.glb واعتماد 126 عضلة) |
| **المهمة قيد التنفيذ:** | `GYM-P1-002` (بناء النموذج التجريبي للـ 3D: RealityKit Native مقابل Three.js WebView) |
| **المهمة التالية:** | `GYM-P1-004` (تقرير المقارنة واعتماد المحرك الفائز 3D_POC_REPORT.md) |
| **فرع Git النشط:** | `feature/gym-personal` |
| **حالة البناء (Build):** | مستقر (161/161 Passing Tests بنسبة 100%، 0 أخطاء في flutter analyze) |
| **الحظر الحالي (Blockers):** | لا يوجد موانع حالياً |

---

## 🔒 الثوابت التشغيلية النشطة (Active Invariants)
- **المنصة:** iOS فقط (iPhone 14 Pro وما فوق).
- **المستخدم:** مستخدم شخصي واحد (لا accounts ولا cloud sync ولا App Store).
- **الكود المحظور لمسه:** كل ما يخص الـ Bike (`lib/services/ride_controller.dart` وباقي شاشات الدراجة).
- **نظام التمارين:** Free Selection (بدون جداول مسبقة).
- **الوزن:** كيلوجرام فقط (`kg`) مع أزرار الزيادة السريعة (+2.5, +5, +10).

---

## ⏭️ التعليمات للمهمة القادمة (Next Step)
تنفيذ المهمتين `GYM-P1-002` و `GYM-P1-003` (مقارنة محركي الـ 3D: Three.js عبر InAppLocalhostServer مقابل RealityKit على iOS) وتحقيق:
1. Tap Selection للعضلات.
2. Continuous Touch Scrubbing في Explore Mode.
3. تدوير 360 درجة في Orbit Mode.
4. قياس معدل الإطارات (FPS) واستهلاك الذاكرة على شاشة الـ 120Hz.
