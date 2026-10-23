import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'screens/dashboard_screen.dart';
import 'screens/live_ride_screen.dart';
import 'services/notification_service.dart';
import 'services/ride_controller.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: supabaseAnonKey,
  );

  // 2. Initialize Local Notifications
  await NotificationService().init();

  // 3. Create RideController
  final rideController = RideController();

  runApp(BikeTrackApp(rideController: rideController));
}

class BikeTrackApp extends StatefulWidget {
  final RideController rideController;

  const BikeTrackApp({super.key, required this.rideController});

  @override
  State<BikeTrackApp> createState() => _BikeTrackAppState();
}

class _BikeTrackAppState extends State<BikeTrackApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Check initial link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (_) {}

    // Listen to deep link stream
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (_) {},
    );
  }

  void _handleDeepLink(Uri uri) {
    final uriString = uri.toString().toLowerCase();

    if (uriString.startsWith('cycletrack://start')) {
      if (!widget.rideController.isRiding) {
        widget.rideController.startRide();
      }
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => LiveRideScreen(controller: widget.rideController),
        ),
      );
    } else if (uriString.startsWith('cycletrack://stop')) {
      if (widget.rideController.isRiding) {
        widget.rideController.stopRide();
      }
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    const neonLime = Color(0xFFCCFF00);
    const oledBlack = Color(0xFF090A0F);
    const cardSurface = Color(0xFF14161F);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Bike Track',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: oledBlack,
        primaryColor: neonLime,
        colorScheme: const ColorScheme.dark(
          primary: neonLime,
          surface: cardSurface,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        // If running on desktop / web preview (width > 450), center inside iPhone 14 Pro Chassis
        if (mediaQuery.size.width > 450) {
          return _buildDesktopIPhonePreview(context, child!);
        }
        return child!;
      },
      home: DashboardScreen(controller: widget.rideController),
    );
  }

  Widget _buildDesktopIPhonePreview(BuildContext context, Widget child) {
    const frameWidth = 393.0;
    const frameHeight = 852.0;

    return Scaffold(
      backgroundColor: const Color(0xFF040508),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF14161F),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_iphone,
                        color: Color(0xFFCCFF00), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'iPhone 14 Pro Preview (393 × 852)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: frameWidth,
                height: frameHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF090A0F),
                  borderRadius: BorderRadius.circular(54),
                  border: Border.all(
                    color: const Color(0xFF2C2C2E),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.9),
                      blurRadius: 48,
                      spreadRadius: 8,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: const Color(0xFFCCFF00).withValues(alpha: 0.05),
                      blurRadius: 80,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Stack(
                    children: [
                      // Simulated iPhone 14 Pro safe insets (59pt top, 34pt bottom)
                      MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          size: const Size(frameWidth, frameHeight),
                          padding: const EdgeInsets.only(top: 59, bottom: 34),
                          viewPadding:
                              const EdgeInsets.only(top: 59, bottom: 34),
                        ),
                        child: child,
                      ),

                      // Physical Dynamic Island Simulator Mock
                      Positioned(
                        top: 11,
                        left: (frameWidth - 8 - 124) / 2,
                        child: IgnorePointer(
                          child: Container(
                            width: 124,
                            height: 35,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),

                      // Physical Home Indicator Simulator Mock
                      Positioned(
                        bottom: 8,
                        left: (frameWidth - 8 - 134) / 2,
                        child: IgnorePointer(
                          child: Container(
                            width: 134,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
