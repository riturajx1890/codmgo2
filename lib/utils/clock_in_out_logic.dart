import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codmgo2/services/clock_in_out_service.dart';
import 'package:codmgo2/services/salesforce_api_service.dart';
import 'package:codmgo2/utils/shared_prefs_utils.dart'; // Import the SharedPrefsUtils
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:codmgo2/utils/location_logic.dart';
import 'timer_notification_logic.dart'; // Import the timer logic

enum ClockStatus { unmarked, clockedIn, clockedOut }

class ClockInOutLogic with ChangeNotifier {
  static final Logger _logger = Logger();

  ClockStatus _status = ClockStatus.unmarked;
  DateTime? inTime;
  DateTime? outTime;

  bool _canClockIn = true;
  bool _canClockOut = false;

  String? accessToken;
  String? instanceUrl;
  String? employeeId;
  String? userEmail;
  String? firstName;
  String? lastName;

  final LocationLogic _locationLogic = LocationLogic();

  // Timer logic integration
  late final TimerNotificationLogic _timerLogic;

  // Getters
  ClockStatus get status => _status;
  bool get canClockIn => _canClockIn;
  bool get canClockOut => _canClockOut;
  TimerNotificationLogic get timerLogic => _timerLogic; // Expose timer logic for external access

  String get statusText {
    switch (_status) {
      case ClockStatus.clockedIn:
        return "Clocked In";
      case ClockStatus.clockedOut:
        return "Clocked Out";
      default:
        return "Unmarked";
    }
  }

  ClockInOutLogic() {
    // Initialize timer logic with callback
    _timerLogic = TimerNotificationLogic(
      onStatusUpdate: updateClockStatus,
    );
    _loadTodayStatus();
  }

  @override
  void dispose() {
    _timerLogic.dispose();
    super.dispose();
  }

  // Static method for getting attendance history
  static Future<List<Map<String, dynamic>>> getAttendanceHistory(
      String accessToken,
      String instanceUrl,
      String employeeId, {
        int limit = 10,
      }) async {
    final Logger logger = Logger();

    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));

      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

      final query = """
      SELECT Id, In_Time__c, Out_Time__c, Date__c 
      FROM Attendance__c 
      WHERE Employee__c = '$employeeId' 
      AND Date__c >= $startDateStr 
      AND Date__c <= $endDateStr 
      ORDER BY Date__c DESC, In_Time__c DESC 
      LIMIT $limit
    """;

      final uri = Uri.parse('$instanceUrl/services/data/v57.0/query/')
          .replace(queryParameters: {'q': query});

      logger.i('Fetching attendance history with query: $query');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      logger.i('Attendance history response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List<dynamic>;

        logger.i('Found ${records.length} attendance records');

        return records.map((record) => record as Map<String, dynamic>).toList();
      } else {
        logger.e('Failed to fetch attendance history: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e, stackTrace) {
      logger.e('Error fetching attendance history: $e', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Future<void> _loadTodayStatus() async {
    _logger.i('Loading today\'s status on controller initialization');

    await _loadCredentials();
    final currentEmployeeId = await _getEmployeeId();

    if (currentEmployeeId != null && accessToken != null && instanceUrl != null) {
      try {
        final todayAttendance = await ClockInOutService.getTodayAttendance(
          accessToken!,
          instanceUrl!,
          currentEmployeeId,
        );

        if (todayAttendance != null) {
          if (todayAttendance['Out_Time__c'] != null) {
            // Already clocked out today
            _status = ClockStatus.clockedOut;
            inTime = DateTime.parse(todayAttendance['In_Time__c']).toLocal();
            outTime = DateTime.parse(todayAttendance['Out_Time__c']).toLocal();
            _canClockIn = false;
            _canClockOut = false;
            _logger.i('Found completed attendance for today');

            // Stop any running timers since user is already clocked out
            _timerLogic.stopTimers();
          } else {
            // Already clocked in today
            _status = ClockStatus.clockedIn;
            inTime = DateTime.parse(todayAttendance['In_Time__c']).toLocal();
            _canClockIn = false;
            _canClockOut = true;
            _logger.i('Found active clock-in for today');

            // Resume timers with existing clock in time
            _timerLogic.resumeTimers(inTime!);
          }
          notifyListeners();
        } else {
          // No attendance today
          _canClockIn = true;
          _canClockOut = false;
          _logger.i('No attendance found for today');

          // Ensure timers are stopped
          _timerLogic.stopTimers();
        }
      } catch (e, stackTrace) {
        _logger.e('Error loading today\'s status: $e', error: e, stackTrace: stackTrace);
      }
    }
  }

  Future<void> _loadCredentials() async {
    _logger.i('Loading credentials from SharedPreferences');

    try {
      // First check if remember me is valid and load data from there
      final rememberMeData = await SharedPrefsUtils.checkRememberMeStatus();

      if (rememberMeData != null) {
        _logger.i('Remember me data found, using cached employee data');
        employeeId = rememberMeData['employee_id'];
        firstName = rememberMeData['first_name'];
        lastName = rememberMeData['last_name'];

        // Load other credentials from SharedPreferences
        final employeeData = await SharedPrefsUtils.getEmployeeDataFromPrefs();
        accessToken = employeeData['access_token'];
        instanceUrl = employeeData['instance_url'];
        userEmail = employeeData['user_email'];

        _logger.i('Credentials loaded from remember me - employeeId: $employeeId, firstName: $firstName, lastName: $lastName');
        _logger.i('Additional credentials - accessToken: ${accessToken != null ? "present" : "null"}, instanceUrl: ${instanceUrl != null ? "present" : "null"}, userEmail: $userEmail');
        return;
      }

      // If no remember me data, fall back to regular SharedPreferences loading
      _logger.i('No remember me data found, loading from regular SharedPreferences');
      final employeeData = await SharedPrefsUtils.getEmployeeDataFromPrefs();

      accessToken = employeeData['access_token'];
      instanceUrl = employeeData['instance_url'];
      employeeId = employeeData['employee_id'];
      userEmail = employeeData['user_email'];
      firstName = employeeData['first_name'];
      lastName = employeeData['last_name'];

      _logger.i('Credentials loaded from SharedPreferences - accessToken: ${accessToken != null ? "present" : "null"}, instanceUrl: ${instanceUrl != null ? "present" : "null"}, employeeId: $employeeId, userEmail: $userEmail');
    } catch (e, stackTrace) {
      _logger.e('Error loading credentials: $e', error: e, stackTrace: stackTrace);
    }
  }

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

  Future<String?> _getEmployeeId() async {
    _logger.i('Getting employee ID - current employeeId: $employeeId');

    if (employeeId != null && employeeId!.isNotEmpty) {
      _logger.i('Employee ID already available: $employeeId');
      return employeeId;
    }

    try {
      // First check remember me status
      final rememberMeData = await SharedPrefsUtils.checkRememberMeStatus();

      if (rememberMeData != null && rememberMeData['employee_id'] != null) {
        final rememberMeEmployeeId = rememberMeData['employee_id']!;
        _logger.i('Employee ID found in remember me data: $rememberMeEmployeeId');
        employeeId = rememberMeEmployeeId;
        firstName = rememberMeData['first_name'];
        lastName = rememberMeData['last_name'];
        return employeeId;
      }

      // If no remember me data, check regular SharedPreferences
      final employeeData = await SharedPrefsUtils.getEmployeeDataFromPrefs();
      final storedEmployeeId = employeeData['employee_id'];

      if (storedEmployeeId != null && storedEmployeeId.isNotEmpty) {
        _logger.i('Employee ID found in SharedPreferences: $storedEmployeeId');
        employeeId = storedEmployeeId;
        return employeeId;
      }

      _logger.w('No employee ID found in SharedPreferences or remember me data');
    } catch (e, stackTrace) {
      _logger.e('Error loading employee ID: $e', error: e, stackTrace: stackTrace);
    }

    // If still no employee ID, try to fetch from Salesforce
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
          final fetchedFirstName = employee['First_Name__c']?.toString() ?? '';
          final fetchedLastName = employee['Last_Name__c']?.toString() ?? '';

          _logger.i('Employee fetched from Salesforce: $fetchedEmployeeId, $fetchedFirstName $fetchedLastName');

          // Save to both regular prefs and remember me if first/last names are available
          await _saveEmployeeId(fetchedEmployeeId);

          if (fetchedFirstName.isNotEmpty && fetchedLastName.isNotEmpty) {
            await SharedPrefsUtils.saveRememberMeStatus(
                fetchedEmployeeId,
                fetchedFirstName,
                fetchedLastName
            );
            firstName = fetchedFirstName;
            lastName = fetchedLastName;
            _logger.i('Saved employee data to remember me');
          }

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

  Future<bool> checkIfAlreadyClockedInToday() async {
    await _loadCredentials();
    final currentEmployeeId = await _getEmployeeId();

    if (currentEmployeeId == null || accessToken == null || instanceUrl == null) {
      return false;
    }

    try {
      final todayAttendance = await ClockInOutService.getTodayAttendance(
        accessToken!,
        instanceUrl!,
        currentEmployeeId,
      );

      return todayAttendance != null && todayAttendance['Out_Time__c'] == null;
    } catch (e, stackTrace) {
      _logger.e('Error checking today\'s attendance: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> checkIfAlreadyClockedOutToday() async {
    await _loadCredentials();
    final currentEmployeeId = await _getEmployeeId();

    if (currentEmployeeId == null || accessToken == null || instanceUrl == null) {
      return false;
    }

    try {
      final todayAttendance = await ClockInOutService.getTodayAttendance(
        accessToken!,
        instanceUrl!,
        currentEmployeeId,
      );

      return todayAttendance != null && todayAttendance['Out_Time__c'] != null;
    } catch (e, stackTrace) {
      _logger.e('Error checking today\'s clock out status: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  Future<Map<String, dynamic>> attemptClockInOut({required bool isClockIn}) async {
    _logger.i('Starting clock ${isClockIn ? "in" : "out"} attempt');

    // Check if user can clock out
    if (!isClockIn && !_canClockOut) {
      _logger.w('Clock out attempted but not allowed');
      return {
        'success': false,
        'message': 'You need to clock in first.',
      };
    }

    final locationResult = await _locationLogic.isWithinRadius();
    if (!locationResult['isInRadius']) {
      _logger.w('Location check failed: ${locationResult['message']}');
      return {
        'success': false,
        'message': locationResult['message'],
      };
    }
    _logger.i('Location check passed');

    await _loadCredentials();

    if (accessToken == null) {
      _logger.e('Access token is null');
      return {
        'success': false,
        'message': 'Salesforce access token not found. Please login again.',
      };
    }

    if (instanceUrl == null) {
      _logger.e('Instance URL is null');
      return {
        'success': false,
        'message': 'Salesforce instance URL not found. Please login again.',
      };
    }

    _logger.i('Getting employee ID...');
    final currentEmployeeId = await _getEmployeeId();
    if (currentEmployeeId == null || currentEmployeeId.isEmpty) {
      _logger.e('Employee ID is null or empty');
      return {
        'success': false,
        'message': 'Employee record not found. Please contact administrator.',
      };
    }

    _logger.i('Using employee ID: $currentEmployeeId');

    try {
      if (isClockIn) {
        _logger.i('Attempting clock in...');
        final recordId = await ClockInOutService.clockIn(
          accessToken!,
          instanceUrl!,
          currentEmployeeId,
          DateTime.now().toUtc(), // Send UTC time to Salesforce
        );

        if (recordId != null) {
          _logger.i('Clock in successful - record ID: $recordId');
          _status = ClockStatus.clockedIn;
          inTime = DateTime.now(); // Store local time for UI
          outTime = null;
          _canClockIn = false;
          _canClockOut = true;
          notifyListeners();

          // Update remember me status after successful clock in
          if (firstName != null && lastName != null &&
              firstName!.isNotEmpty && lastName!.isNotEmpty) {
            await SharedPrefsUtils.saveRememberMeStatus(
                currentEmployeeId,
                firstName!,
                lastName!
            );
            _logger.i('Updated remember me status after clock in');
          }

          // Start timers after successful clock in
          _timerLogic.startTimers(inTime!);
          _logger.i('Started timer logic for clock in');

          return {
            'success': true,
            'message': 'Successfully clocked in!',
            'recordId': recordId,
          };
        } else {
          _logger.e('Clock in failed - no record ID returned');
          return {
            'success': false,
            'message': 'Failed to clock in. Please try again.',
          };
        }
      } else {
        _logger.i('Attempting clock out - getting today\'s attendance...');
        final todayAttendance = await ClockInOutService.getTodayAttendance(
          accessToken!,
          instanceUrl!,
          currentEmployeeId,
        );

        if (todayAttendance != null && todayAttendance['Id'] != null) {
          _logger.i('Today\'s attendance found - record ID: ${todayAttendance['Id']}');
          final success = await ClockInOutService.clockOut(
            accessToken!,
            instanceUrl!,
            todayAttendance['Id'],
            DateTime.now().toUtc(), // Send UTC time to Salesforce
          );

          if (success) {
            _logger.i('Clock out successful');
            _status = ClockStatus.clockedOut;
            outTime = DateTime.now(); // Store local time for UI
            _canClockIn = false; // Will be enabled after 18 hours
            _canClockOut = false;
            notifyListeners();

            // Update remember me status after successful clock out
            if (firstName != null && lastName != null &&
                firstName!.isNotEmpty && lastName!.isNotEmpty) {
              await SharedPrefsUtils.saveRememberMeStatus(
                  currentEmployeeId,
                  firstName!,
                  lastName!
              );
              _logger.i('Updated remember me status after clock out');
            }

            // Stop timers after successful clock out
            _timerLogic.stopTimers();
            _logger.i('Stopped timer logic for clock out');

            return {
              'success': true,
              'message': 'Successfully clocked out!',
            };
          } else {
            _logger.e('Clock out failed');
            return {
              'success': false,
              'message': 'Failed to clock out. Please try again.',
            };
          }
        } else {
          _logger.w('No active clock-in record found for today');
          return {
            'success': false,
            'message': 'No active clock-in record found for today.',
          };
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error during clock ${isClockIn ? "in" : "out"}: $e', error: e, stackTrace: stackTrace);
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }

  Future<void> initializeEmployeeData(String email) async {
    _logger.i('Initializing employee data for email: $email');

    try {
      // Use SharedPrefsUtils to save employee data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      userEmail = email;

      // Clear existing employee data
      employeeId = null;
      firstName = null;
      lastName = null;
      await prefs.remove('employee_id');
      await prefs.remove('current_employee_id');

      _logger.i('Employee data initialized, getting employee ID...');
      final fetchedEmployeeId = await _getEmployeeId();

      if (fetchedEmployeeId != null) {
        _logger.i('Employee data initialization complete with ID: $fetchedEmployeeId');
      } else {
        _logger.w('Employee data initialization completed but no employee ID found');
      }
    } catch (e, stackTrace) {
      _logger.e('Error initializing employee data: $e', error: e, stackTrace: stackTrace);
    }
  }

  // Method to update clock in/out status from external sources (like timer logic)
  void updateClockStatus({
    required ClockStatus status,
    DateTime? clockInTime,
    DateTime? clockOutTime,
    bool? canClockIn,
    bool? canClockOut,
  }) {
    _logger.i('Updating clock status from external source - status: $status, canClockIn: $canClockIn, canClockOut: $canClockOut');

    _status = status;
    if (clockInTime != null) inTime = clockInTime;
    if (clockOutTime != null) outTime = clockOutTime;
    if (canClockIn != null) _canClockIn = canClockIn;
    if (canClockOut != null) _canClockOut = canClockOut;
    notifyListeners();
  }

  // Method to enable clock in (typically called by timer logic after 18 hours)
  void enableClockIn() {
    _logger.i('Enabling clock in from external trigger');
    _canClockIn = true;
    notifyListeners();
  }

  // Method to disable clock out (typically called by timer logic during auto clock out)
  void disableClockOut() {
    _logger.i('Disabling clock out from external trigger');
    _canClockOut = false;
    notifyListeners();
  }

  // Helper methods to access timer information
  bool get hasActiveTimers => _timerLogic.hasActiveTimers;
  bool get isTimerClockIn => _timerLogic.isClockIn;
  DateTime? get timerClockInTime => _timerLogic.clockInTime;
  int get notificationCount => _timerLogic.notificationCount;

  // Methods to get remaining times for various timers
  Duration? getRemainingAutoClockOutTime() => _timerLogic.getRemainingAutoClockOutTime();
  Duration? getRemainingNotificationTime() => _timerLogic.getRemainingNotificationTime();
  Duration? getRemaining18HourTime() => _timerLogic.getRemaining18HourTime();

  // Method for testing notifications
  Future<void> sendTestNotification() => _timerLogic.sendTestNotification();

  // Method to clear remember me data (useful for logout)
  Future<void> clearRememberMe() async {
    _logger.i('Clearing remember me data');
    await SharedPrefsUtils.clearRememberMeData();
    firstName = null;
    lastName = null;
  }

  // Method to manually save remember me data
  Future<void> saveRememberMe() async {
    if (employeeId != null && firstName != null && lastName != null &&
        employeeId!.isNotEmpty && firstName!.isNotEmpty && lastName!.isNotEmpty) {
      _logger.i('Manually saving remember me data');
      await SharedPrefsUtils.saveRememberMeStatus(employeeId!, firstName!, lastName!);
    } else {
      _logger.w('Cannot save remember me data - missing required information');
    }
  }
}