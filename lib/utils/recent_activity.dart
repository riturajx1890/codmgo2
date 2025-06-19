import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        final attendanceRecords = await ClockInOutService.getAttendanceByEmployee(
          accessToken,
          instanceUrl,
          widget.employeeId,
        );

        if (attendanceRecords != null) {
          List<Map<String, dynamic>> activities = [];

          for (var record in attendanceRecords) {
            if (record['In_Time__c'] != null) {
              final inTime = DateTime.parse(record['In_Time__c']).toLocal();
              activities.add({
                'type': 'in',
                'time': inTime,
                'displayText': 'Clocked in at ${DateFormat('h:mm a').format(inTime)} on ${DateFormat('MMM dd, yyyy').format(inTime)}',
              });
            }

            if (record['Out_Time__c'] != null) {
              final outTime = DateTime.parse(record['Out_Time__c']).toLocal();
              activities.add({
                'type': 'out',
                'time': outTime,
                'displayText': 'Clocked out at ${DateFormat('h:mm a').format(outTime)} on ${DateFormat('MMM dd, yyyy').format(outTime)}',
              });
            }
          }

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
    final subtitleColor = widget.isDarkMode ? Colors.white70 : Colors.grey[600];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: widget.textColor,
          ),
        ),
        const SizedBox(height: 12),
        _buildRecentActivitiesCard(subtitleColor),
      ],
    );
  }

  Widget _buildRecentActivitiesCard(Color? subtitleColor) {
    return AnimatedBuilder(
      animation: widget.scaleAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                      valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF667EEA)),
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
                          size: 64,
                          color: subtitleColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No recent activities found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: widget.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No clock-in or clock-out records available',
                          style: TextStyle(
                            fontSize: 14,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: _buildActivityRowsWithDividers(subtitleColor),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildActivityRowsWithDividers(Color? subtitleColor) {
    List<Widget> widgets = [];
    for (int i = 0; i < recentActivities.length; i++) {
      widgets.add(_buildActivityItem(recentActivities[i], subtitleColor));
      if (i < recentActivities.length - 1) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(_buildDivider());
        widgets.add(const SizedBox(height: 16));
      }
    }
    return widgets;
  }

  Widget _buildActivityItem(Map<String, dynamic> activity, Color? subtitleColor) {
    final isClockIn = activity['type'] == 'in';
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF667EEA).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isClockIn ? Icons.login : Icons.logout,
            color: isClockIn ? Colors.green : Colors.red,
            size: 30,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isClockIn ? 'Clock In' : 'Clock Out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatActivityText(activity),
                style: TextStyle(
                  fontSize: 14,
                  color: subtitleColor,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: widget.isDarkMode ? Colors.grey[700] : Colors.grey[200],
      thickness: 1,
      height: 1,
    );
  }
}