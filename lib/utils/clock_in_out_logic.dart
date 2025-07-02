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

  // Core state
  ClockStatus _status = ClockStatus.unmarked;
  DateTime? inTime;
  DateTime? outTime;
  bool _canClockIn = true;
  bool _canClockOut = false;

  // Credentials
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
      case ClockStatus.clockedIn: return "Clocked In";
      case ClockStatus.clockedOut: return "Clocked Out";
      default: return "Unmarked";
    }
  }

  // Timer helper getters
  bool get hasActiveTimers => _timerLogic.hasActiveTimers;
  bool get isTimerClockIn => _timerLogic.isClockIn;
  DateTime? get timerClockInTime => _timerLogic.clockInTime;
  int get notificationCount => _timerLogic.notificationCount;

  ClockInOutLogic() {
    _timerLogic = TimerNotificationLogic(onStatusUpdate: updateClockStatus);
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

  // Private helper methods
  Future<void> _loadCredentials() async {
    _logger.i('Loading credentials from SharedPrefsUtils');

    try {
      // Try to get complete credentials with employee ID first
      final credentialsWithId = await SharedPrefsUtils.getValidCredentialsWithEmployeeId();

      if (credentialsWithId != null) {
        accessToken = credentialsWithId['access_token'];
        instanceUrl = credentialsWithId['instance_url'];
        employeeId = credentialsWithId['employee_id'];
        _logger.i('Complete credentials loaded - employeeId: $employeeId');
      } else {
        // Fallback: load credentials and employee data separately
        final salesforceCredentials = await SharedPrefsUtils.getSalesforceCredentials();
        if (salesforceCredentials != null) {
          accessToken = salesforceCredentials['access_token'];
          instanceUrl = salesforceCredentials['instance_url'];
        }
        employeeId = await SharedPrefsUtils.getCurrentEmployeeId();
      }

      // Load user data from remember me
      final rememberMeData = await SharedPrefsUtils.checkRememberMeStatus();
      if (rememberMeData != null) {
        firstName = rememberMeData['first_name'];
        lastName = rememberMeData['last_name'];
        userEmail = rememberMeData['email'];
        // Use employee ID from remember me if not already set
        employeeId ??= rememberMeData['employee_id'];
        _logger.i('User data loaded from remember me');
      }

      _logger.i('Credentials loaded - accessToken: ${accessToken != null ? "present" : "null"}, instanceUrl: ${instanceUrl != null ? "present" : "null"}, employeeId: $employeeId');
    } catch (e, stackTrace) {
      _logger.e('Error loading credentials: $e', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _loadTodayStatus() async {
    _logger.i('Loading today\'s status on controller initialization');
    await _loadCredentials();

    if (!_hasValidCredentials()) return;

    try {
      final todayAttendance = await ClockInOutService.getTodayAttendance(
        accessToken!,
        instanceUrl!,
        employeeId!,
      );

      if (todayAttendance != null) {
        _processExistingAttendance(todayAttendance);
      } else {
        _resetToUnmarked();
      }
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error loading today\'s status: $e', error: e, stackTrace: stackTrace);
    }
  }

  void _processExistingAttendance(Map<String, dynamic> attendance) {
    if (attendance['Out_Time__c'] != null) {
      // Already clocked out today
      _status = ClockStatus.clockedOut;
      inTime = DateTime.parse(attendance['In_Time__c']).toLocal();
      outTime = DateTime.parse(attendance['Out_Time__c']).toLocal();
      _canClockIn = false;
      _canClockOut = false;
      _timerLogic.stopTimers();
      _logger.i('Found completed attendance for today');
    } else {
      // Already clocked in today
      _status = ClockStatus.clockedIn;
      inTime = DateTime.parse(attendance['In_Time__c']).toLocal();
      _canClockIn = false;
      _canClockOut = true;
      _timerLogic.resumeTimers(inTime!);
      _logger.i('Found active clock-in for today');
    }
  }

  void _resetToUnmarked() {
    _canClockIn = true;
    _canClockOut = false;
    _timerLogic.stopTimers();
    _logger.i('No attendance found for today');
  }

  bool _hasValidCredentials() {
    return employeeId != null && accessToken != null && instanceUrl != null;
  }

  Future<void> _saveRememberMeIfNeeded() async {
    if (_hasCompleteUserData()) {
      await SharedPrefsUtils.saveRememberMeStatus(
        employeeId!,
        firstName!,
        lastName!,
        email: userEmail,
      );
      _logger.i('Updated remember me status');
    }
  }

  bool _hasCompleteUserData() {
    return employeeId != null &&
        firstName != null &&
        lastName != null &&
        employeeId!.isNotEmpty &&
        firstName!.isNotEmpty &&
        lastName!.isNotEmpty;
  }

  Future<Map<String, dynamic>> _processClockIn() async {
    _logger.i('Processing clock in...');

    final recordId = await ClockInOutService.clockIn(
      accessToken!,
      instanceUrl!,
      employeeId!,
      DateTime.now().toUtc(),
    );

    if (recordId != null) {
      _status = ClockStatus.clockedIn;
      inTime = DateTime.now();
      outTime = null;
      _canClockIn = false;
      _canClockOut = true;

      await _saveRememberMeIfNeeded();
      _timerLogic.startTimers(inTime!);

      _logger.i('Clock in successful - record ID: $recordId');
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
  }

  Future<Map<String, dynamic>> _processClockOut() async {
    _logger.i('Processing clock out...');

    final todayAttendance = await ClockInOutService.getTodayAttendance(
      accessToken!,
      instanceUrl!,
      employeeId!,
    );

    if (todayAttendance?.containsKey('Id') != true) {
      _logger.w('No active clock-in record found for today');
      return {
        'success': false,
        'message': 'No active clock-in record found for today.',
      };
    }

    final success = await ClockInOutService.clockOut(
      accessToken!,
      instanceUrl!,
      todayAttendance?['Id'],
      DateTime.now().toUtc(),
    );

    if (success) {
      _status = ClockStatus.clockedOut;
      outTime = DateTime.now();
      _canClockIn = false;
      _canClockOut = false;

      await _saveRememberMeIfNeeded();
      _timerLogic.stopTimers();

      _logger.i('Clock out successful');
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
  }

  // Public methods
  Future<bool> checkIfAlreadyClockedInToday() async {
    await _loadCredentials();
    if (!_hasValidCredentials()) return false;

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
    if (!_hasValidCredentials()) return false;

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

    // Validate clock out permission
    if (!isClockIn && !_canClockOut) {
      _logger.w('Clock out attempted but not allowed');
      return {
        'success': false,
        'message': 'You need to clock in first.',
      };
    }

    // Load and validate credentials
    await _loadCredentials();

    if (!_hasValidCredentials()) {
      final missingCredential = accessToken == null
          ? 'Salesforce access token'
          : instanceUrl == null
          ? 'Salesforce instance URL'
          : 'Employee record';

      _logger.e('Missing credential: $missingCredential');
      return {
        'success': false,
        'message': '$missingCredential not found. Please ${accessToken == null || instanceUrl == null ? 'login again' : 'contact administrator'}.',
      };
    }

    try {
      final result = isClockIn ? await _processClockIn() : await _processClockOut();
      notifyListeners();
      return result;
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
      if (email != null) userEmail = email;
      await _loadCredentials();

      // Fetch employee from Salesforce if needed
      if (employeeId == null &&
          userEmail != null &&
          userEmail!.isNotEmpty &&
          accessToken != null &&
          instanceUrl != null) {
        await _fetchEmployeeFromSalesforce();
      }

      _logger.i('Employee data initialization complete${employeeId != null ? ' with ID: $employeeId' : ' - no employee ID found'}');
    } catch (e, stackTrace) {
      _logger.e('Error initializing employee data: $e', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _fetchEmployeeFromSalesforce() async {
    _logger.i('Fetching employee from Salesforce using email: $userEmail');

    try {
      final employee = await SalesforceApiService.getEmployeeByEmail(
        accessToken!,
        instanceUrl!,
        userEmail!,
      );

      if (employee?.containsKey('Id') == true) {
        employeeId = employee?['Id'].toString();
        firstName = employee?['First_Name__c']?.toString() ?? '';
        lastName = employee?['Last_Name__c']?.toString() ?? '';

        _logger.i('Employee fetched: $employeeId, $firstName $lastName');

        // Save employee data
        await SharedPrefsUtils.saveEmployeeData(
          employeeId!,
          firstName!,
          lastName!,
          email: userEmail,
        );

        // Set remember me if we have complete user data
        if (firstName!.isNotEmpty && lastName!.isNotEmpty) {
          await SharedPrefsUtils.saveRememberMeStatus(
            employeeId!,
            firstName!,
            lastName!,
            email: userEmail,
          );
          _logger.i('Saved employee data to remember me');
        }
      } else {
        _logger.w('No employee found in Salesforce for email: $userEmail');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching employee from Salesforce: $e', error: e, stackTrace: stackTrace);
    }
  }

  // Timer-related methods
  Duration? getRemainingAutoClockOutTime() => _timerLogic.getRemainingAutoClockOutTime();
  Duration? getRemainingNotificationTime() => _timerLogic.getRemainingNotificationTime();
  Duration? getRemaining18HourTime() => _timerLogic.getRemaining18HourTime();
  Future<void> sendTestNotification() => _timerLogic.sendTestNotification();

  // Status update methods
  void updateClockStatus({
    required ClockStatus status,
    DateTime? clockInTime,
    DateTime? clockOutTime,
    bool? canClockIn,
    bool? canClockOut,
  }) {
    _logger.i('Updating clock status from external source - status: $status');

    _status = status;
    if (clockInTime != null) inTime = clockInTime;
    if (clockOutTime != null) outTime = clockOutTime;
    if (canClockIn != null) _canClockIn = canClockIn;
    if (canClockOut != null) _canClockOut = canClockOut;
    notifyListeners();
  }

  void enableClockIn() {
    _logger.i('Enabling clock in from external trigger');
    _canClockIn = true;
    notifyListeners();
  }

  void disableClockOut() {
    _logger.i('Disabling clock out from external trigger');
    _canClockOut = false;
    notifyListeners();
  }

  // Utility methods
  Future<void> clearRememberMe() async {
    _logger.i('Clearing remember me data');
    await SharedPrefsUtils.clearRememberMeData();
    firstName = null;
    lastName = null;
  }

  Future<void> saveRememberMe() async {
    if (_hasCompleteUserData()) {
      _logger.i('Manually saving remember me data');
      await SharedPrefsUtils.saveRememberMeStatus(
        employeeId!,
        firstName!,
        lastName!,
        email: userEmail,
      );
    } else {
      _logger.w('Cannot save remember me data - missing required information');
    }
  }

  Future<void> refreshCredentials() async {
    _logger.i('Refreshing credentials');
    await _loadCredentials();
    notifyListeners();
  }
}