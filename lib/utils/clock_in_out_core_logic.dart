import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codmgo2/services/clock_in_out_service.dart';
import 'package:codmgo2/services/salesforce_api_service.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:codmgo2/utils/location_logic.dart'; // Import the new LocationLogic class

enum ClockStatus { unmarked, clockedIn, clockedOut }

class ClockInOutLogic with ChangeNotifier {
  static final Logger _logger = Logger();
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  ClockStatus _status = ClockStatus.unmarked;
  DateTime? inTime;
  DateTime? outTime;
  Timer? _notificationTimer;
  Timer? _autoClockOutTimer;
  Timer? _eighteenHourTimer;
  int _notificationCount = 0;
  static const int _maxNotifications = 3;

  bool _canClockIn = true;
  bool _canClockOut = false;

  String? accessToken;
  String? instanceUrl;
  String? employeeId;
  String? userEmail;

  final LocationLogic _locationLogic = LocationLogic(); // Instance of LocationLogic

  ClockStatus get status => _status;
  bool get canClockIn => _canClockIn;
  bool get canClockOut => _canClockOut;

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
    _initializeNotifications();
    _loadTodayStatus();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _autoClockOutTimer?.cancel();
    _eighteenHourTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  // Add this method to your ClockInOutService class

  static Future<List<Map<String, dynamic>>> getAttendanceHistory(
      String accessToken,
      String instanceUrl,
      String employeeId, {
        int limit = 10,
      }) async {
    final Logger logger = Logger();

    try {
      // Calculate date range for the last 30 days to ensure we get enough records
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
            // _startEighteenHourTimer(); // Comment out this line
          } else {
            // Already clocked in today
            _status = ClockStatus.clockedIn;
            inTime = DateTime.parse(todayAttendance['In_Time__c']).toLocal();
            _canClockIn = false;
            _canClockOut = true;
            _logger.i('Found active clock-in for today');
            _startNotificationTimer();
            _startAutoClockOutTimer();
            // _startEighteenHourTimer(); // Comment out this line
          }
          notifyListeners();
        } else {
          // No attendance today
          _canClockIn = true;
          _canClockOut = false;
          _logger.i('No attendance found for today');
        }
      } catch (e, stackTrace) {
        _logger.e('Error loading today\'s status: $e', error: e, stackTrace: stackTrace);
      }
    }
  }

  void _startEighteenHourTimer() {
    if (inTime == null) return;

    _eighteenHourTimer?.cancel();

    final now = DateTime.now();
    final clockInTime = inTime!;
    final elapsed = now.difference(clockInTime);
    const eighteenHourDelay = Duration(hours: 18);

    Duration initialDelay;
    if (elapsed >= eighteenHourDelay) {
      // If already past 18 hours, enable clock in immediately
      initialDelay = Duration.zero;
    } else {
      // Time until 18 hours complete
      initialDelay = eighteenHourDelay - elapsed;
    }

    _logger.i('Starting 18-hour timer - will enable clock in after: ${initialDelay.inHours} hours ${initialDelay.inMinutes % 60} minutes');

    _eighteenHourTimer = Timer(initialDelay, () {
      _logger.i('18 hours completed - enabling clock in');
      _canClockIn = true;
      notifyListeners();
    });
  }

  void _startNotificationTimer() {
    if (inTime == null) return;

    _notificationTimer?.cancel();
    _notificationCount = 0;

    final now = DateTime.now();
    final clockInTime = inTime!;
    final elapsed = now.difference(clockInTime);

    // Calculate time until first notification (9 hours 15 minutes)
    const firstNotificationDelay = Duration(hours: 9, minutes: 15);

    Duration initialDelay;
    if (elapsed >= firstNotificationDelay) {
      // If already past 9:15, calculate which notification should be next
      final minutesPast915 = elapsed.inMinutes - firstNotificationDelay.inMinutes;
      _notificationCount = (minutesPast915 / 45).floor() + 1;

      // Don't exceed max notifications
      if (_notificationCount >= _maxNotifications) {
        _logger.i('Maximum notifications already sent');
        return;
      }

      // Time until next notification
      final nextNotificationMinutes = (_notificationCount * 45) - minutesPast915;
      initialDelay = Duration(minutes: nextNotificationMinutes);
    } else {
      // Time until first notification
      initialDelay = firstNotificationDelay - elapsed;
    }

    _logger.i('Starting notification timer - first notification in: ${initialDelay.inMinutes} minutes');

    _notificationTimer = Timer(initialDelay, () {
      _sendNotification();
      _schedulePeriodicNotifications();
    });
  }

  void _schedulePeriodicNotifications() {
    _notificationTimer = Timer.periodic(const Duration(minutes: 45), (timer) {
      if (_notificationCount >= _maxNotifications || _status != ClockStatus.clockedIn) {
        timer.cancel();
        return;
      }
      _sendNotification();
    });
  }

  void _startAutoClockOutTimer() {
    if (inTime == null) return;

    _autoClockOutTimer?.cancel();

    final now = DateTime.now();
    final clockInTime = inTime!;
    final elapsed = now.difference(clockInTime);
    const autoClockOutDelay = Duration(hours: 12);

    Duration initialDelay;
    if (elapsed >= autoClockOutDelay) {
      // If already past 12 hours, auto clock out immediately
      initialDelay = Duration.zero;
    } else {
      // Time until auto clock out
      initialDelay = autoClockOutDelay - elapsed;
    }

    _logger.i('Starting auto clock out timer - will auto clock out in: ${initialDelay.inHours} hours ${initialDelay.inMinutes % 60} minutes');

    _autoClockOutTimer = Timer(initialDelay, () {
      _performAutoClockOut();
    });
  }

  Future<void> _performAutoClockOut() async {
    if (_status != ClockStatus.clockedIn) {
      _logger.i('Auto clock out cancelled - user not clocked in');
      return;
    }

    _logger.i('Performing automatic clock out after 12 hours');

    try {
      await _loadCredentials();
      final currentEmployeeId = await _getEmployeeId();

      if (currentEmployeeId != null && accessToken != null && instanceUrl != null) {
        final todayAttendance = await ClockInOutService.getTodayAttendance(
          accessToken!,
          instanceUrl!,
          currentEmployeeId,
        );

        if (todayAttendance != null && todayAttendance['Id'] != null && todayAttendance['Out_Time__c'] == null) {
          // For auto clock out, we don't save the out_time (it will be blank)
          _logger.i('Auto clock out - marking status as clocked out but not saving out_time');

          _status = ClockStatus.clockedOut;
          outTime = null; // Keep out time as null for auto clock out
          _canClockIn = false; // Will be enabled after 18 hours
          _canClockOut = false;
          _notificationTimer?.cancel();
          _autoClockOutTimer?.cancel();
          notifyListeners();

          // Send notification about auto clock out
          await _sendAutoClockOutNotification();

          _logger.i('Auto clock out completed - out_time kept blank');
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error during auto clock out: $e', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _sendAutoClockOutNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'auto_clockout_channel',
      'Auto Clock Out Notifications',
      channelDescription: 'Notifications for automatic clock out',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      9999, // Unique ID for auto clock out notification
      'Auto Clock Out',
      'You have been automatically clocked out after 12 hours of work.',
      notificationDetails,
    );
  }

  void _sendNotification() async {
    if (_status != ClockStatus.clockedIn || inTime == null || _notificationCount >= _maxNotifications) {
      _notificationTimer?.cancel();
      return;
    }

    _notificationCount++;
    final hoursWorked = DateTime.now().difference(inTime!).inHours;
    final minutesWorked = DateTime.now().difference(inTime!).inMinutes;

    const androidDetails = AndroidNotificationDetails(
      'overtime_channel',
      'Overtime Notifications',
      channelDescription: 'Notifications for overtime work hours',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String title = 'Overtime Alert!';
    String body = 'You\'ve been clocked in for $hoursWorked hour : $minutesWorked minutes.\n Consider clocking out.';

    await _notificationsPlugin.show(
      _notificationCount,
      title,
      body,
      notificationDetails,
    );

    _logger.i('Sent overtime notification #$_notificationCount after ${(minutesWorked / 60).toStringAsFixed(1)} hours');
  }

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
          _startNotificationTimer();
          _startAutoClockOutTimer();
          // _startEighteenHourTimer(); // Comment out this line
          notifyListeners();

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
            _notificationTimer?.cancel();
            _autoClockOutTimer?.cancel();
            // _eighteenHourTimer?.cancel(); // You might also want to cancel the timer here if it's running
            notifyListeners();

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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      userEmail = email;

      employeeId = null;
      await prefs.remove('employee_id');
      await prefs.remove('current_employee_id');

      _logger.i('Employee data initialized, getting employee ID...');
      await _getEmployeeId();

      _logger.i('Employee data initialization complete');
    } catch (e, stackTrace) {
      _logger.e('Error initializing employee data: $e', error: e, stackTrace: stackTrace);
    }
  }
}