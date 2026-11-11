# 📦 ProBike — Dependency & Compatibility Report (`DEPENDENCY_COMPATIBILITY.md`)

> **تاريخ الفحص:** 11 نوفمبر 2026  
> **الإصدارات المعتمدة:** Flutter `3.47.7` • Dart `3.13.5` • iOS `15.0+`

---

## 1. التبعيات الحالية وتوافقها (Current Dependencies)

جميع التبعيات المنصبة حالياً في `pubspec.yaml` متوافقة ومستقرة:
- `flutter_localizations`: SDK
- `cupertino_icons: ^1.0.8`: متوافق
- `supabase_flutter: ^2.18.3`: متوافق
- `geolocator: ^14.1.2`: متوافق
- `flutter_map: ^8.3.2`: متوافق
- `latlong2: ^0.10.1`: متوافق
- `app_links: ^7.2.2`: متوافق
- `flutter_local_notifications: ^22.3.2`: متوافق
- `shared_preferences: ^2.5.6`: متوافق
- `wakelock_plus: ^1.8.0`: متوافق
- `share_plus: ^13.3.1`: متوافق
- `path_provider: ^2.1.6`: متوافق
- `connectivity_plus: ^7.3.1`: متوافق

---

## 2. التبعيات الجديدة المعتمدة للـ Gym Module

لتنفيذ متطلبات الجيم بدون زيادة حجم التطبيق ودون أي تعارضات:

| الحزمة (Package) | الغرض منها | سبب الاختيار والتوافق | مرحلة الإضافة |
|---|---|---|---|
| **`sqflite`** (`^2.4.x`) | قاعدة بيانات SQLite محلية للجيم | تدعم وضع WAL، وThread-safe، وتعمل محلياً 100% بدون أي حاجة للإنترنت. | Phase 2 |
| **`path`** (`^1.9.x`) | معالجة مسارات قواعد البيانات المحلية | حزمة رسمية قياسية من فريق Dart. | Phase 2 |
| **`flutter_inappwebview`** | (مرشح خيار Three.js) | يوفر `InAppLocalhostServer` لتجاوز مشكلة CORS لملفات الـ GLB على iOS. | Phase 1 (PoC) |

---

## 3. توافقية محرك الـ 3D على iOS

### المرشح الأول: RealityKit (Native Swift via PlatformView)
- **التوافقية:** مدمج في نظام iOS من شركة Apple رسمياً.
- **المزايا:** أداء فائق بمعدل 60-120 FPS بدون أي استهلاك زائد للرام، ودعم كامل لـ Dynamic Island والـ Metal Shaders.
- **التقييم:** ممتاز، ولا يتطلب أي حزم Pub خارجية.

### المرشح الثاني: Three.js داخل Local WebView
- **التوافقية:** مدعوم عبر `WKWebView` و WebGL2 على نظام iOS.
- **المزايا:** كود JavaScript موحد ومرونة فائقة في تعديل الـ Shaders والـ Camera Focus.
- **التحدي:** يتطلب تشغيل سيرفر محلي `InAppLocalhostServer` لتحميل ملفات الـ GLB لتفادي حظر بروتوكول `file://`.
- **التقييم:** سيتم قياسه ومقارنته في Phase 1.

