import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codmgo2/services/clock_in_out_service.dart';
import 'package:codmgo2/services/salesforce_api_service.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum ClockStatus { unmarked, clockedIn, clockedOut }

class ClockInOutLogic with ChangeNotifier {
  static final Logger _logger = Logger();
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  ClockStatus _status = ClockStatus.unmarked;
  DateTime? inTime;
  DateTime? outTime;
  Timer? _notificationTimer;
  int _notificationCount = 0;

  double officeLat = 28.55122201233124;
  double officeLng = 77.32420167559967;
  double radiusInMeters = 25;

  String? accessToken;
  String? instanceUrl;
  String? employeeId;
  String? userEmail;

  ClockStatus get status => _status;

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
            inTime = DateTime.parse(todayAttendance['In_Time__c']);
            outTime = DateTime.parse(todayAttendance['Out_Time__c']);
            _logger.i('Found completed attendance for today');
          } else {
            // Already clocked in today
            _status = ClockStatus.clockedIn;
            inTime = DateTime.parse(todayAttendance['In_Time__c']);
            _logger.i('Found active clock-in for today');
            _startNotificationTimer();
          }
          notifyListeners();
        }
      } catch (e, stackTrace) {
        _logger.e('Error loading today\'s status: $e', error: e, stackTrace: stackTrace);
      }
    }
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
      _sendNotification();
    });
  }

  void _sendNotification() async {
    if (_status != ClockStatus.clockedIn || inTime == null) {
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
    String body = 'You\'ve been clocked in for ${hoursWorked}+ hours (${(minutesWorked / 60).toStringAsFixed(1)} hours). Consider clocking out.';

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

      return todayAttendance != null;
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

  Future<Map<String, dynamic>> attemptClockInOut({required bool isClockIn}) async {
    _logger.i('Starting clock ${isClockIn ? "in" : "out"} attempt');

    final locationResult = await _isWithinRadius();
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
          DateTime.now(),
        );

        if (recordId != null) {
          _logger.i('Clock in successful - record ID: $recordId');
          _status = ClockStatus.clockedIn;
          inTime = DateTime.now();
          outTime = null;
          _startNotificationTimer();
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
            DateTime.now(),
          );

          if (success) {
            _logger.i('Clock out successful');
            _status = ClockStatus.clockedOut;
            outTime = DateTime.now();
            _notificationTimer?.cancel();
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

  Future<Map<String, dynamic>> _isWithinRadius() async {
    _logger.i('Checking if user is within office radius');

    try {
      _logger.i('Getting current position...');
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 30),
        ),
      );

      _logger.i('Current position: lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}m');

      double distance = Geolocator.distanceBetween(
        officeLat,
        officeLng,
        position.latitude,
        position.longitude,
      );

      _logger.i('Distance from office: ${distance.toStringAsFixed(2)}m (radius limit: ${radiusInMeters}m)');

      bool isInRadius = distance <= radiusInMeters;

      String message;
      if (isInRadius) {
        message = "Within office radius";
        _logger.i('User is within office radius');
      } else {
        double extraDistance = distance - radiusInMeters;
        message = "You are ${extraDistance.toStringAsFixed(0)}m away from office";
        _logger.w('User is outside office radius by ${extraDistance.toStringAsFixed(0)}m');
      }

      return {
        'isInRadius': isInRadius,
        'message': message,
        'distance': distance,
        'accuracy': position.accuracy,
      };
    } catch (e, stackTrace) {
      _logger.e('Error getting location: $e', error: e, stackTrace: stackTrace);
      return {
        'isInRadius': false,
        'message': 'Unable to get location. Please try again.',
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