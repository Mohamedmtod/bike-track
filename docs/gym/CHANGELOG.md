# 📝 ProBike Gym — Changelog (`CHANGELOG.md`)

> **قاعدة:** يتم تسجيل التغييرات المكتملة فعلياً فقط بعد اجتياز الاختبارات، وليس المهام المخطط لها.

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
