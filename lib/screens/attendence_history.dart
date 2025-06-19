import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codmgo2/screens/clock_in_out.dart';
import 'package:codmgo2/screens/dashboard_page.dart';
import 'package:codmgo2/screens/leave_dashboard.dart';
import 'package:codmgo2/screens/profile_screen.dart';
import 'package:codmgo2/services/clock_in_out_service.dart';
import 'package:codmgo2/services/profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/clock_in_out_core_logic.dart';

class AttendanceHistoryPage extends StatefulWidget {
  final String employeeId;

  const AttendanceHistoryPage({
    super.key,
    required this.employeeId,
  });

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  late final ClockInOutController clockInOutController;
  List<Map<String, dynamic>> attendanceHistory = [];
  bool isLoading = true;
  String? accessToken;
  String? instanceUrl;
  bool isLoadingAuth = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    clockInOutController = ClockInOutController();
    clockInOutController.addListener(_onClockStatusChanged);
    _loadAuthData();
  }

  @override
  void dispose() {
    clockInOutController.removeListener(_onClockStatusChanged);
    clockInOutController.dispose();
    super.dispose();
  }

  void _onClockStatusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAuthData() async {
    setState(() {
      isLoadingAuth = true;
      errorMessage = null;
    });

    try {
      final authData = await ProfileService.getAuthData();
      if (authData != null) {
        setState(() {
          accessToken = authData['access_token'];
          instanceUrl = authData['instance_url'];
          isLoadingAuth = false;
        });
        _loadAttendanceHistory();
      } else {
        setState(() {
          isLoadingAuth = false;
          errorMessage = 'Failed to retrieve authentication data';
        });
      }
    } catch (e) {
      setState(() {
        isLoadingAuth = false;
        errorMessage = 'Error loading authentication data: $e';
      });
    }
  }

  Future<void> _loadAttendanceHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final instanceUrl = prefs.getString('instance_url');

      if (accessToken != null && instanceUrl != null) {
        final records = await ClockInOutService.getAttendanceByEmployee(
          accessToken,
          instanceUrl,
          widget.employeeId,
        );

        if (records != null) {
          setState(() {
            attendanceHistory = records.take(7).toList();
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onBottomNavTap(BuildContext context, int index) {
    if (index == 2) return; // Already on Attendance page

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(
              employeeId: widget.employeeId,
              firstName: '',
              lastName: '',
            ),
          ),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LeaveDashboardPage(employeeId: widget.employeeId),
          ),
        );
        break;
      case 3:
        if (accessToken == null || instanceUrl == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication data not available. Please try again.')),
          );
          _loadAuthData();
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilePage(),
          ),
        );
        break;
    }
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

  String _formatTime(String? dateTimeString) {
    if (dateTimeString == null) return "--:-- --";

    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      final hour = dateTime.hour > 12
          ? dateTime.hour - 12
          : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final period = dateTime.hour >= 12 ? "PM" : "AM";
      return "${hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $period";
    } catch (e) {
      return "--:-- --";
    }
  }

  String _formatDate(String? dateTimeString) {
    if (dateTimeString == null) return "Unknown Date";

    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return "${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}";
    } catch (e) {
      return "Unknown Date";
    }
  }

  String _calculateTotalHours(String? inTime, String? outTime) {
    if (inTime == null || outTime == null) return "0h 0m";

    try {
      final inDateTime = DateTime.parse(inTime);
      final outDateTime = DateTime.parse(outTime);
      final difference = outDateTime.difference(inDateTime);

      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;

      return '${hours}h ${minutes}m';
    } catch (e) {
      return "--:-- hrs";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2D3748);
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.grey[600];

    if (isLoadingAuth) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: TextStyle(color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAuthData,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 63,
        backgroundColor: cardColor,
        title: Text(
          'Attendance History',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: textColor),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's Attendance Card - matching leave dashboard style
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
                  const Text(
                    'Today\'s Attendance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your daily attendance',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildTodayStatCard('Status', _getStatusText(), Icons.access_time),
                      const SizedBox(width: 16),
                      _buildTodayStatCard('Time', _getTimeText(), Icons.schedule),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Recent Activity Section
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),

            const SizedBox(height: 16),

            // Loading or History Cards
            if (isLoading)
              _buildLoadingCard(cardColor, isDarkMode)
            else if (attendanceHistory.isEmpty)
              _buildEmptyStateCard(cardColor, textColor, subtitleColor, isDarkMode)
            else
              ...attendanceHistory.map((record) => _buildAttendanceCard(
                record: record,
                cardColor: cardColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
                isDarkMode: isDarkMode,
              )),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: cardColor,
        selectedItemColor: const Color(0xFF667EEA),
        unselectedItemColor: isDarkMode ? Colors.grey[500] : Colors.grey[400],
        currentIndex: 2, // Attendance tab selected
        elevation: 10,
        onTap: (index) => _onBottomNavTap(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            activeIcon: Icon(Icons.home_filled),
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

  Widget _buildTodayStatCard(String title, String time, IconData icon) {
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              time,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20, // Bigger for time
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(Color cardColor, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF667EEA),
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(Color cardColor, Color textColor, Color? subtitleColor, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF667EEA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.history,
              color: Color(0xFF667EEA),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Records Found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your attendance records will appear here',
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
    );
  }

  Widget _buildAttendanceCard({
    required Map<String, dynamic> record,
    required Color cardColor,
    required Color textColor,
    required Color? subtitleColor,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        ],
      ),
      child: Row(
        children: [
          // Date Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF667EEA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today,
              color: Color(0xFF667EEA),
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                Text(
                  _formatDate(record['CreatedDate']),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),

                const SizedBox(height: 8),

                // Times Row
                Row(
                  children: [
                    // Clock In
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'In',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                          Text(
                            _formatTime(record['In_Time__c']),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Clock Out
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Out',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                          Text(
                            _formatTime(record['Out_Time__c']),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Total Hours
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: subtitleColor,
                          ),
                        ),
                        Text(
                          _calculateTotalHours(record['In_Time__c'], record['Out_Time__c']),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF667EEA),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}