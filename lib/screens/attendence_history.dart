import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codmgo2/screens/clock_in_out.dart';
import 'package:codmgo2/services/clock_in_out_service.dart';
import 'package:codmgo2/utils/bottom_navigation_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/clock_in_out_logic.dart';

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
  int _currentIndex = 2; // Set to 2 for Attendance History

  @override
  void initState() {
    super.initState();
    clockInOutController = ClockInOutController();
    clockInOutController.addListener(_onClockStatusChanged);
    _loadAttendanceHistory();
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

  void _onBottomNavTap(int index) {
    if (index == _currentIndex) return; // Don't navigate to the same page

    switch (index) {
      case 0:
      // Navigate back to Dashboard
        Navigator.pop(context);
        break;
      case 1:
      // Navigate to Leave page
        break;
      case 2:
      // Already on Attendance History
        break;
      case 3:
      // Navigate to Profile page
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
    if (inTime == null || outTime == null) return "0 hrs 0 mins";

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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color cardColor = isDarkMode
        ? Colors.grey[850]!.withOpacity(0.95)
        : const Color(0xFFF8F9FA);
    final Color backgroundColor = isDarkMode ? Colors.black : const Color(0xFFFAFAFA);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        ),
        toolbarHeight: 80,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: textColor,
                size: 20,
              ),
            ),
          ),
        ),
        title: Text(
          'Attendance History',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // Today's Attendance Card - matching dashboard style
          _buildTodaysAttendanceCard(cardColor, textColor, isDarkMode),

          const SizedBox(height: 32),

          // Section Title
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),

          const SizedBox(height: 20),

          // Loading or History Cards
          if (isLoading)
            _buildLoadingCard(cardColor, isDarkMode)
          else if (attendanceHistory.isEmpty)
            _buildEmptyStateCard(cardColor, textColor, isDarkMode)
          else
            ...attendanceHistory.map((record) => _buildAttendanceCard(
              record: record,
              cardColor: cardColor,
              textColor: textColor,
              isDarkMode: isDarkMode,
            )),
        ],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
        isDarkMode: isDarkMode,
      ),
    );
  }

  Widget _buildTodaysAttendanceCard(Color cardColor, Color textColor, bool isDarkMode) {
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

  Widget _buildLoadingCard(Color cardColor, bool isDarkMode) {
    return Container(
      height: 140, // Same height as today's attendance card
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 16),
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
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.blueAccent,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(Color cardColor, Color textColor, bool isDarkMode) {
    return Container(
      height: 140, // Same height as today's attendance card
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.history,
              size: 24,
              color: textColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No Records Found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your attendance records will appear here',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor.withOpacity(0.6),
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
    required bool isDarkMode,
  }) {
    return Container(
      height: 140, // Same height as today's attendance card
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Row(
        children: [
          // Date Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today,
              size: 24,
              color: Colors.green,
            ),
          ),

          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Date
                Text(
                  _formatDate(record['CreatedDate']),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor.withOpacity(0.8),
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
                              color: textColor.withOpacity(0.6),
                            ),
                          ),
                          Text(
                            _formatTime(record['In_Time__c']),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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
                              color: textColor.withOpacity(0.6),
                            ),
                          ),
                          Text(
                            _formatTime(record['Out_Time__c']),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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
                            color: textColor.withOpacity(0.6),
                          ),
                        ),
                        Text(
                          _calculateTotalHours(record['In_Time__c'], record['Out_Time__c']),
                          style: const TextStyle(
                            fontSize: 14,
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
          ),
        ],
      ),
    );
  }
}