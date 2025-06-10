import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'theme/themes.dart';
import 'screens/login_page.dart';
import 'screens/dashboard_page.dart';
// import 'attendance_history_page.dart';
// import 'apply_leave_page.dart';
// import 'team_attendance_page.dart';
// import 'leave_requests_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Set the highest refresh rate supported by the device
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (e) {
    debugPrint('Failed to set high refresh rate: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Codm Go',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        // Add routes when available
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
