import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:codmgo2/utils/location_logic.dart';
import 'package:codmgo2/utils/profile_logic.dart';
import 'package:codmgo2/screens/profile_screen.dart';
import 'package:codmgo2/utils/bottom_nav_bar.dart';
import 'theme/themes.dart';
import 'screens/login_page.dart';

void main() async {
  // Preserve splash screen until initialization is complete
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    // Set the highest refresh rate supported by the device
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (e) {
    debugPrint('Failed to set high refresh rate: $e');
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final LocationLogic _locationLogic = LocationLogic();
  final Logger _logger = Logger();
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Simulate app initialization
    await Future.delayed(const Duration(milliseconds: 1500));

    // Perform initial location check
    await _checkLocation();

    // Remove splash screen after initialization
    FlutterNativeSplash.remove();
  }

  Future<void> _checkLocation() async {
    try {
      _logger.i('Starting location check');
      final result = await _locationLogic.isWithinRadius();
      if (result['isInRadius']) {
        _logger.i('User is within office radius: ${result['message']}');
      } else {
        _logger.w('User is outside office radius: ${result['message']}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error during location check: $e', error: e, stackTrace: stackTrace);
    }
  }

  void _stopLocationChecks() {
    _logger.i('Stopping location checks');
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  @override
  void dispose() {
    _stopLocationChecks();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _logger.i('App resumed');
        _setDisplayMode();
        _checkLocation();
        break;
      case AppLifecycleState.inactive:
        _logger.i('App inactive');
        _stopLocationChecks();
        break;
      case AppLifecycleState.paused:
        _logger.i('App paused');
        _stopLocationChecks();
        break;
      case AppLifecycleState.detached:
        _logger.i('App detached');
        _stopLocationChecks();
        break;
      case AppLifecycleState.hidden:
        _logger.i('App hidden');
        _stopLocationChecks();
        break;
    }
  }

  Future<void> _setDisplayMode() async {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      _logger.e('Failed to set high refresh rate on resume: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileLogic()),
        // Add other providers here if needed
      ],
      child: MaterialApp(
        title: 'CodmGo',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginPage(),
          '/main': (context) => const MainApp(),
          '/profile': (context) => const ProfilePage(),
        },
        navigatorObservers: [RouteObserver<PageRoute>()],
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.0),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}

// Main app wrapper that contains the bottom navigation
class MainApp extends StatefulWidget {
  final String? firstName;
  final String? lastName;
  final String? employeeId;
  final int initialIndex;

  const MainApp({
    super.key,
    this.firstName,
    this.lastName,
    this.employeeId,
    this.initialIndex = 0,
  });

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late String firstName;
  late String lastName;
  late String employeeId;
  late int initialIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get the arguments passed from login or other screens
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    firstName = widget.firstName ?? args?['firstName'] ?? '';
    lastName = widget.lastName ?? args?['lastName'] ?? '';
    employeeId = widget.employeeId ?? args?['employeeId'] ?? '';
    initialIndex = args?['initialIndex'] ?? widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button from going to login
        return false;
      },
      child: CustomBottomNavBar(
        firstName: firstName,
        lastName: lastName,
        employeeId: employeeId,
        initialIndex: initialIndex,
      ),
    );
  }
}

// Enhanced Navigation Helper class for smooth app navigation
class NavigationHelper {
  // Navigate to main app with bottom navigation
  static Future<void> navigateToMainApp(
      BuildContext context, {
        required String firstName,
        required String lastName,
        required String employeeId,
        int initialIndex = 0,
        bool clearStack = true,
      }) async {
    if (clearStack) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/main',
            (route) => false,
        arguments: {
          'firstName': firstName,
          'lastName': lastName,
          'employeeId': employeeId,
          'initialIndex': initialIndex,
        },
      );
    } else {
      Navigator.pushNamed(
        context,
        '/main',
        arguments: {
          'firstName': firstName,
          'lastName': lastName,
          'employeeId': employeeId,
          'initialIndex': initialIndex,
        },
      );
    }
  }

  // Navigate to specific tab in main app
  static Future<void> navigateToMainAppWithTab(
      BuildContext context, {
        required String firstName,
        required String lastName,
        required String employeeId,
        required int tabIndex,
        bool clearStack = true,
      }) async {
    if (clearStack) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/main',
            (route) => false,
        arguments: {
          'firstName': firstName,
          'lastName': lastName,
          'employeeId': employeeId,
          'initialIndex': tabIndex,
        },
      );
    } else {
      Navigator.pushReplacementNamed(
        context,
        '/main',
        arguments: {
          'firstName': firstName,
          'lastName': lastName,
          'employeeId': employeeId,
          'initialIndex': tabIndex,
        },
      );
    }
  }

  // Navigate to profile with smooth transition
  static Future<void> navigateToProfile(BuildContext context, {String? employeeId}) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ProfilePage(employeeId: employeeId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  static Future<void> navigateToProfileWithUserEmail(
      BuildContext context, String userEmail) async {
    final profileLogic = context.read<ProfileLogic>();
    await profileLogic.initializeEmployeeData(userEmail);

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        const ProfilePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  static Future<void> navigateToProfileNamed(BuildContext context) async {
    await Navigator.pushNamed(context, '/profile');
  }

  // Navigate back to login with smooth transition
  static Future<void> navigateToLogin(BuildContext context) async {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
          (route) => false,
    );
  }

  // Method to update tab index without rebuilding the entire widget
  static void updateTabIndex(BuildContext context, int newIndex) {
    final mainAppState = context.findAncestorStateOfType<_MainAppState>();
    if (mainAppState != null) {
      mainAppState.setState(() {
        mainAppState.initialIndex = newIndex;
      });
    }
  }
}

class PlaceholderWidget extends StatelessWidget {
  final String title;
  const PlaceholderWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}