import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codmgo2/services/leave_api_service.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

class UpcomingLeaves extends StatefulWidget {
  final Color textColor;
  final Color cardColor;
  final bool isDarkMode;
  final Animation<double> scaleAnimation;
  final AnimationController scaleAnimationController;
  final String employeeId;

  const UpcomingLeaves({
    super.key,
    required this.textColor,
    required this.cardColor,
    required this.isDarkMode,
    required this.scaleAnimation,
    required this.scaleAnimationController,
    required this.employeeId,
  });

  @override
  State<UpcomingLeaves> createState() => _UpcomingLeavesState();
}

class _UpcomingLeavesState extends State<UpcomingLeaves> {
  static final Logger _logger = Logger();
  List<Map<String, dynamic>> upcomingLeaves = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUpcomingLeaves();
  }

  Future<void> _loadUpcomingLeaves() async {
    try {
      setState(() {
        isLoading = true;
      });

      final leaves = await LeaveApiService.getUpcomingLeaves();

      if (leaves != null) {
        setState(() {
          upcomingLeaves = leaves;
          isLoading = false;
        });
        _logger.i('Successfully loaded ${leaves.length} upcoming leaves');
      } else {
        setState(() {
          upcomingLeaves = [];
          isLoading = false;
        });
        _logger.w('Failed to load upcoming leaves');
      }
    } catch (e, stackTrace) {
      _logger.e('Error loading upcoming leaves: $e', error: e, stackTrace: stackTrace);
      setState(() {
        upcomingLeaves = [];
        isLoading = false;
      });
    }
  }

  String _formatLeaveText(Map<String, dynamic> leave) {
    try {
      final startDate = DateTime.parse(leave['Start_Date__c']);
      final endDate = DateTime.parse(leave['End_Date__c']);
      final startDateStr = DateFormat('MMM dd, yyyy').format(startDate);
      final endDateStr = DateFormat('MMM dd, yyyy').format(endDate);

      if (startDate.isAtSameMomentAs(endDate)) {
        return 'on $startDateStr';
      } else {
        return 'from $startDateStr to $endDateStr';
      }
    } catch (e) {
      return leave['Leave_Type__c'] ?? 'Leave';
    }
  }

  int _calculateLeaveDays(Map<String, dynamic> leave) {
    try {
      final startDate = DateTime.parse(leave['Start_Date__c']);
      final endDate = DateTime.parse(leave['End_Date__c']);
      return endDate.difference(startDate).inDays + 1;
    } catch (e) {
      return 1;
    }
  }

  String _getDaysUntilLeave(Map<String, dynamic> leave) {
    try {
      final startDate = DateTime.parse(leave['Start_Date__c']);
      final now = DateTime.now();
      final difference = startDate.difference(DateTime(now.year, now.month, now.day)).inDays;

      if (difference == 0) {
        return 'Today';
      } else if (difference == 1) {
        return 'Tomorrow';
      } else {
        return 'In $difference days';
      }
    } catch (e) {
      return '';
    }
  }

  Color _getLeaveTypeColor(String? leaveType) {
    switch (leaveType?.toLowerCase()) {
      case 'casual':
        return Colors.blue;
      case 'half day':
        return Colors.orange;
      case 'one day':
        return Colors.purple;
      case 'medical leave':
        return Colors.red;
      default:
        return Colors.blueAccent;
    }
  }

  IconData _getLeaveTypeIcon(String? leaveType) {
    switch (leaveType?.toLowerCase()) {
      case 'casual':
        return Icons.beach_access;
      case 'half day':
        return Icons.access_time;
      case 'one day':
        return Icons.looks_one;
      case 'medical leave':
        return Icons.local_hospital;
      default:
        return Icons.event_available;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitleColor = widget.isDarkMode ? Colors.white70 : Colors.grey[600];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Leaves',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: widget.textColor,
          ),
        ),
        const SizedBox(height: 12),
        _buildUpcomingLeavesCard(subtitleColor),
      ],
    );
  }

  Widget _buildUpcomingLeavesCard(Color? subtitleColor) {
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
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
                    ),
                  ),
                )
              else if (upcomingLeaves.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: subtitleColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No upcoming leaves',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: widget.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You have no approved leaves scheduled',
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
                  children: _buildLeaveRowsWithDividers(subtitleColor),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildLeaveRowsWithDividers(Color? subtitleColor) {
    List<Widget> widgets = [];
    for (int i = 0; i < upcomingLeaves.length; i++) {
      widgets.add(_buildLeaveItem(upcomingLeaves[i], subtitleColor));
      if (i < upcomingLeaves.length - 1) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(_buildDivider());
        widgets.add(const SizedBox(height: 16));
      }
    }
    return widgets;
  }

  Widget _buildLeaveItem(Map<String, dynamic> leave, Color? subtitleColor) {
    final leaveType = leave['Leave_Type__c'] ?? 'Leave';
    final leaveColor = _getLeaveTypeColor(leaveType);
    final leaveIcon = _getLeaveTypeIcon(leaveType);
    final leaveDays = _calculateLeaveDays(leave);
    final daysUntil = _getDaysUntilLeave(leave);
    final description = leave['Description__c'];

    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: leaveColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            leaveIcon,
            color: leaveColor,
            size: 30,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      leaveType,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.textColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      daysUntil,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatLeaveText(leave),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: subtitleColor,
                ),
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor?.withOpacity(0.8),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
