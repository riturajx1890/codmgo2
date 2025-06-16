import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codmgo2/utils/clock_in_out_logic.dart';
import 'package:codmgo2/utils/dashboard_logic.dart';
import 'package:codmgo2/screens/clock_in_out.dart';
import 'dart:math' as math;

class DashboardUIComponents extends StatelessWidget {
  final bool isDarkMode;
  final String Function() getCurrentTime;
  final String Function() getCurrentDate;
  final VoidCallback onLocationIconTap;
  final IconData Function() getLocationIcon;
  final Color Function(bool) getLocationStatusColor;
  final String Function() getLocationText;
  final Animation<double> locationRotationAnimation;
  final ClockInOutController clockInOutController;
  final VoidCallback onClockInTap;
  final List<Map<String, dynamic>> Function() getRecentActivities;
  final Animation<double> clockButtonPulseAnimation;
  final DashboardLogic dashboardLogic;

  const DashboardUIComponents({
    super.key,
    required this.isDarkMode,
    required this.getCurrentTime,
    required this.getCurrentDate,
    required this.onLocationIconTap,
    required this.getLocationIcon,
    required this.getLocationStatusColor,
    required this.getLocationText,
    required this.locationRotationAnimation,
    required this.clockInOutController,
    required this.onClockInTap,
    required this.getRecentActivities,
    required this.clockButtonPulseAnimation,
    required this.dashboardLogic,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: WavePatternPainter(isDarkMode: isDarkMode),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 30),
              _buildTimeSection(),
              const SizedBox(height: 40),
              _buildClockInButton(),
              const SizedBox(height: 30),
              _buildLocationSection(),
              const SizedBox(height: 40),
              _buildRecentActivitySection(),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSection() {
    return Column(
      children: [
        Text(
          getCurrentTime(),
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.w300,
            color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
            height: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          getCurrentDate(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: isDarkMode ? const Color(0xFFD0D0D0) : const Color(0xFF666666),
          ),
        ),
      ],
    );
  }

  Widget _buildClockInButton() {
    final canClockIn = clockInOutController.status != ClockStatus.clockedIn;

    return AnimatedBuilder(
      animation: clockButtonPulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: canClockIn ? clockButtonPulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: onClockInTap,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: canClockIn
                      ? [const Color(0xFF4285F4), const Color(0xFF1E6DE8)]
                      : [Colors.grey.shade600, Colors.grey.shade700],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: canClockIn
                        ? const Color(0xFF4285F4).withOpacity(0.4)
                        : Colors.grey.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getClockButtonText(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 1.2,
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

  String _getClockButtonText() {
    switch (clockInOutController.status) {
      case ClockStatus.clockedIn:
        return 'CLOCKED IN';
      case ClockStatus.clockedOut:
        return 'CLOCK IN';
      default:
        return 'CLOCK IN';
    }
  }

  Widget _buildLocationSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: onLocationIconTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: locationRotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: dashboardLogic.isLocationChecking
                      ? locationRotationAnimation.value * 2 * 3.14159
                      : 0,
                  child: Icon(
                    getLocationIcon(),
                    size: 16,
                    color: getLocationStatusColor(isDarkMode),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              'Location : ${getLocationText()}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: isDarkMode ? const Color(0xFFD0D0D0) : const Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    final activities = getRecentActivities();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: activities.map((activity) => _buildActivityCard(activity)).toList(),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF2C2C2C).withOpacity(0.8)
                : const Color(0xFFF0F0F0),
            shape: BoxShape.circle,
          ),
          child: Icon(
            activity['icon'] as IconData,
            size: 28,
            color: activity['color'] as Color,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          activity['time'] as String,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          activity['label'] as String,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: isDarkMode ? const Color(0xFFD0D0D0) : const Color(0xFF666666),
          ),
        ),
      ],
    );
  }
}

// Custom painter for background waves (optional)
class WavePatternPainter extends CustomPainter {
  final bool isDarkMode;

  WavePatternPainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDarkMode
          ? const Color(0xFF3A5E95).withOpacity(0.05)
          : const Color(0xFF4285F4).withOpacity(0.03)
      ..style = PaintingStyle.fill;

    final path = Path();

    path.moveTo(0, size.height * 0.8);
    for (double i = 0; i <= size.width; i++) {
      path.lineTo(i, size.height * 0.8 + 20 * math.sin((i / size.width) * 2 * math.pi));
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);

    final path2 = Path();
    path2.moveTo(0, size.height * 0.6);
    for (double i = 0; i <= size.width; i++) {
      path2.lineTo(
          i,
          size.height * 0.6 +
              15 * math.sin((i / size.width) * 3 * math.pi + math.pi / 4));
    }
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}