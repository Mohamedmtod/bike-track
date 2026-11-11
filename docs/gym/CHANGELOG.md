# 📝 ProBike Gym — Changelog (`CHANGELOG.md`)

> **قاعدة:** يتم تسجيل التغييرات المكتملة فعلياً فقط بعد اجتياز الاختبارات، وليس المهام المخطط لها.

---

## [Unreleased] — Phase 3: Workout Engine & Real-Time Logging
### Added
- دعم خوارزمية الملء الذكي المسبق `Ghost Pre-fill` بلمسة واحدة (`GYM-P3-002`):
  - عرض الأداء السابق المسجل من آخر جلسة مكتملة كنص باهت بجانب المجموعة (`Ghost Text`).
  - دعم زر نسخ الأداء السابق بلمسة واحدة مع ملء الوزن والعدات فوراً في شجرة العناصر وحفظها في SQLite.
  - نافذة تعديل الأوزان السريعة مع شرائح الضبط المباشر (`[-10, -5, -2.5, +2.5, +5, +10 kg]`) وحقل رقمي يدوي.
- دعم أنواع المجموعات المتعددة والأطراف والتمارين الزمنية (`GYM-P3-003`):
  - إضافة شارة نوع المجموعة القابلة للنقر للتبديل الدوري السلس: `WORKING` (أخضر/أبيض)، `WARMUP` (عنبر)، `DROP` (بنفسجي).
  - دعم تسجيل التمارين الأحادية `unilateral` مع شارة تبديل الأطراف: `L` (يسار - سماوي)، `R` (يمين - وردي)، `B` (كلا الطرفين).
  - دعم التمارين الزمنية `durationOnly` (مثل البلانك) مع عداد ثوانٍ قابل للتعديل بخطوات 5 ثوانٍ (`-5s` / `+5s`).
- مؤقت الراحة التنازلي التلقائي بالساعة الرتيبة `Monotonic Rest Timer` (`GYM-P3-004`):
  - حساب الفارق الزمني عبر `DateTime.now()` مقابل `restTargetEndTime` لمنع أي انجراف أو تخطي للوقت عند وضع التطبيق في الخلفية.
  - تخزين `rest_ends_at_utc` في SQLite واستئناف العداد بدقة عند استعادة التطبيق.
- الحفظ اللحظي والاستعادة ضد الانهيار `Crash-Safe State Recovery` (`GYM-P3-007`):
  - تطبيق نمط التحديث المتفائل السريع (Optimistic UI Updates) مع حفظ كافة التعديلات مباشرة في SQLite.
- ميزة استبدال التمرينة لحظياً `Exercise Swap` (`GYM-P3-008`):
  - إضافة قائمة خيارات ثلاثية النقاط لكل تمرين تتضمن استبدال التمرينة ببديل يستهدف نفس العضلة الأساسية دون فقدان هيكل الجلسة.
- كتابة وتوسيع حزمة اختبارات `test/gym/active_workout_screen_test.dart` إلى 10 اختبارات شاملة ناجحة 100%.

### Verified
- اجتياز اختبارات شاشة التمرين اللحظي وكافة ميزات Phase 3 بنجاح (10/10 Tests Passed).
- اجتياز كامل حزمة اختبارات الجيم (38/38 Tests Passed).
- اجتياز كامل حزمة اختبارات المشروع (194/194 Tests Passed).
- 0 أخطاء و 0 تحذيرات في فحص `flutter analyze`.

---

## [Unreleased] — Phase 2: Gym Foundation & Data Pipeline
### Added
- تطوير شاشة تفاصيل العضلة `MuscleDetailScreen` (`lib/features/gym/presentation/screens/muscle_detail_screen.dart`):
  - إضافة استعلام استرجاع آخر أداء مسجل `getLastPerformanceForExercises` في `ExerciseRepository`.
  - إظهار شارة الأداء السابق `Last: X kg × Y` أو `Last: Xs` أو `New (جديد)` تلقائياً على كل بطاقة تمرين.
  - إضافة ورقة تفاصيل التمرين السفلية (Modal Bottom Sheet) لعرض تعليمات التكنيك، والمعدات، ومؤشرات الأداء.
  - إضافة زر الإضافة المباشرة للجلسة التدريبية الفعالة `Add to Workout (إضافة للتمرين)` وتوليد الجلسة تلقائياً إذا لم تكن قيد التشغيل.
- كتابة حزمة اختبارات شاشة تفاصيل العضلة وشارات الأداء `test/gym/muscle_detail_screen_test.dart`.
- إضافة حزمة `flutter_inappwebview` لتشغيل حزمة الـ 3D محلياً على iOS عبر InAppLocalhostServer.
- بناء شاشة المجسم ثلاثي الأبعاد التفاعلية `Muscle3DScreen` (`lib/features/gym/presentation/screens/muscle_3d_screen.dart`) المتضمنة:
  - شريط تحكم عائم للتبديل السريع بين وضعي الاستكشاف `Explore Mode` (لمس ومسح العضلات <0.4ms BVH) والتدوير `Orbit Mode` (تدوير 360 درجة وتقريب).
  - زر تبديل زاوية الكاميرا الفورية (`FRONT` / `BACK`) لرؤية عضلات الصدر والبطن أو الظهر والخلفيات.
  - لافتة HUD حية تظهر اسم العضلة المحومة باللغتين العربية والإنجليزية.
  - شريط أفقي سفلي لجميع العضلات الـ 18 للوصول السريع مع دعم التحديد التلقائي.
  - بطاقة إجراءات سفلية للعضلة المختارة مع زر الانتقال المباشر لتمارين العضلة `View Targeted Exercises`.
- كتابة حزمة اختبارات شاشة الـ 3D التفاعلية `test/gym/muscle_3d_screen_test.dart`.
- إنشاء مستودعات البيانات: `MuscleRepository`، `ExerciseRepository`، و `WorkoutRepository` مع نماذج `WorkoutSession` و `SetLog`.
- بناء واجهة `GymDashboardScreen` بتصميم داكن OLED Black وحاويات Titanium Dark مع دعم استعراض العضلات، ومتابعة الجلسات الفعالة والسابقة، وزر بدء تمرين حر `Start Free Workout`.
- بناء واجهة `MuscleDetailScreen` لعرض بيانات العضلة والتمارين المستهدفة ومعداتها وأنواع التسجيل.
- إضافة زر الدخول للجيم `gym_button` في شريط تطبيق الدراجة الرئيسي `DashboardScreen` مع عزل تام لمنطق التيليمتري.
- إضافة حزمة اختبارات واجهة المستخدم والتنقل `test/gym/gym_dashboard_navigation_test.dart`.
- إنشاء نماذج البيانات الأساسية للجيم (`lib/features/gym/models/muscle.dart` و `lib/features/gym/models/exercise.dart`).
- إضافة خدمة بذر البيانات الكاملة (`lib/features/gym/data/gym_seed_data.dart`) متضمنة:
  - 18 مجموعة عضلية مطابقة لبيانات الـ 3D والتشريح الطبي.
  - 126 ربط مجسم (Mesh Bindings) يربط كل عقدة 3D بالعضلة والطرف المناسب.
  - 32 تمريناً أساسياً شاملاً لكافة عضلات الجسم بأنواع تسجيل متعددة (`weightAndReps`, `bodyweightReps`, `durationOnly`).
  - ربط كامل للأهداف الأولية والثانوية في جدول `EXERCISE_MUSCLE`.
- تهيئة البذر التلقائي عند أول إنشاء لقاعدة البيانات مع ضمان عدم تكرار البذر (Idempotent Seed Execution).
- كتابة حزمة اختبارات بذر البيانات (`test/gym/seed_data_test.dart`).

### Verified
- اجتياز اختبارات شاشة تفاصيل العضلة وشارات الأداء بنجاح (3/3 Tests Passed).
- اجتياز اختبارات شاشة الـ 3D التفاعلية بنجاح (5/5 Tests Passed).
- اجتياز اختبارات واجهة المستخدم والتنقل بنجاح (4/4 Tests Passed).
- اجتياز اختبارات بذر البيانات بنجاح (5/5 Tests Passed).
- اجتياز جميع اختبارات موديول الجيم (28/28 Tests Passed).
- اجتياز حزمة الاختبارات الشاملة للتطبيق بنسبة 100% (184/184 Tests Passed).
- اكتمال المرحلة الثانية (Phase 2 — Gym Foundation) بنسبة 100%.
- خلو الكود تماماً من أي أخطاء أو تحذيرات في `flutter analyze`.

---

## [Unreleased] — Phase 1: 3D Proof of Concept & Engine Selection
### Added
- تجهيز موديل الـ 3D التشريحي المقسم (`assets/gym/models/male_anatomy.glb`) بحجم 5.07 MB وبنية مضلعات محسّنة لضمان استقرار 120 FPS على iPhone 14 Pro.
- إضافة ملف بيانات الربط التشريحي الكامل (`assets/gym/models/manifest.json`) المغطي لـ 126 عضلة منفصلة موزعة على 18 مجموعة عضلية رئيسية.
- إضافة وثائق التراخيص والمصدر المفتوح (`CC-BY-SA-4.0.txt`, `LICENSE.txt`, `NOTICE.txt`, `UPSTREAM-LICENSE.txt`).
- إنشاء حزمة الويب المستقلة بالكامل لـ Three.js (`assets/gym/web/gym_viewer_bundle.js` بحجم 726 KB) مع تسريع BVH Raycasting والربط مع Flutter.
- إنشاء صفحة الويب المهيأة لشاشات OLED (`assets/gym/web/index.html`) مع دعم وضعي `explore` و `orbit` وأزرار التحكم.
- كتابة تقرير إثبات المفهوم الشامل (`docs/gym/3D_POC_REPORT.md`) واعتماد محرك Three.js رسمياً لـ ProBike Gym.
- كتابة حزمة اختبارات سلامة وتكامل الـ 3D والويب (`test/gym/asset_validation_test.dart`).

### Verified
- اجتياز اختبارات سلامة وتكامل الـ 3D والويب بنجاح (8/8 Tests Passed).
- تطابق 100% بين أسماء العضلات في `manifest.json` وأسماء الـ Meshes داخل هيكل الـ GLB.
- اجتياز حزمة الاختبارات الكلية للتطبيق بنسبة 100% (164/164 Tests Passed) دون أي تراجع في كود الدراجة.
- نجاح التحليل البرمجي الثابت الكامل (`flutter analyze`) بـ 0 تحذيرات و 0 أخطاء.

---

## [Unreleased] — Phase 0: Technical Audit & Agent Governance Hub
### Added
- تجهيز وثيقة الخطة الهندسية الشخصية المعتمدة (`new-plan.md`).
- إنشاء مجلد حوكمة الـ Agent والتشغيل السريع (`docs/gym/STATUS.md`, `docs/gym/TASKS.md`, `docs/gym/CODEMAP.md`, `docs/gym/TEST_PLAN.md`).
- تحديد مصفوفة عزل كود الجيم التام عن تتبع الدراجة (`docs/gym/BIKE_TRACKING_INVARIANTS.md`).
- إتمام تقرير الفحص الفني للبيئة الحالية (`docs/gym/TECHNICAL_AUDIT.md`).
- توثيق المعمارية الحالية ونقاط التكامل المقترحة (`docs/gym/EXISTING_ARCHITECTURE.md`).
- توثيق دراسة توافق الحزم ومحركات الـ 3D على iOS (`docs/gym/DEPENDENCY_COMPATIBILITY.md`).
- وضع خطة التكامل المعمارية التفصيلية (`docs/gym/GYM_MODULE_INTEGRATION_PLAN.md`).
- تحديث فهرس التوثيق العام ومستند سياق الوكلاء (`docs/README.md`, `AGENT_CONTEXT.md`, `README.md`).

### Verified
- تشغيل واجتياز حزمة الاختبارات الكاملة لـ ProBike بنجاح بنسبة 100% (156/156 Tests Passed).
- التحقق من دعم iOS 15.0+ في `ios/Runner.xcodeproj` ورفع الهدف لـ iOS 16.1+ لـ Live Activities.
- التحقق من إصدار Flutter `3.47.7` و Dart `3.13.5`.
