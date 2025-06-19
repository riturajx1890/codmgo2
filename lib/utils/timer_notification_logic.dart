import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codmgo2/services/clock_in_out_service.dart';

import 'clock_in_out_logic.dart';

class TimerNotificationLogic with ChangeNotifier {
  static final Logger _logger = Logger();
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Timer? _notificationTimer;
  Timer? _autoClockOutTimer;
  int _notificationCount = 0;
  static const int _maxNotifications = 3;

  DateTime? _clockInTime;
  bool _isClockIn = false;

  // Credentials for API calls
  String? _accessToken;
  String? _instanceUrl;
  String? _employeeId;

  // Callback function to update main clock logic
  Function({
  required ClockStatus status,
  DateTime? clockInTime,
  DateTime? clockOutTime,
  bool? canClockIn,
  bool? canClockOut,
  })? onStatusUpdate;

  TimerNotificationLogic({this.onStatusUpdate}) {
    _initializeNotifications();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _autoClockOutTimer?.cancel();
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

  Future<void> _loadCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _instanceUrl = prefs.getString('instance_url');
      _employeeId = prefs.getString('employee_id') ?? prefs.getString('current_employee_id');
    } catch (e, stackTrace) {
      _logger.e('Error loading credentials: $e', error: e, stackTrace: stackTrace);
    }
  }

  // Start all timers when user clocks in
  void startTimers(DateTime clockInTime) {
    _clockInTime = clockInTime;
    _isClockIn = true;

    _logger.i('Starting all timers for clock in at: $clockInTime');

    _startNotificationTimer();
    _startAutoClockOutTimer();
  }

  // Stop all timers when user clocks out or when needed
  void stopTimers() {
    _logger.i('Stopping all timers');

    _notificationTimer?.cancel();
    _autoClockOutTimer?.cancel();

    _isClockIn = false;
    _notificationCount = 0;
  }

  // Resume timers with existing clock in time (for app restart scenarios)
  void resumeTimers(DateTime existingClockInTime) {
    _clockInTime = existingClockInTime;
    _isClockIn = true;

    _logger.i('Resuming timers with existing clock in time: $existingClockInTime');

    _startNotificationTimer();
    _startAutoClockOutTimer();
    // Don't restart 18-hour timer for existing sessions as it affects next day clock-in
  }



  void _startNotificationTimer() {
    if (_clockInTime == null) return;

    _notificationTimer?.cancel();
    _notificationCount = 0;

    final now = DateTime.now();
    final clockInTime = _clockInTime!;
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
      if (_notificationCount >= _maxNotifications || !_isClockIn) {
        timer.cancel();
        return;
      }
      _sendNotification();
    });
  }

  void _startAutoClockOutTimer() {
    if (_clockInTime == null) return;

    _autoClockOutTimer?.cancel();

    final now = DateTime.now();
    final clockInTime = _clockInTime!;
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
    if (!_isClockIn) {
      _logger.i('Auto clock out cancelled - user not clocked in');
      return;
    }

    _logger.i('Performing automatic clock out after 12 hours');

    try {
      await _loadCredentials();

      if (_employeeId != null && _accessToken != null && _instanceUrl != null) {
        final todayAttendance = await ClockInOutService.getTodayAttendance(
          _accessToken!,
          _instanceUrl!,
          _employeeId!,
        );

        if (todayAttendance != null && todayAttendance['Id'] != null && todayAttendance['Out_Time__c'] == null) {
          // For auto clock out, we don't save the out_time (it will be blank)
          _logger.i('Auto clock out - marking status as clocked out but not saving out_time');

          // Update the main clock logic
          onStatusUpdate?.call(
            status: ClockStatus.clockedOut,
            clockOutTime: null, // Keep out time as null for auto clock out
            canClockIn: false, // Will be enabled after 18 hours
            canClockOut: false,
          );

          // Stop timers except 18-hour timer
          _notificationTimer?.cancel();
          _autoClockOutTimer?.cancel();
          _isClockIn = false;

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
    if (!_isClockIn || _clockInTime == null || _notificationCount >= _maxNotifications) {
      _notificationTimer?.cancel();
      return;
    }

    _notificationCount++;
    final hoursWorked = DateTime.now().difference(_clockInTime!).inHours;
    final minutesWorked = DateTime.now().difference(_clockInTime!).inMinutes;

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

  // Public methods to check timer status
  bool get hasActiveTimers => _notificationTimer?.isActive == true ||
      _autoClockOutTimer?.isActive == true;
  bool get isClockIn => _isClockIn;

  DateTime? get clockInTime => _clockInTime;

  int get notificationCount => _notificationCount;

  // Method to manually trigger a notification (for testing)
  Future<void> sendTestNotification() async {
    _sendNotification();
  }

  // Method to get remaining time for auto clock out
  Duration? getRemainingAutoClockOutTime() {
    if (_clockInTime == null || !_isClockIn) return null;

    const autoClockOutDelay = Duration(hours: 12);
    final elapsed = DateTime.now().difference(_clockInTime!);
    final remaining = autoClockOutDelay - elapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  // Method to get remaining time for next notification
  Duration? getRemainingNotificationTime() {
    if (_clockInTime == null || !_isClockIn || _notificationCount >= _maxNotifications) return null;

    final elapsed = DateTime.now().difference(_clockInTime!);
    final firstNotificationDelay = Duration(hours: 9, minutes: 15);

    if (_notificationCount == 0) {
      // Time until first notification
      final remaining = firstNotificationDelay - elapsed;
      return remaining.isNegative ? Duration.zero : remaining;
    } else {
      // Time until next periodic notification
      final nextNotificationTime = firstNotificationDelay + Duration(minutes: _notificationCount * 45);
      final remaining = nextNotificationTime - elapsed;
      return remaining.isNegative ? Duration.zero : remaining;
    }
  }

  // Method to get remaining time for 18-hour timer
  Duration? getRemaining18HourTime() {
    if (_clockInTime == null) return null;

    const eighteenHourDelay = Duration(hours: 18);
    final elapsed = DateTime.now().difference(_clockInTime!);
    final remaining = eighteenHourDelay - elapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }
}