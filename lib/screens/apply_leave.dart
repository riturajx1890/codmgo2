import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum LeaveType { casual, halfDay, oneDay, sick }

class ApplyLeavePage extends StatefulWidget {
  final String employeeId;

  const ApplyLeavePage({Key? key, required this.employeeId}) : super(key: key);

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  LeaveType? _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  int _currentIndex = 1; // Default to Leave tab

  final Map<LeaveType, String> _leaveTypeDisplayNames = {
    LeaveType.casual: 'Casual Leave',
    LeaveType.halfDay: 'Half-Day Leave',
    LeaveType.oneDay: 'One Day Leave',
    LeaveType.sick: 'Medical Leave',
  };

  final Map<LeaveType, IconData> _leaveTypeIcons = {
    LeaveType.casual: Icons.beach_access,
    LeaveType.halfDay: Icons.schedule,
    LeaveType.oneDay: Icons.today,
    LeaveType.sick: Icons.local_hospital,
  };

  final Map<LeaveType, Color> _leaveTypeColors = {
    LeaveType.casual: const Color(0xFF667EEA),
    LeaveType.halfDay: const Color(0xFF48BB78),
    LeaveType.oneDay: const Color(0xFF9F7AEA),
    LeaveType.sick: const Color(0xFFED8936),
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  bool _canBackdate(LeaveType type) {
    return type == LeaveType.sick;
  }

  bool _isSingleDayLeave(LeaveType type) {
    return type == LeaveType.halfDay || type == LeaveType.oneDay;
  }

  Future<void> _selectStartDate() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: _selectedLeaveType != null && _canBackdate(_selectedLeaveType!)
          ? DateTime.now().subtract(const Duration(days: 30))
          : DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF667EEA),
              onPrimary: Colors.white,
              surface: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              onSurface: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_selectedLeaveType != null && _isSingleDayLeave(_selectedLeaveType!)) {
          _endDate = picked;
        } else if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start date first')),
      );
      return;
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF667EEA),
              onPrimary: Colors.white,
              surface: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              onSurface: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLeaveType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a leave type')),
      );
      return;
    }

    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start date')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false, // Allow dismissal on tap outside
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).pop(); // Close dialog
            Navigator.of(context).pop(); // Go back to previous screen
          },
          child: AlertDialog(
            backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF48BB78).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF48BB78),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Success!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your ${_leaveTypeDisplayNames[_selectedLeaveType!]} request has been submitted successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Go back to previous screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667EEA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      shadowColor: Colors.transparent,
                      side: const BorderSide(
                        color: Color(0xFF667EEA),
                        width: 1,
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // void _onBottomNavTap(int index) {
  //   setState(() {
  //     _currentIndex = index;
  //   });
  //
  //   switch (index) {
  //     case 0:
  //       Navigator.pushReplacementNamed(context, '/dashboard', arguments: {
  //         'employeeId': widget.employeeId,
  //       });
  //       break;
  //     case 1:
  //       break;
  //     case 2:
  //       Navigator.pushNamed(context, '/attendance_history', arguments: {
  //         'employeeId': widget.employeeId,
  //       }).then((_) {
  //         setState(() {
  //           _currentIndex = 1;
  //         });
  //       });
  //       break;
  //     case 3:
  //       Navigator.pushNamed(context, '/profile', arguments: {
  //         'employeeId': widget.employeeId,
  //       }).then((_) {
  //         setState(() {
  //           _currentIndex = 1;
  //         });
  //       });
  //       break;
  //   }
  // }

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
        backgroundColor: cardColor,
        title: Text(
          'Apply for Leave',
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Leave Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildLeaveTypeCard(LeaveType.casual, isDarkMode, cardColor, textColor)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildLeaveTypeCard(LeaveType.halfDay, isDarkMode, cardColor, textColor)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildLeaveTypeCard(LeaveType.oneDay, isDarkMode, cardColor, textColor)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildLeaveTypeCard(LeaveType.sick, isDarkMode, cardColor, textColor)),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Select Dates',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildDateSelector(
                'Start Date',
                _startDate,
                Icons.calendar_today,
                _selectStartDate,
                isDarkMode,
                cardColor,
                textColor,
                subtitleColor,
              ),
              const SizedBox(height: 16),
              if (_selectedLeaveType == null || !_isSingleDayLeave(_selectedLeaveType!))
                _buildDateSelector(
                  'End Date (Optional)',
                  _endDate,
                  Icons.event,
                  _selectEndDate,
                  isDarkMode,
                  cardColor,
                  textColor,
                  subtitleColor,
                ),
              if (_selectedLeaveType != null && _isSingleDayLeave(_selectedLeaveType!)) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_leaveTypeDisplayNames[_selectedLeaveType!]} is only applicable for a single day.',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_selectedLeaveType != null && _canBackdate(_selectedLeaveType!)) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sick/Medical Leave can be backdated up to 30 days.',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Text(
                'Description (Optional)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Enter reason for leave (optional)',
                    hintStyle: TextStyle(color: subtitleColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitLeaveRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667EEA),
                    disabledBackgroundColor: const Color(0xFF667EEA),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    side: const BorderSide(
                      color: Color(0xFF667EEA),
                      width: 1,
                    ),
                  ),
                  child: _isLoading
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Submitting...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                      : const Text(
                    'Submit Leave Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12), // Space for bottom nav bar
            ],
          ),
        ),
      ),
      extendBody: true,
    //   bottomNavigationBar: BottomNavigationBar(
    //     type: BottomNavigationBarType.fixed,
    //     backgroundColor: cardColor,
    //     selectedItemColor: const Color(0xFF667EEA),
    //     unselectedItemColor: isDarkMode ? Colors.grey[500] : Colors.grey[400],
    //     currentIndex: _currentIndex,
    //     elevation: 10,
    //     onTap: _onBottomNavTap,
    //     items: const [
    //       BottomNavigationBarItem(
    //         icon: Icon(Icons.home),
    //         activeIcon: Icon(Icons.home),
    //         label: 'Home',
    //       ),
    //       BottomNavigationBarItem(
    //         icon: Icon(Icons.event_available_outlined),
    //         activeIcon: Icon(Icons.event_available),
    //         label: 'Leave',
    //       ),
    //       BottomNavigationBarItem(
    //         icon: Icon(Icons.calendar_month),
    //         activeIcon: Icon(Icons.calendar_month),
    //         label: 'Attendance',
    //       ),
    //       BottomNavigationBarItem(
    //         icon: Icon(Icons.person_outline),
    //         activeIcon: Icon(Icons.person),
    //         label: 'Profile',
    //       ),
    //     ],
    //   ),
    );
  }

  Widget _buildLeaveTypeCard(LeaveType type, bool isDarkMode, Color cardColor, Color textColor) {
    final isSelected = _selectedLeaveType == type;
    final color = _leaveTypeColors[type]!;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedLeaveType == type) {
            _selectedLeaveType = null;
            _startDate = null;
            _endDate = null;
          } else {
            _selectedLeaveType = type;
            _startDate = DateTime.now();
            if (_isSingleDayLeave(type)) {
              _endDate = DateTime.now();
            } else {
              _endDate = null;
            }
          }
        });
      },
      child: Container(
        height: 140, // Increased height
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withOpacity(0.2)
                  : isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48, // Increased icon container size
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _leaveTypeIcons[type],
                color: color,
                size: 24, // Increased icon size
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _leaveTypeDisplayNames[type]!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14, // Increased from 12 to 14
                fontWeight: FontWeight.w600,
                color: isSelected ? color : textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _getLeaveTypeDescription(type),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13, // Increased from 10 to 13
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime? date, IconData icon, VoidCallback onTap,
      bool isDarkMode, Color cardColor, Color textColor, Color? subtitleColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF667EEA).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF667EEA), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date != null
                        ? DateFormat('EEEE, MMM dd, yyyy').format(date)
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 16,
                      color: date != null ? textColor : subtitleColor,
                      fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.calendar_today,
              color: subtitleColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _getLeaveTypeDescription(LeaveType type) {
    switch (type) {
      case LeaveType.casual:
        return 'Personal & recreational';
      case LeaveType.halfDay:
        return 'Half day (4 hours)';
      case LeaveType.oneDay:
        return 'Single day absence';
      case LeaveType.sick:
        return 'Medical (backdated)';
    }
  }
}