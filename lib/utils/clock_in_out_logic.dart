import 'package:flutter/material.dart';
import 'package:codmgo2/services/clock_in_out_service.dart';
import 'package:codmgo2/services/salesforce_api_service.dart';
import 'package:codmgo2/utils/shared_prefs_utils.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'timer_notification_logic.dart';

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

  // Timer logic integration
  late final TimerNotificationLogic _timerLogic;

  // Getters
  ClockStatus get status => _status;
  bool get canClockIn => _canClockIn;
  bool get canClockOut => _canClockOut;
  TimerNotificationLogic get timerLogic => _timerLogic;

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

    if (employeeId != null && accessToken != null && instanceUrl != null) {
      try {
        final todayAttendance = await ClockInOutService.getTodayAttendance(
          accessToken!,
          instanceUrl!,
          employeeId!,
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
    _logger.i('Loading credentials from SharedPrefsUtils');

    try {
      // Get valid credentials with employee ID using SharedPrefsUtils
      final credentialsWithId = await SharedPrefsUtils.getValidCredentialsWithEmployeeId();

      if (credentialsWithId != null) {
        accessToken = credentialsWithId['access_token'];
        instanceUrl = credentialsWithId['instance_url'];
        employeeId = credentialsWithId['employee_id'];

        _logger.i('Credentials loaded successfully - employeeId: $employeeId');

        // Load additional user data from remember me or stored preferences
        final rememberMeData = await SharedPrefsUtils.checkRememberMeStatus();
        if (rememberMeData != null) {
          firstName = rememberMeData['first_name'];
          lastName = rememberMeData['last_name'];
          userEmail = rememberMeData['email'];
          _logger.i('User data loaded from remember me');
        }

        return;
      }

      // Fallback: try to get credentials separately
      final salesforceCredentials = await SharedPrefsUtils.getSalesforceCredentials();
      if (salesforceCredentials != null) {
        accessToken = salesforceCredentials['access_token'];
        instanceUrl = salesforceCredentials['instance_url'];
      }

      // Try to get employee ID
      employeeId = await SharedPrefsUtils.getCurrentEmployeeId();

      // Load user data from remember me
      final rememberMeData = await SharedPrefsUtils.checkRememberMeStatus();
      if (rememberMeData != null) {
        firstName = rememberMeData['first_name'];
        lastName = rememberMeData['last_name'];
        userEmail = rememberMeData['email'];
        // If employee ID is missing but available in remember me, use it
        if (employeeId == null) {
          employeeId = rememberMeData['employee_id'];
        }
      }

      _logger.i('Credentials loaded - accessToken: ${accessToken != null ? "present" : "null"}, instanceUrl: ${instanceUrl != null ? "present" : "null"}, employeeId: $employeeId');
    } catch (e, stackTrace) {
      _logger.e('Error loading credentials: $e', error: e, stackTrace: stackTrace);
    }
  }

  Future<bool> checkIfAlreadyClockedInToday() async {
    await _loadCredentials();

    if (employeeId == null || accessToken == null || instanceUrl == null) {
      return false;
    }

    try {
      final todayAttendance = await ClockInOutService.getTodayAttendance(
        accessToken!,
        instanceUrl!,
        employeeId!,
      );

      return todayAttendance != null && todayAttendance['Out_Time__c'] == null;
    } catch (e, stackTrace) {
      _logger.e('Error checking today\'s attendance: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> checkIfAlreadyClockedOutToday() async {
    await _loadCredentials();

    if (employeeId == null || accessToken == null || instanceUrl == null) {
      return false;
    }

    try {
      final todayAttendance = await ClockInOutService.getTodayAttendance(
        accessToken!,
        instanceUrl!,
        employeeId!,
      );

      return todayAttendance != null && todayAttendance['Out_Time__c'] != null;
    } catch (e, stackTrace) {
      _logger.e('Error checking today\'s clock out status: $e', error: e, stackTrace: stackTrace);
      return false;
    }
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

    // Load credentials from SharedPrefsUtils
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

    if (employeeId == null || employeeId!.isEmpty) {
      _logger.e('Employee ID is null or empty');
      return {
        'success': false,
        'message': 'Employee record not found. Please contact administrator.',
      };
    }

    _logger.i('Using employee ID: $employeeId');

    try {
      if (isClockIn) {
        _logger.i('Attempting clock in...');
        final recordId = await ClockInOutService.clockIn(
          accessToken!,
          instanceUrl!,
          employeeId!,
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
                employeeId!,
                firstName!,
                lastName!,
                email: userEmail
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
          employeeId!,
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
                  employeeId!,
                  firstName!,
                  lastName!,
                  email: userEmail
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

  Future<void> initializeEmployeeData({String? email}) async {
    _logger.i('Initializing employee data${email != null ? ' for email: $email' : ''}');

    try {
      if (email != null) {
        userEmail = email;
      }

      // Load all credentials using SharedPrefsUtils
      await _loadCredentials();

      // If we still don't have employee ID and we have email and Salesforce credentials,
      // try to fetch from Salesforce
      if (employeeId == null && userEmail != null && userEmail!.isNotEmpty &&
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

            // Save employee ID for current session
            await SharedPrefsUtils.saveCurrentSessionEmployeeId(fetchedEmployeeId);
            employeeId = fetchedEmployeeId;

            // Save to remember me if first/last names are available
            if (fetchedFirstName.isNotEmpty && fetchedLastName.isNotEmpty) {
              await SharedPrefsUtils.saveRememberMeStatus(
                  fetchedEmployeeId,
                  fetchedFirstName,
                  fetchedLastName,
                  email: userEmail
              );
              firstName = fetchedFirstName;
              lastName = fetchedLastName;
              _logger.i('Saved employee data to remember me');
            }
          } else {
            _logger.w('No employee found in Salesforce for email: $userEmail');
          }
        } catch (e, stackTrace) {
          _logger.e('Error fetching employee from Salesforce: $e', error: e, stackTrace: stackTrace);
        }
      }

      _logger.i('Employee data initialization complete${employeeId != null ? ' with ID: $employeeId' : ' - no employee ID found'}');
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
      await SharedPrefsUtils.saveRememberMeStatus(
          employeeId!,
          firstName!,
          lastName!,
          email: userEmail
      );
    } else {
      _logger.w('Cannot save remember me data - missing required information');
    }
  }

  // Method to refresh credentials if needed
  Future<void> refreshCredentials() async {
    _logger.i('Refreshing credentials');
    await _loadCredentials();
    notifyListeners();
  }
  //
  // // Method to clear all data (useful for logout)
  // Future<void> clearAllData() async {
  //   _logger.i('Clearing all clock in/out data');
  //
  //   // Stop timers
  //   _timerLogic.stopTimers();
  //
  //   // Clear SharedPreferences data
  //   await SharedPrefsUtils.clearAllData();
  //
  //   // Reset local variables
  //   _status = ClockStatus.unmarked;
  //   inTime = null;
  //   outTime = null;
  //   _canClockIn = true;
  //   _canClockOut = false;
  //   accessToken = null;
  //   instanceUrl = null;
  //   employeeId = null;
  //   userEmail = null;
  //   firstName = null;
  //   lastName = null;
  //
  //   notifyListeners();
  //   _logger.i('All clock in/out data cleared');
  // }
}