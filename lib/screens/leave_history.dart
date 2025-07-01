import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codmgo2/screens/dashboard_page.dart';
import 'package:codmgo2/screens/leave_dashboard.dart';
import 'package:codmgo2/screens/profile_screen.dart';
import 'package:codmgo2/services/leave_api_service.dart';

class LeaveHistoryPage extends StatefulWidget {
  final String employeeId;

  const LeaveHistoryPage({
    super.key,
    required this.employeeId,
  });

  @override
  State<LeaveHistoryPage> createState() => _LeaveHistoryPageState();
}

class _LeaveHistoryPageState extends State<LeaveHistoryPage> {
  List<Map<String, dynamic>> allLeaves = [];
  List<Map<String, dynamic>> filteredLeaves = [];
  bool isLoading = true;
  String selectedFilter = 'All';
  String? errorMessage;

  get titleColor => null;

  @override
  void initState() {
    super.initState();
    _loadLeaveHistory();
  }

  Future<void> _loadLeaveHistory() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final leaves = await LeaveApiService.getEmployeeLeaves();

      if (leaves != null) {
        setState(() {
          allLeaves = leaves;
          filteredLeaves = leaves;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load leave history';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading leave history: $e';
      });
    }
  }

  void _filterLeaves(String filter) {
    // Light haptic feedback when selecting filter
    HapticFeedback.lightImpact();

    setState(() {
      selectedFilter = filter;

      if (filter == 'All') {
        filteredLeaves = allLeaves;
      } else {
        filteredLeaves = allLeaves.where((leave) =>
        leave['Status__c']?.toString().toLowerCase() == filter.toLowerCase()
        ).toList();
      }
    });
  }

  void _showHelpSnackbar() {
    // Light haptic feedback for help button
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Help feature coming soon'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF667EEA),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showDescriptionPopup(String description) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDarkMode ? Colors.white : const Color(0xFF2D3748);

        return Dialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 350),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Leave Reason',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    // color: const Color(0xFF4F46E5).withOpacity(isDarkMode ? 0.1 : 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4F46E5).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    description.isNotEmpty ? description : 'No reason provided',
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
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



  String _formatDate(String? dateString) {
    if (dateString == null) return "Unknown Date";

    try {
      final dateTime = DateTime.parse(dateString);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return "${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}";
    } catch (e) {
      return "Unknown Date";
    }
  }

  String _calculateLeaveDuration(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return "0 days";

    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final difference = end.difference(start).inDays + 1; // +1 to include both start and end dates

      return difference == 1 ? "1 day" : "$difference days";
    } catch (e) {
      return "0 days";
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusBackgroundColor(String? status, bool isDarkMode) {
    final baseColor = _getStatusColor(status);
    return baseColor.withOpacity(isDarkMode ? 0.2 : 0.1);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2D3748);
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.grey[600];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 63,
        backgroundColor: cardColor,
        title: Text(
          'Leave History',
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
            icon: const Icon(Icons.help_outline, color: Colors.green),
            onPressed: _showHelpSnackbar,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLeaveHistory,
        color: const Color(0xFF667EEA),
        backgroundColor: cardColor,
        child: Column(
          children: [
            // Filter Options Row
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildFilterChip('All', selectedFilter == 'All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Approved', selectedFilter == 'Approved'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', selectedFilter == 'Pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rejected', selectedFilter == 'Rejected'),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recent Activity Section
                    Text(
                      'Leave History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Loading, Error, or History Cards
                    if (isLoading)
                      _buildLoadingCard(cardColor, isDarkMode)
                    else if (errorMessage != null)
                      _buildErrorCard(cardColor, textColor, subtitleColor, isDarkMode)
                    else if (filteredLeaves.isEmpty)
                        _buildEmptyStateCard(cardColor, textColor, subtitleColor, isDarkMode)
                      else
                        ...filteredLeaves.map((record) => _buildLeaveCard(
                          record: record,
                          cardColor: cardColor,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                          isDarkMode: isDarkMode,
                        )),

                    const SizedBox(height: 100), // Space for bottom nav
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => _filterLeaves(label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF667EEA)
                : (isDarkMode ? const Color(0xFF2D2D2D) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF667EEA)
                  : (isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDarkMode ? Colors.white70 : Colors.grey[700]),
            ),
          ),
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

  Widget _buildErrorCard(Color cardColor, Color textColor, Color? subtitleColor, bool isDarkMode) {
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
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            errorMessage!,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadLeaveHistory,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667EEA),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
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
              Icons.event_busy,
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
                  selectedFilter == 'All' ? 'No Leave Records Found' : 'No ${selectedFilter} Leaves',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedFilter == 'All'
                      ? 'Your leave records will appear here'
                      : 'No ${selectedFilter.toLowerCase()} leaves found',
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

  Widget _buildLeaveCard({
    required Map<String, dynamic> record,
    required Color cardColor,
    required Color textColor,
    required Color? subtitleColor,
    required bool isDarkMode,
  }) {
    final status = record['Status__c']?.toString() ?? 'Unknown';
    final statusColor = _getStatusColor(status);
    final statusBgColor = _getStatusBackgroundColor(status, isDarkMode);
    final description = record['Description__c']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leave Type and Status Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Indicator
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  status.toLowerCase() == 'approved'
                      ? Icons.check_circle
                      : status.toLowerCase() == 'pending'
                      ? Icons.access_time
                      : Icons.cancel,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Leave Type with proper text wrapping
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record['Leave_Type__c']?.toString() ?? 'Leave',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      maxLines: 2, // Allow text to wrap to 2 lines
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Date Range and Duration - Fixed Layout
          Column(
            children: [
              // From and To dates in a row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(record['Start_Date__c']),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'To',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(record['End_Date__c']),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Duration row with description button and duration text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Description button
                  GestureDetector(
                    onTap: () => _showDescriptionPopup(description),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(isDarkMode ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:  Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  // Duration text

                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Duration: ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        TextSpan(
                          text: _calculateLeaveDuration(record['Start_Date__c'], record['End_Date__c']),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF667EEA),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}