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
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _clockInButtonController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _clockOutButtonController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
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
    final Color boxColor = isDarkMode ? Colors.grey[900]!.withOpacity(0.9) : const Color(0xFFF8F8FF);

    return Scaffold(
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
      body: Container(
        color: isDarkMode ? Colors.black : Colors.white,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          children: [
            Text(
              'Hello',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
                color: textColor.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.firstName} ${widget.lastName}',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 24),

            _buildDetailedInfoBox(
              color: boxColor,
              textColor: textColor,
              icon: Icons.event,
              lines: ["Today's Attendance", _getStatusText(), _getTimeText()],
              height: 150,
            ),

            _buildTopAlignedInfoBox(
              title: 'Upcoming Leave',
              subtitle: 'No Upcoming Leaves',
              icon: Icons.beach_access,
              color: boxColor,
              textColor: textColor,
              height: 120,
            ),

            Row(
              children: [
                Expanded(
                  child: _buildAnimatedCenteredButtonBox(
                    title: 'Clock In',
                    icon: Icons.login,
                    backgroundColor: clockInOutController.status == ClockStatus.clockedIn
                        ? Colors.grey.shade700
                        : Colors.blueAccent,
                    height: 130,
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
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAnimatedCenteredButtonBox(
                    title: 'Clock Out',
                    icon: Icons.logout,
                    backgroundColor: clockInOutController.status != ClockStatus.clockedIn
                        ? Colors.grey.shade700
                        : Colors.blueAccent,
                    height: 130,
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
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Text(
              'More Options',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),

            _buildAnimatedOptionBox(
              title: 'Attendance History',
              icon: Icons.history,
              color: boxColor,
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
            ),

            _buildAnimatedOptionBox(
              title: 'Logout',
              icon: Icons.exit_to_app,
              color: boxColor,
              textColor: textColor,
              onTap: () {
                HapticFeedback.heavyImpact();
                LogoutLogic.showLogoutDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedInfoBox({
    required IconData icon,
    required List<String> lines,
    required Color color,
    required Color textColor,
    required double height,
  }) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: textColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(lines.length, (index) {
              double fontSize;
              FontWeight fontWeight;
              double spacing;

              switch (index) {
                case 0:
                  fontSize = 20;
                  fontWeight = FontWeight.bold;
                  spacing = 8;
                  break;
                case 1:
                  fontSize = 16;
                  fontWeight = FontWeight.w500;
                  spacing = 6;
                  break;
                default:
                  fontSize = 32;
                  fontWeight = FontWeight.bold;
                  spacing = 0;
                  break;
              }

              return Padding(
                padding: EdgeInsets.only(bottom: spacing),
                child: Text(
                  lines[index],
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                    color: textColor,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAlignedInfoBox({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color textColor,
    required double height,
  }) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: textColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              Text(subtitle,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCenteredButtonBox({
    required String title,
    required IconData icon,
    required Color backgroundColor,
    required double height,
    required bool isEnabled,
    required AnimationController animationController,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 - (animationController.value * 0.05),
          child: GestureDetector(
            onTap: isEnabled ? onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: height,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: isEnabled ? 10 : 5,
                    offset: Offset(0, isEnabled ? 5 : 2),
                  )
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 36, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedOptionBox({
    required String title,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
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
              height: 80,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, size: 28, color: textColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: textColor),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}