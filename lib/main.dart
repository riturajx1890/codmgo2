import 'theme/themes.dart';
import 'package:flutter/material.dart';
// Import your page files here when they are created
import 'screens/login_page.dart';
// import 'dashboard_page.dart';
// import 'attendance_history_page.dart';
// import 'apply_leave_page.dart';
// import 'team_attendance_page.dart';
// import 'leave_requests_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Employee Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const PlaceholderWidget(title: 'Dashboard Page'),
        '/attendance-history': (context) => const PlaceholderWidget(title: 'Attendance History Page'),
        '/apply-leave': (context) => const PlaceholderWidget(title: 'Apply Leave Page'),
        '/team-attendance': (context) => const PlaceholderWidget(title: 'Team Attendance Page'),
        '/leave-requests': (context) => const PlaceholderWidget(title: 'Leave Requests Page'),
      },
    );
  }
}

// Placeholder widget for routing until actual pages are implemented
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
