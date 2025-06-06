import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codmgo2/services/clock_in_out_service.dart'; // Add your service import here

enum ClockStatus { unmarked, clockedIn, clockedOut }

class ClockInOutController with ChangeNotifier {
  ClockStatus _status = ClockStatus.unmarked;
  DateTime? inTime;
  DateTime? outTime;

  double officeLat = 28.55122201233124;
  double officeLng = 77.32420167559967;
  double radiusInMeters = 250;

  // Salesforce credentials
  String? accessToken;
  String? instanceUrl;
  String? employeeId;

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

  // Load credentials from SharedPreferences
  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('access_token');
    instanceUrl = prefs.getString('instance_url');
    employeeId = prefs.getString('employee_id');
  }

  Future<void> showClockDialog(
      BuildContext context, {
        required bool isClockIn,
        double popupWidth = 600,
        double popupHeight = 400,
        double popupIconSize = 120,
        TextStyle? textStyle,
      }) async {
    final now = DateTime.now();
    final dateStr = "${now.day}/${now.month}/${now.year}";
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final period = now.hour >= 12 ? "PM" : "AM";
    final timeStr = "${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $period";

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
                      Text(
                        "Date: $dateStr",
                        style: textStyle ??
                            const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Time: $timeStr",
                        style: textStyle ??
                            const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                          width: 250,
                          height: 52,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                if (states.contains(WidgetState.disabled)) {
                                  return Colors.blue; // Keep blue when disabled
                                }
                                return Colors.blue;
                              }),
                              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                if (states.contains(WidgetState.disabled)) {
                                  return Colors.white; // Keep white when disabled
                                }
                                return Colors.white;
                              }),
                              textStyle: WidgetStateProperty.all<TextStyle>(
                                const TextStyle(fontSize: 18),
                              ),
                              shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              padding: WidgetStateProperty.all<EdgeInsets>(
                                const EdgeInsets.symmetric(horizontal: 16),
                              ),
                            ),

                            onPressed: isLoading
                                ? null
                                : () async {
                              HapticFeedback.heavyImpact();
                              setState(() => isLoading = true);
                              final result = isClockIn
                                  ? await _attemptClockInOut(isClockIn: true)
                                  : await _attemptClockInOut(isClockIn: false);

                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result['message'],
                                      style: const TextStyle(fontSize: 16, color: Colors.white),
                                    ),
                                    backgroundColor: result['success'] ? Colors.green : Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Processing...',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                                ),
                              ],
                            )
                                : Text(
                              isClockIn ? 'Clock In' : 'Clock Out',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                          )
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
    HapticFeedback.heavyImpact();
    await showClockDialog(context, isClockIn: true);
  }

  Future<void> clockOut(BuildContext context) async {
    HapticFeedback.heavyImpact();
    await showClockDialog(context, isClockIn: false);
  }

  Future<Map<String, dynamic>> _attemptClockInOut({required bool isClockIn}) async {
    // Check location first
    final locationResult = await _isWithinRadius();
    if (!locationResult['isInRadius']) {
      return {
        'success': false,
        'message': locationResult['message'],
      };
    }

    // Load credentials
    await _loadCredentials();

    if (accessToken == null || instanceUrl == null || employeeId == null) {
      return {
        'success': false,
        'message': 'Authentication credentials not found. Please login again.'
      };
    }

    try {
      if (isClockIn) {
        // Clock In
        final recordId = await ClockInOutService.clockIn(
          accessToken!,
          instanceUrl!,
          employeeId!,
          DateTime.now(),
        );

        if (recordId != null) {
          _status = ClockStatus.clockedIn;
          inTime = DateTime.now();
          notifyListeners();

          return {
            'success': true,
            'message': 'Successfully clocked in!',
            'recordId': recordId
          };
        } else {
          return {
            'success': false,
            'message': 'Failed to clock in. Please try again.'
          };
        }
      } else {
        // Clock Out - First get today's attendance record
        final todayAttendance = await ClockInOutService.getTodayAttendance(
          accessToken!,
          instanceUrl!,
          employeeId!,
        );

        if (todayAttendance != null && todayAttendance['Id'] != null) {
          final success = await ClockInOutService.clockOut(
            accessToken!,
            instanceUrl!,
            todayAttendance['Id'],
            DateTime.now(),
          );

          if (success) {
            _status = ClockStatus.clockedOut;
            outTime = DateTime.now();
            notifyListeners();

            return {
              'success': true,
              'message': 'Successfully clocked out!'
            };
          } else {
            return {
              'success': false,
              'message': 'Failed to clock out. Please try again.'
            };
          }
        } else {
          return {
            'success': false,
            'message': 'No active clock-in record found for today.'
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}'
      };
    }
  }

  Future<Map<String, dynamic>> _isWithinRadius() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 30),
        ),
      );

      double distance = Geolocator.distanceBetween(
        officeLat,
        officeLng,
        position.latitude,
        position.longitude,
      );

      bool isInRadius = distance <= radiusInMeters;

      String message;
      if (isInRadius) {
        message = "Within office radius";
      } else {
        double extraDistance = distance - radiusInMeters;
        message =
        "You are ${extraDistance.toStringAsFixed(0)}m away from office (${distance.toStringAsFixed(0)}m total)";
      }

      return {
        'isInRadius': isInRadius,
        'message': message,
        'distance': distance,
        'accuracy': position.accuracy,
      };
    } catch (e) {
      print('Location error: $e');
      return {
        'isInRadius': false,
        'message': 'Unable to get location. Please try again.',
      };
    }
  }
}