import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codmgo2/screens/clock_in_out.dart';
import 'package:codmgo2/utils/clock_in_out_logic.dart';
import '../utils/logout_logic.dart';
import 'attendence_history.dart';
import 'package:animations/animations.dart';

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
  late AnimationController _scaleAnimationController;
  late AnimationController _clockInButtonController;
  late AnimationController _clockOutButtonController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    clockInOutController = ClockInOutController();
    clockInOutController.addListener(_onClockStatusChanged);

    // Initialize animation controllers
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

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(
      parent: _scaleAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    clockInOutController.removeListener(_onClockStatusChanged);
    clockInOutController.dispose();
    _scaleAnimationController.dispose();
    _clockInButtonController.dispose();
    _clockOutButtonController.dispose();
    super.dispose();
  }

  void _onClockStatusChanged() {
    if (mounted) setState(() {});
  }

  String _getStatusText() {
    switch (clockInOutController.status) {
      case ClockStatus.clockedIn:
        return "Clocked In";
      case ClockStatus.clockedOut:
        return "Clocked Out";
      default:
        return "Unmarked";
    }
  }

  String _getTimeText() {
    DateTime? timeToShow;
    switch (clockInOutController.status) {
      case ClockStatus.clockedIn:
        timeToShow = clockInOutController.inTime;
        break;
      case ClockStatus.clockedOut:
        timeToShow = clockInOutController.outTime;
        break;
      default:
        return "--:-- --";
    }

    if (timeToShow != null) {
      final hour = timeToShow.hour > 12
          ? timeToShow.hour - 12
          : (timeToShow.hour == 0 ? 12 : timeToShow.hour);
      final period = timeToShow.hour >= 12 ? "PM" : "AM";
      return "${hour.toString().padLeft(2, '0')}:${timeToShow.minute.toString().padLeft(2, '0')} $period";
    }

    return "--:-- --";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color cardColor = isDarkMode
        ? Colors.grey[850]!.withOpacity(0.95)
        : const Color(0xFFF8F9FA);
    final Color backgroundColor = isDarkMode ? Colors.black : const Color(0xFFFAFAFA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildHeader(textColor),
          const SizedBox(height: 32),
          _buildAttendanceCard(cardColor, textColor, isDarkMode),
          const SizedBox(height: 20),
          _buildUpcomingLeaveCard(cardColor, textColor),
          const SizedBox(height: 24),
          _buildClockButtons(isDarkMode),
          const SizedBox(height: 32),
          _buildMoreOptionsSection(textColor, cardColor, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello,',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: textColor.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.firstName} ${widget.lastName}',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: textColor,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCard(Color cardColor, Color textColor, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.access_time,
                  size: 24,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Today's Attendance",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Time',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getTimeText(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingLeaveCard(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.beach_access,
              size: 24,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upcoming Leave',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No Upcoming Leaves',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockButtons(bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: _buildClockButton(
            title: 'Clock In',
            icon: Icons.login,
            isEnabled: clockInOutController.status != ClockStatus.clockedIn,
            animationController: _clockInButtonController,
            onTap: clockInOutController.status == ClockStatus.clockedIn
                ? () {}
                : () async {
              _clockInButtonController.forward().then((_) {
                _clockInButtonController.reverse();
              });
              await clockInOutController.clockIn(context);
            },
            isDarkMode: isDarkMode,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildClockButton(
            title: 'Clock Out',
            icon: Icons.logout,
            isEnabled: clockInOutController.status == ClockStatus.clockedIn,
            animationController: _clockOutButtonController,
            onTap: clockInOutController.status != ClockStatus.clockedIn
                ? () {}
                : () async {
              _clockOutButtonController.forward().then((_) {
                _clockOutButtonController.reverse();
              });
              await clockInOutController.clockOut(context);
            },
            isDarkMode: isDarkMode,
          ),
        ),
      ],
    );
  }

  Widget _buildClockButton({
    required String title,
    required IconData icon,
    required bool isEnabled,
    required AnimationController animationController,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 - (animationController.value * 0.05),
          child: GestureDetector(
            onTap: isEnabled ? onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 120,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: isEnabled
                    ? const LinearGradient(
                  colors: [Colors.blueAccent, Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : LinearGradient(
                  colors: [
                    Colors.grey.shade700,
                    Colors.grey.shade700,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isEnabled
                    ? [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
                    : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 32,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoreOptionsSection(Color textColor, Color cardColor, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More Options',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildOptionCard(
          title: 'Attendance History',
          icon: Icons.history,
          color: cardColor,
          textColor: textColor,
          onTap: () {
            HapticFeedback.heavyImpact();
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => AttendanceHistoryPage(
                  employeeId: widget.employeeId,
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return SharedAxisTransition(
                    animation: animation,
                    secondaryAnimation: secondaryAnimation,
                    transitionType: SharedAxisTransitionType.horizontal,
                    child: child,
                  );
                },
              ),
            );
          },
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 12),
        _buildOptionCard(
          title: 'Logout',
          icon: Icons.exit_to_app,
          color: cardColor,
          textColor: textColor,
          onTap: () {
            HapticFeedback.heavyImpact();
            LogoutLogic.showLogoutDialog(context);
          },
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTapDown: (_) => _scaleAnimationController.forward(),
          onTapUp: (_) => _scaleAnimationController.reverse(),
          onTapCancel: () => _scaleAnimationController.reverse(),
          onTap: onTap,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: textColor.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}