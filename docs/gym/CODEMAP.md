# 🗺️ ProBike Gym — Architectural Code Map (`CODEMAP.md`)

> **قاعدة ذهبية للـ Agent:** يُمنع تعديل أي ملف في مجلدات الـ Bike (`lib/models/ride_model.dart`, `lib/services/ride_controller.dart`, `lib/screens/live_ride_screen.dart`, إلخ). كل عمل الـ Gym معزول بالكامل داخل مجلداته المخصصة.

---

## 🗂️ هيكل المجلدات والمسؤوليات (Directory Responsibilities)

```
lib/
├── features/
│   └── gym/                        ← [GYM MODULE ROOT] جميع ميزات الجيم معزولة هنا
│       ├── data/                   ← طبقة البيانات (SQLite database, DAOs, seed data)
│       │   ├── gym_database.dart   ← محرك SQLite وتهيئة جداول الجيم مع وضع WAL
│       │   ├── exercise_dao.dart   ← استعلامات التمارين والعضلات
│       │   └── session_dao.dart    ← استعلامات الجلسات ومجموعات SET_LOG
│       ├── domain/                 ← الكيانات والنماذج المجردة (Entities & Enums)
│       │   ├── exercise.dart       ← كائن التمرينة ومحددات نوع الوزن (ExerciseLoggingType)
│       │   ├── muscle.dart         ← كائن العضلة وربطها بالـ Mesh ID
│       │   └── workout_session.dart← كائن الجلسة النشطة وحسابات الأداء
│       ├── presentation/           ← واجهات المستخدم وشاشات الجيم
│       │   ├── dashboard/          ← الشاشة الرئيسية للجيم (GymDashboardScreen)
│       │   ├── muscle_map/         ← شاشة ومجسم الـ 3D (MuscleMapScreen)
│       │   ├── exercise_list/      ← قائمة تمارين العضلة المحددة
│       │   ├── active_workout/     ← شاشة تسجيل المجموعات اللحظية (ActiveWorkoutScreen)
│       │   └── progress/           ← شاشة الرسوم البيانية وتطور الأوزان
│       └── renderer/               ← واجهة محرك الـ 3D (MuscleMapRenderer Interface)
│           ├── muscle_map_renderer.dart  ← واجهة مجردة تسمح بتبديل المحرك بسهولة
│           └── ios_renderer/             ← كود محرك الـ 3D المعتمد لـ iOS (RealityKit أو Three.js)
│
├── shared/                         ← الخدمات والبنية التحتية المشتركة
│   ├── audio/
│   │   └── app_audio_coordinator.dart ← إدارة AVAudioSession المركزية (Spotify-friendly)
│   └── live_activity/
│       └── gym_activity_manager.dart  ← إدارة الجزيرة التفاعلية وشاشة القفل لمؤقت الراحة
│
└── integration/
    └── activity_bridge/
        └── gym_bike_bridge.dart    ← قراءة فقط: جلب ملخصات رحلات العجلة لتلوين الـ Heatmap
```

---

## 🛑 الحدود المعمارية وقواعد الأمان (Invariants)

1. **قاعدة البيانات:** الجيم يستخدم جداول مستقلة (`gym_exercises`, `gym_sessions`, `gym_set_logs`) داخل نفس ملف SQLite المحلي مع تفعيل `PRAGMA journal_mode=WAL;` لضمان عدم حدوث تعارض مع كتابة إحداثيات GPS الخاصة بالدراجة.
2. **الصوت:** لا يتم استخدام `video_player` أو مشغل نغمات بشكل منفصل أبداً؛ كل استدعاء يمر عبر `AppAudioSessionCoordinator` مع خيار `mixWithOthers: true`.
3. **وحدة الوزن:** الكود يتعامل داخلياً وخارجياً مع الكيلوجرام (`kg`) فقط — لا يوجد أي كود لتحويل الباوند.
4. **تكامل العجلة:** كود الـ Gym يستدعي دالة للقراءة فقط عبر `gym_bike_bridge.dart` ولا يكتب في جداول الدراجة على الإطلاق.

