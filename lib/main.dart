import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart'; // For logging
import 'package:codmgo2/utils/location_logic.dart'; // Import LocationLogic
import 'theme/themes.dart';
import 'screens/login_page.dart';
import 'screens/dashboard_page.dart';

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
  final LocationLogic _locationLogic = LocationLogic(); // Instantiate LocationLogic
  final Logger _logger = Logger(); // Logger instance
  StreamSubscription<Position>? _positionStreamSubscription; // To manage location stream

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Simulate app initialization
    await Future.delayed(const Duration(milliseconds: 1500)); // 1.5 seconds

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
        _checkLocation(); // Perform location check when app resumes
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
    return MaterialApp(
      title: 'CodmGo',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(firstName: '', lastName: '', employeeId: ''),
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
    );
  }
}

class PlaceholderWidget extends StatelessWidget {
  final String title;
  const PlaceholderWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
    );
  }
}