import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:codmgo2/utils/clock_in_out_logic.dart';
import 'package:animations/animations.dart';
import 'package:logger/logger.dart';

class ClockInOutController with ChangeNotifier {
  static final Logger _logger = Logger();
  final ClockInOutLogic _logic = ClockInOutLogic();

  ClockInOutController() {
    _logger.i('ClockInOutController initialized');
    // Listen to logic changes and notify UI
    _logic.addListener(() {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _logger.i('ClockInOutController disposing');
    _logic.dispose();
    super.dispose();
  }

  // Expose getters from logic
  ClockStatus get status => _logic.status;
  String get statusText => _logic.statusText;
  DateTime? get inTime => _logic.inTime;
  DateTime? get outTime => _logic.outTime;
  bool get canClockIn => _logic.canClockIn;
  bool get canClockOut => _logic.canClockOut;

  // Public methods that delegate to logic
  Future<void> initializeEmployeeData(String email) async {
    _logger.i('Initializing employee data for email: $email');
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

    _logger.i('Showing clock dialog - isClockIn: $isClockIn');

    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AttendanceProcessingPage(
              logic: _logic,
              isClockIn: isClockIn,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> clockIn(BuildContext context) async {
    _logger.i('Clock in requested');
    HapticFeedback.heavyImpact();
    await showClockDialog(context, isClockIn: true);
  }

  Future<void> clockOut(BuildContext context) async {
    _logger.i('Clock out requested');
    HapticFeedback.heavyImpact();
    await showClockDialog(context, isClockIn: false);
  }
}

class AttendanceProcessingPage extends StatefulWidget {
  final ClockInOutLogic logic;
  final bool isClockIn;

  const AttendanceProcessingPage({
    super.key,
    required this.logic,
    required this.isClockIn,
  });

  @override
  State<AttendanceProcessingPage> createState() => _AttendanceProcessingPageState();
}

class _AttendanceProcessingPageState extends State<AttendanceProcessingPage>
    with TickerProviderStateMixin {

  static final Logger _logger = Logger();

  late AnimationController _processingController;
  late AnimationController _successController;
  late AnimationController _tickController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _tickScaleAnimation;

  bool _isProcessing = true;
  bool _isCompleted = false;
  bool _hasError = false;
  String _resultMessage = '';
  String _currentDate = '';
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _logger.i('AttendanceProcessingPage initialized - isClockIn: ${widget.isClockIn}');
    _initializeAnimations();
    _updateDateTime();
    _processAttendance();
  }

  void _initializeAnimations() {
    _logger.d('Initializing animations');

    _processingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _tickController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _processingController,
      curve: Curves.linear,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    ));

    _tickScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _tickController,
      curve: Curves.elasticOut,
    ));

    _processingController.repeat();
  }

  void _updateDateTime() {
    final now = DateTime.now();
    _currentDate = "${now.day}/${now.month}/${now.year}";
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final period = now.hour >= 12 ? "PM" : "AM";
    _currentTime = "${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $period";

    _logger.d('DateTime updated - Date: $_currentDate, Time: $_currentTime');
  }

  Future<void> _processAttendance() async {
    _logger.i('Starting attendance processing - isClockIn: ${widget.isClockIn}');

    try {
      // Start the API call immediately but don't wait for it
      final apiCallFuture = widget.logic.attemptClockInOut(isClockIn: widget.isClockIn);

      // Always wait for exactly 1500ms to show processing animation
      await Future.delayed(const Duration(milliseconds: 2700));
      _logger.d('Processing animation completed after 1500ms');

      // Try to get the API result (it might be completed by now)
      try {
        final result = await apiCallFuture.timeout(const Duration(milliseconds: 100));
        _logger.i('API call completed: ${result['success']} - ${result['message']}');

        if (result['success']) {
          _handleSuccess('Attendance Marked Successfully', widget.isClockIn ? 'Successfully Clocked In' : 'Successfully Clocked Out');
        } else {
          _handleError(result['message'] ?? 'Attendance marking failed');
        }
      } catch (e) {
        // API call not completed yet, assume success for UX
        _logger.w('API call still in progress, showing success for UX: $e');
        _handleSuccess('Attendance Marked Successfully', widget.isClockIn ? 'Successfully Clocked In' : 'Successfully Clocked Out');

        // Continue API call in background
        apiCallFuture.then((result) {
          _logger.i('Background API call completed: ${result['success']} - ${result['message']}');
        }).catchError((e, stackTrace) {
          _logger.e('Background API call error: $e', error: e, stackTrace: stackTrace);
        });
      }

    } catch (e, stackTrace) {
      _logger.e('Error during attendance processing: $e', error: e, stackTrace: stackTrace);
      _handleError('An unexpected error occurred');
    }
  }

  void _handleSuccess(String title, String message) {
    _logger.i('Handling success: $title - $message');
    HapticFeedback.heavyImpact();

    setState(() {
      _isProcessing = false;
      _isCompleted = true;
      _resultMessage = message;
    });

    _processingController.stop();
    _successController.forward();

    Future.delayed(const Duration(milliseconds: 200), () {
      _tickController.forward();
    });
  }

  void _handleError(String message) {
    _logger.w('Handling error: $message');
    HapticFeedback.heavyImpact();

    setState(() {
      _isProcessing = false;
      _hasError = true;
      _resultMessage = message;
    });

    _processingController.stop();
    _successController.forward();
  }

  @override
  void dispose() {
    _logger.d('AttendanceProcessingPage disposing');
    _processingController.dispose();
    _successController.dispose();
    _tickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),

                // Date and Time Display
                Text(
                  "Date: $_currentDate",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Time: $_currentTime",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 60),

                // Processing/Success Animation - Centered
                Center(
                  child: SizedBox(
                    height: 150,
                    width: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Processing spinner
                        if (_isProcessing)
                          AnimatedBuilder(
                            animation: _rotationAnimation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _rotationAnimation.value * 2 * 3.14159,
                                child: Container(
                                  height: 120,
                                  width: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.blueAccent,
                                      width: 4,
                                    ),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        // Success/Error circle
                        if (!_isProcessing)
                          AnimatedBuilder(
                            animation: _scaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Container(
                                  height: 120,
                                  width: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _hasError ? Colors.red : Colors.blueAccent,
                                  ),
                                  child: _hasError
                                      ? const Icon(
                                    Icons.close,
                                    size: 60,
                                    color: Colors.white,
                                  )
                                      : AnimatedBuilder(
                                    animation: _tickScaleAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _tickScaleAnimation.value,
                                        child: const Icon(
                                          Icons.check,
                                          size: 60,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Status Text
                if (_isProcessing)
                  Text(
                    widget.isClockIn ? 'Clocking In...' : 'Clocking Out...',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  Column(
                    children: [
                      Text(
                        _hasError ? 'Attendance Marking Failed!' : 'Attendance Marked Successfully!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: _hasError ? Colors.red : Colors.blueAccent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _resultMessage,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: textColor.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                const Spacer(),

                // Done Button (only shown when completed)
                if (!_isProcessing)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasError ? Colors.red : Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () {
                        _logger.i('Done button pressed, closing attendance processing page');
                        HapticFeedback.heavyImpact();
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}