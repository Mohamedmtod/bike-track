# 📝 ProBike Gym — Changelog (`CHANGELOG.md`)

> **قاعدة:** يتم تسجيل التغييرات المكتملة فعلياً فقط بعد اجتياز الاختبارات، وليس المهام المخطط لها.

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
- التحقق من دعم iOS 15.0+ في `ios/Runner.xcodeproj`.
- التحقق من إصدار Flutter `3.47.7` و Dart `3.13.5`.
