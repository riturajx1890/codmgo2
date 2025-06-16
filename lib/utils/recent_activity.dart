import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codmgo2/utils/logout_logic.dart';
import 'package:codmgo2/screens/attendence_history.dart';
import 'package:animations/animations.dart';
import 'package:codmgo2/services/clock_in_out_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

class RecentActivity extends StatefulWidget {
  final Color textColor;
  final Color cardColor;
  final bool isDarkMode;
  final Animation<double> scaleAnimation;
  final AnimationController scaleAnimationController;
  final String employeeId;

  const RecentActivity({
    super.key,
    required this.textColor,
    required this.cardColor,
    required this.isDarkMode,
    required this.scaleAnimation,
    required this.scaleAnimationController,
    required this.employeeId,
  });

  @override
  State<RecentActivity> createState() => _RecentActivityState();
}

class _RecentActivityState extends State<RecentActivity> {
  static final Logger _logger = Logger();
  List<Map<String, dynamic>> recentActivities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentActivities();
  }

  Future<void> _loadRecentActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final instanceUrl = prefs.getString('instance_url');

      if (accessToken != null && instanceUrl != null && widget.employeeId.isNotEmpty) {
        // Get recent attendance records using the existing method
        final attendanceRecords = await ClockInOutService.getAttendanceByEmployee(
          accessToken,
          instanceUrl,
          widget.employeeId,
        );

        if (attendanceRecords != null) {
          List<Map<String, dynamic>> activities = [];

          for (var record in attendanceRecords) {
            // Add clock in activity
            if (record['In_Time__c'] != null) {
              final inTime = DateTime.parse(record['In_Time__c']).toLocal();
              activities.add({
                'type': 'in',
                'time': inTime,
                'displayText': 'Clocked in at ${DateFormat('h:mm a').format(inTime)} on ${DateFormat('MMM dd, yyyy').format(inTime)}',
              });
            }

            // Add clock out activity
            if (record['Out_Time__c'] != null) {
              final outTime = DateTime.parse(record['Out_Time__c']).toLocal();
              activities.add({
                'type': 'out',
                'time': outTime,
                'displayText': 'Clocked out at ${DateFormat('h:mm a').format(outTime)} on ${DateFormat('MMM dd, yyyy').format(outTime)}',
              });
            }
          }

          // Sort by time (most recent first) and take last 10
          activities.sort((a, b) => b['time'].compareTo(a['time']));

          setState(() {
            recentActivities = activities.take(7).toList();
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
        _logger.w('Missing credentials or employee ID for loading recent activities');
      }
    } catch (e, stackTrace) {
      _logger.e('Error loading recent activities: $e', error: e, stackTrace: stackTrace);
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatActivityText(Map<String, dynamic> activity) {
    final time = activity['time'] as DateTime;
    final timeStr = DateFormat('h:mm a').format(time);
    final dateStr = DateFormat('MMM dd, yyyy').format(time);
    final isClockIn = activity['type'] == 'in';

    return '${isClockIn ? 'Clocked in' : 'Clocked out'} at $timeStr on $dateStr';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: widget.textColor,
                  ),
                ),
              ],
            ),
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _buildRecentActivitiesCard(),
      ],
    );
  }

  Widget _buildRecentActivitiesCard() {
    return AnimatedBuilder(
      animation: widget.scaleAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                  ),
                )
              else if (recentActivities.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 48,
                          color: widget.textColor.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No recent activities found',
                          style: TextStyle(
                            color: widget.textColor.withOpacity(0.6),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    for (int i = 0; i < recentActivities.length; i++) ...[
                      _buildActivityItem(recentActivities[i]),
                      if (i < recentActivities.length - 1) ...[
                        const SizedBox(height: 12),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                widget.textColor.withOpacity(0.05),
                                widget.textColor.withOpacity(0.15),
                                widget.textColor.withOpacity(0.05),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final isClockIn = activity['type'] == 'in';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _formatActivityText(activity),
              style: TextStyle(
                color: widget.textColor.withOpacity(0.8),
                fontSize: 18,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isClockIn ? Colors.green : Colors.orange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isClockIn ? Icons.login : Icons.logout,
              size: 28,
              color: isClockIn ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}