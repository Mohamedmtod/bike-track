import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'l10n/locale_controller.dart';
import 'screens/dashboard_screen.dart';
import 'screens/live_ride_screen.dart';
import 'services/notification_service.dart';
import 'services/ride_controller.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

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

  // 3. Create RideController, ThemeController & LocaleController
  final rideController = RideController();
  final themeController = ThemeController();
  await themeController.init();
  final localeController = LocaleController();
  await localeController.init();

  runApp(BikeTrackApp(
    rideController: rideController,
    themeController: themeController,
    localeController: localeController,
  ));
}

class BikeTrackApp extends StatefulWidget {
  final RideController rideController;
  final ThemeController? themeController;
  final LocaleController? localeController;

  const BikeTrackApp({
    super.key,
    required this.rideController,
    this.themeController,
    this.localeController,
  });

  @override
  State<BikeTrackApp> createState() => _BikeTrackAppState();
}

class _BikeTrackAppState extends State<BikeTrackApp> {
  late final ThemeController _themeController =
      widget.themeController ?? ThemeController();
  late final LocaleController _localeController =
      widget.localeController ?? LocaleController();
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final List<Uri> _linkQueue = [];
  bool _isProcessingQueue = false;
  String? _lastHandledLink;
  DateTime? _lastHandledTime;
  bool _isLiveScreenOpen = false;

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

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // 1. Subscribe to link stream early before awaiting getInitialLink()
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _enqueueDeepLink(uri);
      },
      onError: (_) {},
    );

    // 2. Check getInitialLink()
    _appLinks.getInitialLink().then((initialUri) {
      if (initialUri != null) {
        _enqueueDeepLink(initialUri);
      }
    }).catchError((_) {});
  }

  void _enqueueDeepLink(Uri uri) {
    final uriStr = uri.toString().toLowerCase();

    // Deduplication check: ignore duplicate rapid NFC taps within 1500ms
    final now = DateTime.now();
    if (_lastHandledLink == uriStr &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!).inMilliseconds < 1500) {
      return;
    }
    _lastHandledLink = uriStr;
    _lastHandledTime = now;

    _linkQueue.add(uri);
    _processLinkQueue();
  }

  Future<void> _processLinkQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      while (_linkQueue.isNotEmpty) {
        final uri = _linkQueue.removeAt(0);

        // Ensure navigator is ready and first frame rendered
        if (navigatorKey.currentState == null) {
          final completer = Completer<void>();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            completer.complete();
          });
          await completer.future;
        }

        final uriString = uri.toString().toLowerCase();

        if (uriString.startsWith('cycletrack://start') ||
            uriString.startsWith('probike://start')) {
          final started = await widget.rideController.startRide();
          if (started || widget.rideController.isRiding) {
            if (!_isLiveScreenOpen && navigatorKey.currentState != null) {
              _isLiveScreenOpen = true;
              navigatorKey.currentState!
                  .push(
                MaterialPageRoute(
                  builder: (_) => LiveRideScreen(
                    controller: widget.rideController,
                    themeController: _themeController,
                    localeController: _localeController,
                  ),
                ),
              )
                  .then((_) {
                _isLiveScreenOpen = false;
              });
            }
          }
        } else if (uriString.startsWith('cycletrack://stop') ||
            uriString.startsWith('probike://stop')) {
          if (widget.rideController.isRiding) {
            await widget.rideController.stopRide();
          }
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.popUntil((route) => route.isFirst);
            _isLiveScreenOpen = false;
          }
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_themeController, _localeController]),
      builder: (context, _) {
        final tokens = _themeController.currentTheme;
        final strings = _localeController.strings;

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: strings.appName,
          debugShowCheckedModeBanner: false,
          theme: tokens.toThemeData(),
          locale: _localeController.flutterLocale,
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            // If running on desktop / web preview (width > 450), center inside iPhone 14 Pro Chassis
            if (mediaQuery.size.width > 450) {
              return _buildDesktopIPhonePreview(context, child!, tokens);
            }
            return child!;
          },
          home: DashboardScreen(
            controller: widget.rideController,
            themeController: _themeController,
            localeController: _localeController,
          ),
        );
      },
    );
  }

  Widget _buildDesktopIPhonePreview(
      BuildContext context, Widget child, AppThemeTokens tokens) {
    const frameWidth = 393.0;
    const frameHeight = 852.0;

    return Directionality(
      textDirection: _localeController.textDirection,
      child: Scaffold(
        backgroundColor: tokens.background,
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
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tokens.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_iphone, color: tokens.primary, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _localeController.strings.desktopPreviewLabel,
                      style: TextStyle(
                        color: tokens.textSecondary,
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
    ),
    );
  }
}
