# 📍 ProBike Gym — Project Status (Live Working State)

> **الغرض:** هذا الملف هو أول ما يقرأه الـ AI Agent في بداية أي جلسة لمعرفة مكان وقوفه الحالي والمهمة التالية مباشرة، بدلاً من قراءة وثيقة الخطة الكاملة.
> **آخر تحديث:** 12 نوفمبر 2026.

---

## 🎯 الوضع الحالي (Current State)

| البند | القيمة الحالية |
|---|---|
| **المرحلة الحالية:** | **COMPLETED & HARDWARE-READY — All Phases (0-4) + Real Live Activities + In-App Diagnostics HUD Implemented** |
| **آخر مهمة مكتملة:** | تنفيذ ActivityKit الأصلي في Swift مع ويدجت SwiftUI للجزيرة التفاعلية (`GymRestLiveActivity`)، إضافة HUD تشخيصي لحظي 120 FPS داخل WebGL، وتوثيق بروتوكول الفحص العتادي `HARDWARE_VERIFICATION_PROTOCOL.md` |
| **المهمة قيد التنفيذ:** | جاهز للتجربة الميدانية والفحص العتادي على iPhone 14 Pro (iOS 16.1+) |
| **المهمة التالية:** | الفحص الميداني للأداء (120 FPS ProMotion، استجابة الجزيرة التفاعلية، ومزامنة العجلة مع الجيم) |
| **فرع Git النشط:** | `feature/gym-personal` |
| **حالة البناء (Build):** | مستقر تماماً (225/225 Passing Tests بنسبة 100%، 0 أخطاء في flutter analyze) |
| **الحظر الحالي (Blockers):** | لا يوجد أي موانع إطلاقاً |

---

## 🔒 الثوابت التشغيلية النشطة (Active Invariants)
- **المنصة والعتاد:** iOS 16.1+ حصرياً (iPhone 14 Pro لدعم Live Activities والجزيرة التفاعلية Dynamic Island).
- **المستخدم:** مستخدم شخصي واحد (لا accounts ولا cloud sync ولا App Store).
- **كود الدراجة وتيليمتري الـ GPS:** حماية تامة لمنطق الدراجة، مع وجود نقطة دخول تنقل محكومة (`gym_button`) في شريط أدوات `DashboardScreen`.
- **عزل التخزين:** قاعدة بيانات SQLite (`probike_gym.db`) خاصة بالجيم فقط، وربط الدراجة لقراءة أحمال الـ Heatmap يتم كـ Read-Only عبر `GymBikeBridge` دون داتابيز مشتركة.
- **نطاق العمل دون اتصال:** موديول الجيم يعمل 100% Offline-First.
- **نظام التمارين:** Free Selection (بدون جداول مسبقة).
- **الوزن:** كيلوجرام فقط (`kg`) مع أزرار الزيادة السريعة (+2.5, +5, +10).
- **محرك الـ 3D المعتمد:** Three.js محلياً عبر InAppLocalhostServer مع تسريع three-mesh-bvh وموديل Z-Anatomy المرخص (CC-BY-SA-4.0).

---

## ⏭️ خطوة التشغيل والتجربة الفورية (How to Run & Test Now)
1. تشغيل التطبيق محلياً: `flutter run` أو البناء للآيفون عبر Xcode / SideStore.
2. من الشاشة الرئيسية (Dashboard)، اضغط على أيقونة الجيم الحمراء/الفسفورية (`gym_button`) في شريط الأدوات العلوي.
3. استكشف مجسم الـ 3D، خريطة الإجهاد الحرارية، تسجيل التمرين الحر، ومؤقت الراحة مع Live Activities والنسخة الاحتياطية.
