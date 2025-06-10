import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codmgo2/utils/clock_in_out_logic.dart';

class ClockInOutController with ChangeNotifier {
  final ClockInOutLogic _logic = ClockInOutLogic();

  ClockInOutController() {
    // Listen to logic changes and notify UI
    _logic.addListener(() {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _logic.dispose();
    super.dispose();
  }

  // Expose getters from logic
  ClockStatus get status => _logic.status;
  String get statusText => _logic.statusText;
  DateTime? get inTime => _logic.inTime;
  DateTime? get outTime => _logic.outTime;

  // Public methods that delegate to logic
  Future<void> initializeEmployeeData(String email) async {
    await _logic.initializeEmployeeData(email);
  }

  Future<void> showClockDialog(
      BuildContext context, {
        required bool isClockIn,
        double popupWidth = 600,
        double popupHeight = 400,
        double popupIconSize = 120,
        TextStyle? textStyle,
      }) async {
    // Check if already performed action today
    // COMMENTED OUT TO ALLOW MULTIPLE CLOCK INS/OUTS
//

    if (isClockIn) {
      final alreadyClockedIn = await _logic.checkIfAlreadyClockedInToday();
      if (alreadyClockedIn) {
        if (context.mounted) {
          _showSnackBar(
            context,
            'You have already clocked in today!',
            Colors.orange,
          );
        }
        return;
      }
    } else {
      final alreadyClockedOut = await _logic.checkIfAlreadyClockedOutToday();
      if (alreadyClockedOut) {
        if (context.mounted) {
          _showSnackBar(
            context,
            'You have already clocked out today!',
            Colors.orange,
          );
        }
        return;
      }

      // For clock out, also check if clocked in today
      final clockedInToday = await _logic.checkIfAlreadyClockedInToday();
      if (!clockedInToday) {
        if (context.mounted) {
          _showSnackBar(
            context,
            'You need to clock in first!',
            Colors.red,
          );
        }
        return;
      }
    }

//

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
                      Text(
                        "Date: $dateStr",
                        style: textStyle ?? const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Time: $timeStr",
                        style: textStyle ?? const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: 250,
                        height: 52,
                        child: ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(Colors.blue),
                            foregroundColor: WidgetStateProperty.all(Colors.white),
                            textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 18)),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                            HapticFeedback.heavyImpact();
                            setState(() => isLoading = true);

                            final result = await _logic.attemptClockInOut(isClockIn: isClockIn);

                            if (context.mounted) {
                              Navigator.of(context).pop();
                              _showSnackBar(
                                context,
                                result['message'],
                                result['success'] ? Colors.green : Colors.red,
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
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                          ),
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
    HapticFeedback.heavyImpact();
    await showClockDialog(context, isClockIn: true);
  }

  Future<void> clockOut(BuildContext context) async {
    HapticFeedback.heavyImpact();
    await showClockDialog(context, isClockIn: false);
  }

  void _showSnackBar(BuildContext context, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}