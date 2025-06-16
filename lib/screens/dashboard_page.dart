import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codmgo2/screens/clock_in_out.dart';
import 'package:codmgo2/screens/attendence_history.dart';
import 'package:codmgo2/utils/clock_in_out_logic.dart';
import 'package:codmgo2/utils/bottom_navigation_bar.dart';
import 'package:codmgo2/utils/recent_activity.dart';
import 'package:codmgo2/utils/dashboard_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animations/animations.dart';
import 'package:codmgo2/utils/dashboard_ui_components.dart';

import 'leave_dashboard.dart'; // Import the UI components file

class DashboardPage extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String employeeId;

  const DashboardPage({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.employeeId,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  late final ClockInOutController clockInOutController;
  late final DashboardLogic dashboardLogic;
  late AnimationController _scaleAnimationController;
  late AnimationController _clockInButtonController;
  late AnimationController _clockOutButtonController;
  late AnimationController _pageTransitionController;
  late AnimationController _locationAnimationController;
  late AnimationController _clockButtonPulseController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _locationRotationAnimation;
  late Animation<double> _clockButtonPulseAnimation;
  int _currentIndex = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    clockInOutController = ClockInOutController();
    clockInOutController.addListener(_onClockStatusChanged);

    dashboardLogic = DashboardLogic();
    dashboardLogic.addListener(_onLocationStatusChanged);

    _initializeAnimationControllers();
    _initializeDashboard();
  }

  void _initializeAnimationControllers() {
    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _clockInButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _clockOutButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _pageTransitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _locationAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _clockButtonPulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(
      parent: _scaleAnimationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageTransitionController,
      curve: Curves.easeInOut,
    ));

    _locationRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _locationAnimationController,
      curve: Curves.easeInOut,
    ));

    _clockButtonPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _clockButtonPulseController,
      curve: Curves.easeInOut,
    ));

    // Start the pulse animation and repeat
    _clockButtonPulseController.repeat(reverse: true);
  }

  Future<void> _initializeDashboard() async {
    await dashboardLogic.initialize();
  }

  @override
  void dispose() {
    clockInOutController.removeListener(_onClockStatusChanged);
    clockInOutController.dispose();
    dashboardLogic.removeListener(_onLocationStatusChanged);
    dashboardLogic.dispose();
    _scaleAnimationController.dispose();
    _clockInButtonController.dispose();
    _clockOutButtonController.dispose();
    _pageTransitionController.dispose();
    _locationAnimationController.dispose();
    _clockButtonPulseController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
      });
    }
  }

  void _onClockStatusChanged() {
    if (mounted) setState(() {});
  }

  void _onLocationStatusChanged() {
    if (mounted) {
      setState(() {});

      if (dashboardLogic.isLocationChecking) {
        _locationAnimationController.repeat();
      } else {
        _locationAnimationController.stop();
        _locationAnimationController.reset();
      }
    }
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    _pageTransitionController.forward();

    dashboardLogic.showUpdatingLocationSnackbar(context);
    await dashboardLogic.checkLocationRadius();

    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email') ?? 'default@example.com';
    await clockInOutController.initializeEmployeeData(userEmail);

    await Future.delayed(const Duration(milliseconds: 2000));

    if (mounted) {
      _pageTransitionController.reverse();
      setState(() => _isRefreshing = false);

      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          dashboardLogic.showLocationSnackbar(context);
        }
      });
    }
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0:
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LeaveDashboardPage(employeeId: widget.employeeId), // make sure this page exists
          ),
        ).then((_) {
          setState(() {
            _currentIndex = 0;
          });
        });
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceHistoryPage(employeeId: widget.employeeId),
          ),
        ).then((_) {
          setState(() {
            _currentIndex = 0;
          });
        });
        break;
      case 3:
        break;
    }
  }

  void _onLocationIconTap() {
    if (dashboardLogic.isLocationChecking) {
      dashboardLogic.showLocationSnackbar(context);
    } else {
      dashboardLogic.showUpdatingLocationSnackbar(context);

      dashboardLogic.checkLocationRadius().then((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            dashboardLogic.showLocationSnackbar(context);
          }
        });
      });
    }
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    return "${hour.toString().padLeft(2, '0')}:$minute";
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return "${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}";
  }

  Color _getLocationStatusColor(bool isDarkMode) {
    if (dashboardLogic.isLocationChecking) {
      return Colors.blueAccent;
    } else if (dashboardLogic.isWithinRadius) {
      return Colors.green;
    } else {
      return Colors.red;
    }
  }

  IconData _getLocationIcon() {
    if (dashboardLogic.isLocationChecking) {
      return Icons.location_searching;
    } else if (dashboardLogic.isWithinRadius) {
      return Icons.location_on;
    } else {
      return Icons.location_off;
    }
  }

  String _getLocationText() {
    if (dashboardLogic.isLocationChecking) {
      return "Checking location...";
    } else if (dashboardLogic.isWithinRadius) {
      return "You are in Office reach";
    } else {
      return "You are not in Office reach";
    }
  }

  List<Map<String, dynamic>> _getRecentActivities() {
    List<Map<String, dynamic>> activities = [];

    if (clockInOutController.inTime != null) {
      final inTime = clockInOutController.inTime!;
      final hour = inTime.hour > 12 ? inTime.hour - 12 : (inTime.hour == 0 ? 12 : inTime.hour);
      activities.add({
        'time': "${hour.toString().padLeft(2, '0')}:${inTime.minute.toString().padLeft(2, '0')}",
        'label': 'Clock In',
        'icon': Icons.login,
        'color': Colors.green,
      });
    }

    if (clockInOutController.outTime != null) {
      final outTime = clockInOutController.outTime!;
      final hour = outTime.hour > 12 ? outTime.hour - 12 : (outTime.hour == 0 ? 12 : outTime.hour);
      activities.add({
        'time': "${hour.toString().padLeft(2, '0')}:${outTime.minute.toString().padLeft(2, '0')}",
        'label': 'Clock Out',
        'icon': Icons.logout,
        'color': Colors.red,
      });
    }

    // Add working hours if both times are available
    if (clockInOutController.inTime != null && clockInOutController.outTime != null) {
      final workingDuration = clockInOutController.outTime!.difference(clockInOutController.inTime!);
      final hours = workingDuration.inHours;
      final minutes = workingDuration.inMinutes % 60;
      activities.add({
        'time': "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}",
        'label': 'Working Hrs',
        'icon': Icons.schedule,
        'color': Colors.blue,
      });
    }

    // Fill with placeholder if not enough activities
    while (activities.length < 3) {
      activities.add({
        'time': '--:--',
        'label': 'No Data',
        'icon': Icons.schedule,
        'color': Colors.grey,
      });
    }

    return activities.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 80,
        title: Row(
          children: [
            // User Info Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${widget.firstName}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF2C2C2C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getCurrentDate(),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Location Status Section
            GestureDetector(
              onTap: _onLocationIconTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _getLocationStatusColor(isDarkMode).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: _getLocationStatusColor(isDarkMode).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _locationRotationAnimation,
                      builder: (Context, child) {
                        return Transform.rotate(
                          angle: dashboardLogic.isLocationChecking
                              ? _locationRotationAnimation.value * 2 * 3.14159
                              : 0,
                          child: Icon(
                            _getLocationIcon(),
                            size: 20,
                            color: _getLocationStatusColor(isDarkMode),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dashboardLogic.isLocationChecking
                          ? "Checking..."
                          : (dashboardLogic.isWithinRadius ? "In Range" : "Out of Range"),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getLocationStatusColor(isDarkMode),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        height: MediaQuery.of(context).size.height -
            AppBar().preferredSize.height -
            MediaQuery.of(context).padding.top -
            85 - bottomPadding, // Account for bottom nav height
        child: SlideTransition(
          position: _slideAnimation,
          child: DashboardUIComponents(
            isDarkMode: isDarkMode,
            getCurrentTime: _getCurrentTime,
            getCurrentDate: _getCurrentDate,
            onLocationIconTap: _onLocationIconTap,
            getLocationIcon: _getLocationIcon,
            getLocationStatusColor: _getLocationStatusColor,
            getLocationText: _getLocationText,
            locationRotationAnimation: _locationRotationAnimation,
            clockInOutController: clockInOutController,
            onClockInTap: () async {
              if (clockInOutController.status != ClockStatus.clockedIn) {
                _clockInButtonController.forward().then((_) {
                  _clockInButtonController.reverse();
                });
                await clockInOutController.clockIn(context);
              }
            },
            getRecentActivities: _getRecentActivities,
            clockButtonPulseAnimation: _clockButtonPulseAnimation,
            dashboardLogic: dashboardLogic,
          ),
        ),
      ),
      extendBody: true, // This allows the body to extend behind the bottom navigation
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
        isDarkMode: isDarkMode,
      ),
    );
  }
}