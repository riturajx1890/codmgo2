import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codmgo2/services/leave_api_service.dart';
import 'package:codmgo2/services/salesforce_api_service.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

enum LeaveType { casual, halfDay, oneDay, sick }

class LeaveLogic with ChangeNotifier {
  static final Logger _logger = Logger();

  // Leave state
  List<Map<String, dynamic>> _leaveHistory = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Credentials
  String? accessToken;
  String? instanceUrl;
  String? employeeId;
  String? userEmail;

  // Getters
  List<Map<String, dynamic>> get leaveHistory => _leaveHistory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Leave type mapping
  static const Map<LeaveType, String> _leaveTypeMap = {
    LeaveType.casual: 'casual',
    LeaveType.halfDay: 'halfDay',
    LeaveType.oneDay: 'oneDay',
    LeaveType.sick: 'sick',
  };

  static const Map<LeaveType, String> _leaveTypeDisplayNames = {
    LeaveType.casual: 'Casual Leave',
    LeaveType.halfDay: 'Half-Day Leave',
    LeaveType.oneDay: 'One Day Leave',
    LeaveType.sick: 'Sick Leave/ Medical Leave',
  };

  LeaveLogic() {
    _loadLeaveHistory();
  }

  /// Get display name for leave type
  String getLeaveTypeDisplayName(LeaveType type) {
    return _leaveTypeDisplayNames[type] ?? 'Unknown';
  }

  /// Check if leave type allows back dating
  bool canBackdate(LeaveType type) {
    return type == LeaveType.sick; // Only sick/medical leave can be backdated
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Load credentials from SharedPreferences
  Future<void> _loadCredentials() async {
    _logger.i('Loading credentials from SharedPreferences');

    try {
      final prefs = await SharedPreferences.getInstance();
      accessToken = prefs.getString('access_token');
      instanceUrl = prefs.getString('instance_url');
      employeeId = prefs.getString('employee_id') ?? prefs.getString('current_employee_id');
      userEmail = prefs.getString('user_email');

      _logger.i('Credentials loaded - accessToken: ${accessToken != null ? "present" : "null"}, instanceUrl: ${instanceUrl != null ? "present" : "null"}, employeeId: $employeeId, userEmail: $userEmail');
    } catch (e, stackTrace) {
      _logger.e('Error loading credentials: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Save employee ID
  Future<void> _saveEmployeeId(String empId) async {
    _logger.i('Saving employee ID: $empId');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employee_id', empId);
      await prefs.setString('current_employee_id', empId);
      employeeId = empId;

      _logger.i('Employee ID saved successfully');
    } catch (e, stackTrace) {
      _logger.e('Error saving employee ID: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Get employee ID
  Future<String?> _getEmployeeId() async {
    _logger.i('Getting employee ID - current employeeId: $employeeId');

    if (employeeId != null && employeeId!.isNotEmpty) {
      _logger.i('Employee ID already available: $employeeId');
      return employeeId;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedEmployeeId = prefs.getString('employee_id') ?? prefs.getString('current_employee_id');

      if (storedEmployeeId != null && storedEmployeeId.isNotEmpty) {
        _logger.i('Employee ID found in SharedPreferences: $storedEmployeeId');
        employeeId = storedEmployeeId;
        return employeeId;
      }

      _logger.w('No employee ID found in SharedPreferences');
    } catch (e, stackTrace) {
      _logger.e('Error loading employee ID from SharedPreferences: $e', error: e, stackTrace: stackTrace);
    }

    if (userEmail != null && userEmail!.isNotEmpty &&
        accessToken != null && instanceUrl != null) {
      _logger.i('Attempting to fetch employee from Salesforce using email: $userEmail');

      try {
        final employee = await SalesforceApiService.getEmployeeByEmail(
          accessToken!,
          instanceUrl!,
          userEmail!,
        );

        if (employee != null && employee['Id'] != null) {
          final fetchedEmployeeId = employee['Id'].toString();
          _logger.i('Employee fetched from Salesforce: $fetchedEmployeeId');

          await _saveEmployeeId(fetchedEmployeeId);
          return fetchedEmployeeId;
        } else {
          _logger.w('No employee found in Salesforce for email: $userEmail');
        }
      } catch (e, stackTrace) {
        _logger.e('Error fetching employee from Salesforce: $e', error: e, stackTrace: stackTrace);
      }
    } else {
      _logger.w('Cannot fetch employee from Salesforce - missing required data: userEmail: $userEmail, accessToken: ${accessToken != null}, instanceUrl: ${instanceUrl != null}');
    }

    _logger.e('Failed to get employee ID from all sources');
    return null;
  }

  /// Load leave history
  Future<void> _loadLeaveHistory() async {
    _logger.i('Loading leave history');
    _setLoading(true);
    _setError(null);

    try {
      await _loadCredentials();
      final currentEmployeeId = await _getEmployeeId();

      if (currentEmployeeId == null || accessToken == null || instanceUrl == null) {
        _setError('Employee credentials not found. Please login again.');
        return;
      }

      final leaves = await LeaveApiService.getLeavesByEmployee(
        accessToken!,
        instanceUrl!,
        currentEmployeeId,
      );

      if (leaves != null) {
        _leaveHistory = leaves;
        _logger.i('Loaded ${leaves.length} leave records');
      } else {
        _setError('Failed to load leave history');
      }
    } catch (e, stackTrace) {
      _logger.e('Error loading leave history: $e', error: e, stackTrace: stackTrace);
      _setError('Error loading leave history: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh leave history
  Future<void> refreshLeaveHistory() async {
    await _loadLeaveHistory();
  }

  /// Apply for leave
  Future<Map<String, dynamic>> applyForLeave({
    required LeaveType leaveType,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
  }) async {
    _logger.i('Applying for leave - Type: ${getLeaveTypeDisplayName(leaveType)}, Start: $startDate, End: $endDate');

    _setLoading(true);
    _setError(null);

    try {
      // Validate inputs
      final validationResult = _validateLeaveRequest(leaveType, startDate, endDate);
      if (!validationResult['isValid']) {
        _setError(validationResult['message']);
        return {
          'success': false,
          'message': validationResult['message'],
        };
      }

      await _loadCredentials();
      final currentEmployeeId = await _getEmployeeId();

      if (currentEmployeeId == null || accessToken == null || instanceUrl == null) {
        const errorMsg = 'Employee credentials not found. Please login again.';
        _setError(errorMsg);
        return {
          'success': false,
          'message': errorMsg,
        };
      }

      // Use the quick leave request method from LeaveApiService
      final leaveTypeKey = _leaveTypeMap[leaveType]!;
      final result = await LeaveApiService.quickLeaveRequest(
        accessToken!,
        instanceUrl!,
        currentEmployeeId,
        leaveTypeKey,
        startDate,
        endDate,
        description,
      );

      if (result.startsWith('✅')) {
        _logger.i('Leave request successful: $result');
        // Refresh the leave history
        await _loadLeaveHistory();
        return {
          'success': true,
          'message': result,
        };
      } else {
        _logger.e('Leave request failed: $result');
        _setError(result);
        return {
          'success': false,
          'message': result,
        };
      }
    } catch (e, stackTrace) {
      _logger.e('Error applying for leave: $e', error: e, stackTrace: stackTrace);
      final errorMsg = 'Error applying for leave: ${e.toString()}';
      _setError(errorMsg);
      return {
        'success': false,
        'message': errorMsg,
      };
    } finally {
      _setLoading(false);
    }
  }

  /// Validate leave request
  Map<String, dynamic> _validateLeaveRequest(LeaveType leaveType, DateTime startDate, DateTime? endDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final requestDate = DateTime(startDate.year, startDate.month, startDate.day);

    // Check if backdating is allowed
    if (requestDate.isBefore(today) && !canBackdate(leaveType)) {
      return {
        'isValid': false,
        'message': 'Back dating is only allowed for Sick/Medical Leave',
      };
    }

    // Validate date range
    if (endDate != null && endDate.isBefore(startDate)) {
      return {
        'isValid': false,
        'message': 'End date cannot be before start date',
      };
    }

    // Validate single day leaves
    if (leaveType == LeaveType.halfDay || leaveType == LeaveType.oneDay) {
      if (endDate != null && !_isSameDay(startDate, endDate)) {
        return {
          'isValid': false,
          'message': '${getLeaveTypeDisplayName(leaveType)} can only be applied for a single day',
        };
      }
    }

    // Check if start date is too far in the past (more than 30 days)
    if (requestDate.isBefore(today.subtract(const Duration(days: 30)))) {
      return {
        'isValid': false,
        'message': 'Cannot apply for leave more than 30 days in the past',
      };
    }

    // Check if start date is too far in the future (more than 365 days)
    if (requestDate.isAfter(today.add(const Duration(days: 365)))) {
      return {
        'isValid': false,
        'message': 'Cannot apply for leave more than 1 year in advance',
      };
    }

    return {
      'isValid': true,
      'message': 'Valid leave request',
    };
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Update leave request
  Future<Map<String, dynamic>> updateLeaveRequest({
    required String leaveRecordId,
    LeaveType? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
  }) async {
    _logger.i('Updating leave request: $leaveRecordId');

    _setLoading(true);
    _setError(null);

    try {
      await _loadCredentials();

      if (accessToken == null || instanceUrl == null) {
        const errorMsg = 'Credentials not found. Please login again.';
        _setError(errorMsg);
        return {
          'success': false,
          'message': errorMsg,
        };
      }

      // Convert leave type to string if provided
      String? leaveTypeStr;
      if (leaveType != null) {
        leaveTypeStr = LeaveApiService.leaveTypes[_leaveTypeMap[leaveType]];
      }

      final success = await LeaveApiService.updateLeaveRequest(
        accessToken!,
        instanceUrl!,
        leaveRecordId,
        leaveTypeStr,
        startDate,
        endDate,
        description,
      );

      if (success) {
        _logger.i('Leave request updated successfully');
        // Refresh the leave history
        await _loadLeaveHistory();
        return {
          'success': true,
          'message': 'Leave request updated successfully',
        };
      } else {
        const errorMsg = 'Failed to update leave request';
        _setError(errorMsg);
        return {
          'success': false,
          'message': errorMsg,
        };
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating leave request: $e', error: e, stackTrace: stackTrace);
      final errorMsg = 'Error updating leave request: ${e.toString()}';
      _setError(errorMsg);
      return {
        'success': false,
        'message': errorMsg,
      };
    } finally {
      _setLoading(false);
    }
  }

  /// Delete leave request
  Future<Map<String, dynamic>> deleteLeaveRequest(String leaveRecordId) async {
    _logger.i('Deleting leave request: $leaveRecordId');

    _setLoading(true);
    _setError(null);

    try {
      await _loadCredentials();

      if (accessToken == null || instanceUrl == null) {
        const errorMsg = 'Credentials not found. Please login again.';
        _setError(errorMsg);
        return {
          'success': false,
          'message': errorMsg,
        };
      }

      final success = await LeaveApiService.deleteLeaveRequest(
        accessToken!,
        instanceUrl!,
        leaveRecordId,
      );

      if (success) {
        _logger.i('Leave request deleted successfully');
        // Refresh the leave history
        await _loadLeaveHistory();
        return {
          'success': true,
          'message': 'Leave request deleted successfully',
        };
      } else {
        const errorMsg = 'Failed to delete leave request';
        _setError(errorMsg);
        return {
          'success': false,
          'message': errorMsg,
        };
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting leave request: $e', error: e, stackTrace: stackTrace);
      final errorMsg = 'Error deleting leave request: ${e.toString()}';
      _setError(errorMsg);
      return {
        'success': false,
        'message': errorMsg,
      };
    } finally {
      _setLoading(false);
    }
  }

  /// Get leaves for date range
  Future<List<Map<String, dynamic>>> getLeavesByDateRange(
      DateTime startDate,
      DateTime endDate,
      ) async {
    _logger.i('Getting leaves for date range: $startDate to $endDate');

    try {
      await _loadCredentials();
      final currentEmployeeId = await _getEmployeeId();

      if (currentEmployeeId == null || accessToken == null || instanceUrl == null) {
        _logger.e('Missing credentials for date range query');
        return [];
      }

      final leaves = await LeaveApiService.getLeavesByDateRange(
        accessToken!,
        instanceUrl!,
        currentEmployeeId,
        startDate,
        endDate,
      );

      return leaves ?? [];
    } catch (e, stackTrace) {
      _logger.e('Error getting leaves by date range: $e', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get today's leaves
  Future<List<Map<String, dynamic>>> getTodayLeaves() async {
    _logger.i('Getting today\'s leaves');

    try {
      await _loadCredentials();
      final currentEmployeeId = await _getEmployeeId();

      if (currentEmployeeId == null || accessToken == null || instanceUrl == null) {
        _logger.e('Missing credentials for today\'s leaves query');
        return [];
      }

      final leaves = await LeaveApiService.getTodayLeaves(
        accessToken!,
        instanceUrl!,
        currentEmployeeId,
      );

      return leaves ?? [];
    } catch (e, stackTrace) {
      _logger.e('Error getting today\'s leaves: $e', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Check if user is on leave today
  Future<bool> isOnLeaveToday() async {
    final todayLeaves = await getTodayLeaves();
    return todayLeaves.isNotEmpty;
  }

  /// Initialize employee data
  Future<void> initializeEmployeeData(String email) async {
    _logger.i('Initializing employee data for email: $email');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      userEmail = email;

      employeeId = null;
      await prefs.remove('employee_id');
      await prefs.remove('current_employee_id');

      _logger.i('Employee data initialized, getting employee ID...');
      await _getEmployeeId();

      _logger.i('Employee data initialization complete');
      // Refresh leave history with new employee data
      await _loadLeaveHistory();
    } catch (e, stackTrace) {
      _logger.e('Error initializing employee data: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Format date for display
  String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Format datetime for display
  String formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  /// Get leave status text
  String getLeaveStatusText(Map<String, dynamic> leave) {
    // This would depend on your Salesforce leave object structure
    // You might have a Status__c field or similar
    return leave['Status__c'] ?? 'Pending';
  }

  /// Get leave duration in days
  int getLeaveDuration(Map<String, dynamic> leave) {
    try {
      final startDateStr = leave['Start_Date__c'];
      final endDateStr = leave['End_Date__c'];

      if (startDateStr != null && endDateStr != null) {
        final startDate = DateTime.parse(startDateStr);
        final endDate = DateTime.parse(endDateStr);
        return endDate.difference(startDate).inDays + 1;
      }
    } catch (e) {
      _logger.e('Error calculating leave duration: $e');
    }
    return 1;
  }
}