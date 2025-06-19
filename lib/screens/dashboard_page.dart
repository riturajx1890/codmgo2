import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codmgo2/screens/attendence_history.dart';
import 'package:codmgo2/utils/dashboard_logic.dart';
import 'package:codmgo2/screens/profile_screen.dart';
import 'package:intl/intl.dart';
import 'leave_dashboard.dart';
import 'package:codmgo2/utils/recent_activity.dart';
import 'package:codmgo2/utils/clock_in_out_core_logic.dart';

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

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  late final DashboardLogic dashboardLogic;
  late final ClockInOutLogic clockInOutLogic;
  late AnimationController scaleAnimationController;
  late Animation<double> scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize dashboard logic
    dashboardLogic = DashboardLogic();
    dashboardLogic.addListener(_onDashboardStateChanged);

    // Initialize clock in/out logic
    clockInOutLogic = ClockInOutLogic();
    clockInOutLogic.addListener(_onClockInOutStateChanged);

    // Initialize animation controller for RecentActivity
    scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    scaleAnimation = CurvedAnimation(
      parent: scaleAnimationController,
      curve: Curves.easeInOut,
    );
    scaleAnimationController.forward();

    // Initialize dashboard with user data
    _initializeDashboard();
  }

  /// Initialize dashboard with user data
  Future<void> _initializeDashboard() async {
    await dashboardLogic.initializeDashboard(
      firstName: widget.firstName,
      lastName: widget.lastName,
      employeeId: widget.employeeId,
    );
  }

  /// Handle dashboard state changes
  void _onDashboardStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Handle clock in/out state changes
  void _onClockInOutStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Handle refresh action
  Future<void> _onRefresh() async {
    await dashboardLogic.onRefresh(context);
  }

  /// Handle bottom navigation tap
  void _onBottomNavTap(int index) {
    dashboardLogic.onBottomNavTap(index);

    // Handle navigation based on index
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LeaveDashboardPage(employeeId: dashboardLogic.displayEmployeeId),
          ),
        ).then((_) {
          dashboardLogic.resetBottomNavToHome();
        });
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceHistoryPage(employeeId: dashboardLogic.displayEmployeeId),
          ),
        ).then((_) {
          dashboardLogic.resetBottomNavToHome();
        });
        break;
      case 3:
        if (dashboardLogic.accessToken == null || dashboardLogic.instanceUrl == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication data not available. Please try again.')),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilePage(),
          ),
        ).then((_) {
          dashboardLogic.resetBottomNavToHome();
        });
        break;
    }
  }

  /// Handle clock in tap
  Future<void> _onClockInTap() async {
    await dashboardLogic.onClockIn(context);
  }

  /// Handle clock out tap
  Future<void> _onClockOutTap() async {
    // Add your clock out logic here
    await dashboardLogic.onClockOut(context);
  }

  /// Handle location icon tap
  void _onLocationIconTap() {
    dashboardLogic.onLocationIconTap(context);
  }

  String _getClockInTime() {
    if (clockInOutLogic.inTime != null) {
      return DateFormat('h:mm a').format(clockInOutLogic.inTime!);
    }
    return "--:-- - ";
  }

  String _getClockOutTime() {
    if (clockInOutLogic.outTime != null) {
      return DateFormat('h:mm a').format(clockInOutLogic.outTime!);
    } else if (clockInOutLogic.status == ClockStatus.clockedIn) {
      return "--:-- - ";
    }
    return "--:-- -";
  }

  @override
  void dispose() {
    // Remove listener and dispose dashboard logic
    dashboardLogic.removeListener(_onDashboardStateChanged);
    dashboardLogic.dispose();
    clockInOutLogic.removeListener(_onClockInOutStateChanged);
    clockInOutLogic.dispose();
    scaleAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2D3748);
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.grey[600];

    // Format current date and time
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, MMM d yyyy');
    final timeFormat = DateFormat('h:mm a');
    final formattedDate = dateFormat.format(now);
    final formattedTime = timeFormat.format(now);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 63,
        title: Row(
          children: [
            // App Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF667EEA),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // User Info Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello,',
                    style: TextStyle(
                      fontSize: 14,
                      color: subtitleColor,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dashboardLogic.displayFirstName.isNotEmpty ? dashboardLogic.displayFirstName : 'User'} ${dashboardLogic.displayLastName}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
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
                  color: dashboardLogic.getLocationStatusColor(isDarkMode).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: dashboardLogic.getLocationStatusColor(isDarkMode).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      dashboardLogic.getLocationIcon(),
                      size: 20,
                      color: dashboardLogic.getLocationStatusColor(isDarkMode),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dashboardLogic.getLocationHeaderText(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: dashboardLogic.getLocationStatusColor(isDarkMode),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Today's Attendance Card - from attendance history
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedTime,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildClockStatCard('Clock In', _getClockInTime(), Icons.login),
                        const SizedBox(width: 18),
                        _buildClockStatCard('Clock Out', _getClockOutTime(), Icons.logout),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Upcoming Leave Section
              Text(
                'Upcoming Leave',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: isDarkMode ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF667EEA).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_available,
                        color: Color(0xFF667EEA),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No upcoming leaves',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You have no scheduled leaves',
                            style: TextStyle(
                              fontSize: 14,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quick Actions Section
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      'Clock In',
                      Icons.login,
                      Colors.green,
                      isDarkMode,
                      _onClockInTap,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      'Clock Out',
                      Icons.logout,
                      Colors.red,
                      isDarkMode,
                      _onClockOutTap,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Recent Activity Section
              RecentActivity(
                textColor: textColor,
                cardColor: cardColor,
                isDarkMode: isDarkMode,
                scaleAnimation: scaleAnimation,
                scaleAnimationController: scaleAnimationController,
                employeeId: widget.employeeId,
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: cardColor,
        selectedItemColor: const Color(0xFF667EEA),
        unselectedItemColor: isDarkMode ? Colors.grey[500] : Colors.grey[400],
        currentIndex: dashboardLogic.currentIndex,
        elevation: 10,
        onTap: _onBottomNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available_outlined),
            activeIcon: Icon(Icons.event_available),
            label: 'Leave',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildClockStatCard(String title, String time, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16, // Slightly smaller for label
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              time,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24, // Bigger for time
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
      BuildContext context,
      String title,
      IconData icon,
      Color color,
      bool isDarkMode,
      VoidCallback onTap,
      ) {
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2D3748);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: isDarkMode ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}