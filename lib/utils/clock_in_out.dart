import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codmgo2/services/clock_in_out_service.dart';
import 'package:codmgo2/services/salesforce_api_service.dart';
import 'package:logger/logger.dart';

enum ClockStatus { unmarked, clockedIn, clockedOut }

class ClockInOutController with ChangeNotifier {
  static final Logger _logger = Logger();

  ClockStatus _status = ClockStatus.unmarked;
  DateTime? inTime;
  DateTime? outTime;

  double officeLat = 28.55122201233124;
  double officeLng = 77.32420167559967;
  double radiusInMeters = 250;

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
      await prefs.setString('current_employee_id', empId); // Also save as current_employee_id for consistency
      employeeId = empId;

      _logger.i('Employee ID saved successfully');
    } catch (e, stackTrace) {
      _logger.e('Error saving employee ID: $e', error: e, stackTrace: stackTrace);
    }
  }

  Future<String?> _getEmployeeId() async {
    _logger.i('Getting employee ID - current employeeId: $employeeId');

    // First check if we already have employee ID loaded
    if (employeeId != null && employeeId!.isNotEmpty) {
      _logger.i('Employee ID already available: $employeeId');
      return employeeId;
    }

    // Try to load from SharedPreferences first
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

    // If no stored employee ID, try to fetch from Salesforce using email
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

  Future<void> showClockDialog(
      BuildContext context, {
        required bool isClockIn,
        double popupWidth = 600,
        double popupHeight = 400,
        double popupIconSize = 120,
        TextStyle? textStyle,
      }) async {
    _logger.i('Showing clock dialog - isClockIn: $isClockIn');

    final now = DateTime.now();
    final dateStr = "${now.day}/${now.month}/${now.year}";
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final period = now.hour >= 12 ? "PM" : "AM";
    final timeStr =
        "${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $period";

    bool isLoading = false;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[900]
                : const Color(0xFFF8F8FF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(20),
            content: StatefulBuilder(
              builder: (context, setState) {
                return SizedBox(
                  width: popupWidth,
                  height: popupHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time, size: popupIconSize),
                      const SizedBox(height: 24),
                      Text("Date: $dateStr", style: textStyle ?? const TextStyle(fontSize: 32, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text("Time: $timeStr", style: textStyle ?? const TextStyle(fontSize: 32, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: 250,
                        height: 52,
                        child: ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(Colors.blue),
                            foregroundColor: WidgetStateProperty.all(Colors.white),
                            textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 18)),
                            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                            _logger.i('Clock dialog button pressed - isClockIn: $isClockIn');
                            HapticFeedback.heavyImpact();
                            setState(() => isLoading = true);

                            final result = await _attemptClockInOut(isClockIn: isClockIn);

                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message'], style: const TextStyle(fontSize: 16, color: Colors.white)),
                                  backgroundColor: result['success'] ? Colors.green : Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }

                            setState(() => isLoading = false);
                          },
                          child: isLoading
                              ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                              ),
                              SizedBox(width: 10),
                              Text('Processing...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                            ],
                          )
                              : Text(isClockIn ? 'Clock In' : 'Clock Out', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> clockIn(BuildContext context) async {
    _logger.i('Clock in button pressed');
    HapticFeedback.heavyImpact();
    await showClockDialog(context, isClockIn: true);
  }

  Future<void> clockOut(BuildContext context) async {
    _logger.i('Clock out button pressed');
    HapticFeedback.heavyImpact();
    await showClockDialog(context, isClockIn: false);
  }

  Future<Map<String, dynamic>> _attemptClockInOut({required bool isClockIn}) async {
    _logger.i('Starting clock ${isClockIn ? "in" : "out"} attempt');

    // Check location first
    _logger.i('Checking location radius...');
    final locationResult = await _isWithinRadius();
    if (!locationResult['isInRadius']) {
      _logger.w('Location check failed: ${locationResult['message']}');
      return {
        'success': false,
        'message': locationResult['message'],
      };
    }
    _logger.i('Location check passed');

    // Load credentials
    _logger.i('Loading credentials...');
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
        message = "You are ${extraDistance.toStringAsFixed(0)}m away from office (${distance.toStringAsFixed(0)}m total)";
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

      // Clear existing employee ID to force fresh lookup
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