import 'package:codmgo2/screens/slide_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codmgo2/utils/dashboard_logic.dart';
import 'package:intl/intl.dart';
import 'package:codmgo2/utils/recent_activity.dart';
import 'package:codmgo2/utils/clock_in_out_logic.dart';

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
  late final DashboardLogic dashboardLogic;
  late final ClockInOutLogic clockInOutLogic;
  late AnimationController scaleAnimationController;
  late Animation<double> scaleAnimation;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Drawer functionality variables
  late AnimationController _drawerAnimationController;
  late Animation<Offset> _drawerSlideAnimation;
  bool _isDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeDashboard();
    _initializeDrawer();
  }

  void _initializeControllers() {
    dashboardLogic = DashboardLogic();
    dashboardLogic.addListener(_onDashboardStateChanged);

    clockInOutLogic = ClockInOutLogic();
    clockInOutLogic.addListener(_onClockInOutStateChanged);

    scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    scaleAnimation = CurvedAnimation(
      parent: scaleAnimationController,
      curve: Curves.easeInOut,
    );
    scaleAnimationController.forward();
  }

  void _initializeDrawer() {
    _drawerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _drawerSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _drawerAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeDashboard() async {
    await dashboardLogic.initializeDashboard(
      firstName: widget.firstName,
      lastName: widget.lastName,
      employeeId: widget.employeeId,
    );
  }

  void _onDashboardStateChanged() {
    if (mounted) setState(() {});
  }

  void _onClockInOutStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    await dashboardLogic.onRefresh(context);
  }

  void _onProfileIconTap() {
    HapticFeedback.lightImpact();
    setState(() {
      _isDrawerOpen = !_isDrawerOpen;
    });

    if (_isDrawerOpen) {
      _drawerAnimationController.forward();
    } else {
      _drawerAnimationController.reverse();
    }
  }

  void _closeDrawer() {
    if (_isDrawerOpen) {
      setState(() {
        _isDrawerOpen = false;
      });
      _drawerAnimationController.reverse();
    }
  }

  void _toggleTheme() {
    // Implement your theme toggle logic here
    print('Toggle theme');
    // You can add your theme provider logic here
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    if (_isDrawerOpen) {
      _closeDrawer();
      return false; // Don't exit the app, just close the drawer
    }
    return true; // Allow exit without confirmation
  }

  Future<void> _onClockInTap() async {
    HapticFeedback.mediumImpact();

    if (!dashboardLogic.isWithinRadius) {
      _showRangeErrorDialog('Clock In', 'You are outside the allowed office radius.');
      return;
    }

    // Check if user has already clocked in today
    if (clockInOutLogic.status == ClockStatus.clockedIn ||
        clockInOutLogic.status == ClockStatus.clockedOut ||
        !dashboardLogic.canClockIn()) {
      _showClockInRestrictedDialog();
      return;
    }

    await dashboardLogic.onClockIn(context);
  }

  Future<void> _onClockOutTap() async {
    HapticFeedback.mediumImpact();
    if (!dashboardLogic.isWithinRadius) {
      _showRangeErrorDialog('Clock Out', 'You are outside the allowed office radius.');
      return;
    }

    // Check if user is clocked in first
    if (clockInOutLogic.status != ClockStatus.clockedIn) {
      _showClockInRequiredDialog();
      return;
    }

    if (!dashboardLogic.canClockOut()) {
      _showClockOutRestrictedDialog();
      return;
    }
    await dashboardLogic.onClockOut(context);
  }

  void _showRangeErrorDialog(String action, String message) {
    _showCustomDialog(
      icon: Icons.location_off,
      iconColor: Colors.red,
      title: '$action Failed!',
      message: message,
      buttonText: 'Done',
    );
  }

  void _showClockInRequiredDialog() {
    _showCustomDialog(
      icon: Icons.access_time,
      iconColor: Colors.orange,
      title: 'Clock Out Failed!',
      message: 'Please clock in before attempting to clock out.',
      buttonText: 'Got It',
    );
  }

  void _showClockInRestrictedDialog() {
    _showCustomDialog(
      icon: Icons.error_outline,
      iconColor: Colors.orange,
      title: 'Clock In Failed!',
      message: 'You have already clocked in today.\nYou can only clock in once per day.',
      buttonText: 'Done',
    );
  }

  void _showClockOutRestrictedDialog() {
    _showCustomDialog(
      icon: Icons.timer,
      iconColor: Colors.orange,
      title: 'Clock Out Failed!',
      message: 'You can only clock out after 45 minutes\nof clocking in. Please try again later.',
      buttonText: 'Done',
    );
  }

  void _showCustomDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String buttonText,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDarkMode ? Colors.white : const Color(0xFF2D3748);
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.grey[600];

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(icon, color: iconColor, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: subtitleColor),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667EEA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      shadowColor: Colors.transparent,
                      side: const BorderSide(color: Color(0xFF667EEA), width: 1),
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
    dashboardLogic.removeListener(_onDashboardStateChanged);
    dashboardLogic.dispose();
    clockInOutLogic.removeListener(_onClockInOutStateChanged);
    clockInOutLogic.dispose();
    scaleAnimationController.dispose();
    _drawerAnimationController.dispose();
    _scrollController.dispose();
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

    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, MMM d yyyy');
    final timeFormat = DateFormat('h:mm a');
    final formattedDate = dateFormat.format(now);
    final formattedTime = timeFormat.format(now);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Stack(
        children: [
          Scaffold(
            key: _scaffoldKey,
            backgroundColor: backgroundColor,
            appBar: _buildAppBar(cardColor, subtitleColor, textColor, isDarkMode),
            body: Stack(
              children: [
                // Main content with gesture detector to close drawer
                GestureDetector(
                  onTap: _isDrawerOpen ? _closeDrawer : null,
                  child: AbsorbPointer(
                    absorbing: _isDrawerOpen,
                    child: RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ScrollConfiguration(
                        behavior: const ScrollBehavior().copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTodaysAttendanceCard(formattedTime, formattedDate, isDarkMode),
                              const SizedBox(height: 20),
                              _buildUpcomingLeaveSection(textColor, cardColor, isDarkMode, subtitleColor),
                              const SizedBox(height: 20),
                              _buildQuickActionsSection(textColor, isDarkMode),
                              const SizedBox(height: 20),
                              _buildRecentActivitySection(textColor, cardColor, isDarkMode),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Overlay when drawer is open
                if (_isDrawerOpen)
                  GestureDetector(
                    onTap: _closeDrawer,
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
              ],
            ),
          ),

          // Slide-out drawer - moved outside Scaffold to appear above app bar
          SlideTransition(
            position: _drawerSlideAnimation,
            child: SlideBar(
              firstName: widget.firstName,
              lastName: widget.lastName,
              phoneNumber: '+91 1234567890',
              isDarkMode: isDarkMode,
              onThemeToggle: _toggleTheme,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Color cardColor, Color? subtitleColor, Color textColor, bool isDarkMode) {
    return AppBar(
      backgroundColor: cardColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 63,
      title: Row(
        children: [
          GestureDetector(
            onTap: _onProfileIconTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: Color(0xFF667EEA), size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello,',
                  style: TextStyle(fontSize: 14, color: subtitleColor, fontWeight: FontWeight.normal),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dashboardLogic.displayFirstName.isNotEmpty ? dashboardLogic.displayFirstName : 'User'} ${dashboardLogic.displayLastName}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
              ],
            ),
          ),
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
    );
  }

  Widget _buildTodaysAttendanceCard(String formattedTime, String formattedDate, bool isDarkMode) {
    return Container(
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
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            formattedDate,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildUpcomingLeaveSection(Color textColor, Color cardColor, bool isDarkMode, Color? subtitleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Leave',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
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
                child: const Icon(Icons.event_available, color: Color(0xFF667EEA), size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No upcoming leaves',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have no scheduled leaves',
                      style: TextStyle(fontSize: 14, color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection(Color textColor, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
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
      ],
    );
  }

  Widget _buildRecentActivitySection(Color textColor, Color cardColor, bool isDarkMode) {
    return RecentActivity(
      textColor: textColor,
      cardColor: cardColor,
      isDarkMode: isDarkMode,
      scaleAnimation: scaleAnimation,
      scaleAnimationController: scaleAnimationController,
      employeeId: widget.employeeId,
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
                    fontSize: 16,
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
                fontSize: 24,
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
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}