# 🏛️ ProBike — Existing Architecture Audit (`EXISTING_ARCHITECTURE.md`)

> **تاريخ التوثيق:** 11 نوفمبر 2026  
> **الغرض:** توضيح المعمارية الحالية لـ ProBike وتحديد نقطة الاتصال الوحيدة والآمنة للـ Gym Module.

---

## 1. المعمارية الحالية لـ ProBike (Cycling Telemetry)

```mermaid
flowchart TD
    subgraph UI_Layer [شاشات الدراجة الحالية - لا تُمس]
        D[DashboardScreen - العجلة]
        L[LiveRideScreen - الخريطة الحية]
        RD[RideDetailsScreen - تفاصيل الرايد]
        DS[DailyStatsScreen - إحصائيات اليوم]
        OS[OverallStatsScreen - سجل الأرقام]
        S[SettingsScreen - الإعدادات]
    end

    subgraph Core_Controllers [متحكمات الحالة الحالية]
        RC[RideController - عقل الدراجة والـ GPS]
        TC[ThemeController - الثيمات الثلاثة]
        LC[LocaleController - العربية والإنجليزية]
    end

    subgraph Data_Layer [التخزين الحالي]
        SP[(SharedPreferences - الكاش المحلي)]
        SB[(Supabase - السحابة)]
    end

    RC --> SP
    RC --> SB
    RC -.-> UI_Layer
    TC -.-> UI_Layer
    LC -.-> UI_Layer
```

---

## 2. معمارية الدمج النظيف للـ Gym Module

بدلاً من تشابك الكود، سيتم دمج الجيم عبر **نقطة دخول منفصلة في الواجهة** و **جسر تكاملي للقراءة فقط في البيانات**:

```mermaid
flowchart TD
    subgraph App_Root [نقطة الربط الوحيدة في واجهة المستخدم]
        MainHub[شريط التنقل السفلي أو زر سياقي في Dashboard]
    end

    subgraph Bike_Domain [عالم الدراجة - محمي بالكامل]
        RC[RideController]
        RidesData[(سجل الرحلات)]
    end

    subgraph Gym_Bridge [جسر التكامل - قراءة فقط]
        Bridge[gym_bike_bridge.dart\nيطلب ملخص المسافات والمدة فقط]
    end

    subgraph Gym_Domain [عالم الجيم - مستقل 100%]
        GymDashboard[GymDashboardScreen]
        Muscle3D[3D Muscle Map Screen]
        WorkoutEngine[Active Workout Session]
        GymDB[(SQLite Local Database - WAL)]
    end

    MainHub --> D[DashboardScreen الدراجة]
    MainHub --> GymDashboard
    RidesData -.-> Bridge
    Bridge --> Muscle3D
    GymDashboard --> Muscle3D
    GymDashboard --> WorkoutEngine
    WorkoutEngine --> GymDB
```

---

## 3. نقاط التلاقي والدمج المعتمدة (Integration Points)

1. **الواجهة (UI Navigation):**
   - إضافة خيار أو زر انتقال واضح وسلس من شاشة `DashboardScreen` أو شريط تنقل خفيف يقود المستخدم إلى `GymDashboardScreen` داخل `lib/features/gym/presentation/dashboard/`.
2. **البيانات (Data Bridge):**
   - الجيم لا يستعلم عن قاعدة بيانات الدراجة مباشرة، بل يستدعي دالة خفيفة:
     `List<CyclingDaySummary> getRecentCyclingLoad(int days)`
     والتي تُرجع فقط المسافة والمدة لتلوين عضلات الفخذ والسمانة على مجسم الـ 3D (Heatmap).
3. **الثيمات وتجربة الاستخدام:**
   - شاشات الجيم ستستخدم نفس `AppTheme` الحالية للمحافظة على الفخامة الداكنة والتجانس البصري دون كتابة ثيمات مكررة.

