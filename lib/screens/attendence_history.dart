import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codmgo2/screens/clock_in_out.dart';
import 'package:codmgo2/services/clock_in_out_service.dart'; // Import your ClockInOutService
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
            attendanceHistory = records.take(7).toList(); // Get last 7 records
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
    if (inTime == null || outTime == null) return "0 hour: 0 minutes";

    try {
      final inDateTime = DateTime.parse(inTime);
      final outDateTime = DateTime.parse(outTime);
      final difference = outDateTime.difference(inDateTime);

      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;

      return '$hours hour${hours != 1 ? ' ' : ''}: $minutes minute${minutes != 1 ? 's' : ''}';
    } catch (e) {
      return "--:-- hrs";
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final Color textColor = isDarkMode ? Colors.white : Colors.black;
    final Color boxColor = isDarkMode ? Colors.grey[900]!.withOpacity(0.9) : const Color(0xFFF8F8FF);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: textColor,
              size: 28,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Attendance',
            style: TextStyle(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
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
            // Today's Attendance Status
            _buildDetailedInfoBox(
              color: boxColor,
              textColor: textColor,
              icon: Icons.event,
              lines: ["Today's Attendance", _getStatusText(), _getTimeText()],
              height: 150,
            ),

            const SizedBox(height: 24),

            // Attendance History Title
            Text(
              'Attendance History',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),

            // Loading or History Cards
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (attendanceHistory.isEmpty)
              Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: boxColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5)),
                  ],
                ),
                child: Center(
                  child: Text(
                    'No attendance history found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ),
              )
            else
              ...attendanceHistory.map((record) => _buildAttendanceCard(
                record: record,
                color: boxColor,
                textColor: textColor,
              )),
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

  Widget _buildAttendanceCard({
    required Map<String, dynamic> record,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date
          Text(
            'Date: ${_formatDate(record['CreatedDate'])}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),

          // Clock In/Out Row
          Row(
            children: [
              // Clock In
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clocked In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(record['In_Time__c']),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
                      'Clocked Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(record['Out_Time__c']),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Total Working Hours
          Text(
            'Total Working Hours: ${_calculateTotalHours(record['In_Time__c'], record['Out_Time__c'])}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
               // Or use your `textColor` variable if dynamic
            ),
          ),

        ],
      ),
    );
  }
}