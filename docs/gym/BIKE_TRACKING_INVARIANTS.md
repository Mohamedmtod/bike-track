# 🛡️ ProBike — Bike Tracking Invariants (`BIKE_TRACKING_INVARIANTS.md`)

> **تنبيه إلزامي لأي AI Agent:** هذه الوثيقة تمثل القواعد الصارمة التي تحظر التعديل في كود الدراجة. أي تعديل أو تجاوز لهذه القواعد يُعتبر خرقاً لجودة واستقرار التطبيق.

---

## 🚫 الممنوعات الصارمة (Strict Prohibitions)

1. **حظر تعديل ملفات الدراجة الأساسية:**
   - يمنع منعاً باتاً تعديل ملفات:
     - `lib/services/ride_controller.dart` (عقل التطبيق وفلتر الـ GPS).
     - `lib/models/ride_model.dart` (كيان الرحلة والبيانات).
     - `lib/screens/live_ride_screen.dart` (شاشة التسجيل الحي).
     - `lib/screens/dashboard_screen.dart` (شاشة رحلات العجلة).
     - `lib/screens/daily_stats_screen.dart` و `lib/screens/overall_stats_screen.dart`.
     - `lib/services/supabase_service.dart` و `lib/services/telemetry_service.dart`.

2. **حظر مشاركة جداول قاعدة البيانات المباشرة:**
   - لا يجوز لجداول الجيم (`gym_*`) التداخل مع مفاتيح الـ `SharedPreferences` الخاصة بالدراجة (`rides_cache_key`, `pending_sync_rides_key`).
   - تعامل الجيم مع بيانات الدراجة مقتصر بنسبة 100% على **القراءة فقط (Read-Only)** عبر `gym_bike_bridge.dart` لاستخراج مسافات وأوقات الرحلات لحساب الـ 3D Heatmap.

3. **حظر تشويش دورة حياة التطبيق في الخلفية:**
   - الدراجة تستخدم `UIBackgroundModes: location` مع ضبط صارم للـ Wakelock والـ GPS watchdog.
   - لا يجوز لأي مؤقت راحة في الجيم أن يستدعي أو يوقف خدمات الموقع في الخلفية الخاصة بالدراجة.

---

## ✅ الثوابت الخمسة للدراجة (The 5 Invariants)

1. **فلتر الـ GPS رباعي الطبقات (4-Layer GPS Filter):**
   - رفض أي نقطة بدقة أفقية > 20 متر.
   - كشف التوقف عبر الدوبلر وسرعات ≤ 2.5 كم/ساعة.
   - فلترة الاهتزازات الدقيقة ≤ 3 أمتار.
   - حماية القفزات والأنفاق بسرعة > 65 كم/ساعة.

2. **تزامن الوقت مع ساعة الحائط (Wall-Clock Synchronization):**
   - الحسابات تعتمد دائماً على `DateTime.now().difference(startTime)` وليس على نبضات التايمر المجردة.

3. **حماية الصفر واللانهاية (Zero NaN / Zero Infinity Defense):**
   - أي عملية قسمة تخضع للتحقق: `durationSeconds > 0 && distanceMeters > 0`.

4. **الحفظ المحلي أولاً (Local Write Before Remote):**
   - كل رحلة تُكتب محلياً قبل التفكير في إرسالها لأي سيرفر.

5. **خرائط Stadia Alidade Smooth Dark:**
   - مفتاح الخريطة يُحقن وقت البناء بـ `--dart-define=STADIA_MAPS_API_KEY`.
   - لا يُسمح بأي طلب شبكة غير مصرح؛ استخدام `SafeEmptyTileProvider` تلقائياً عند غياب المفتاح.

