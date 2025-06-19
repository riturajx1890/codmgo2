import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:codmgo2/utils/location_logic.dart';
import 'package:codmgo2/screens/clock_in_out.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codmgo2/services/profile_service.dart';
import 'package:codmgo2/utils/clock_in_out_core_logic.dart';

class DashboardLogic extends ChangeNotifier {
  static final Logger _logger = Logger();
  final LocationLogic _locationLogic = LocationLogic();
  late final ClockInOutController _clockInOutController;

  // Location-related properties
  bool _isLocationChecking = false;
  bool _isWithinRadius = false;
  String _locationMessage = '';
  double _distance = 0.0;

  // Dashboard state properties
  int _currentIndex = 0;
  bool _isRefreshing = false;
  String? _accessToken;
  String? _instanceUrl;

  // User data properties
  String _displayFirstName = '';
  String _displayLastName = '';
  String _displayEmployeeId = '';

  // Original constructor parameters (fallback)
  String _originalFirstName = '';
  String _originalLastName = '';
  String _originalEmployeeId = '';

  // Getters for location
  bool get isLocationChecking => _isLocationChecking;
  bool get isWithinRadius => _isWithinRadius;
  String get locationMessage => _locationMessage;
  double get distance => _distance;

  // Getters for dashboard state
  int get currentIndex => _currentIndex;
  bool get isRefreshing => _isRefreshing;
  String? get accessToken => _accessToken;
  String? get instanceUrl => _instanceUrl;

  // Getters for user data
  String get displayFirstName => _displayFirstName;
  String get displayLastName => _displayLastName;
  String get displayEmployeeId => _displayEmployeeId;

  // Getter for clock controller
  ClockInOutController get clockInOutController => _clockInOutController;

  /// Initialize the dashboard logic with user data
  Future<void> initializeDashboard({
    required String firstName,
    required String lastName,
    required String employeeId,
  }) async {
    _logger.i('Initializing dashboard logic');

    // Store original parameters as fallback
    _originalFirstName = firstName;
    _originalLastName = lastName;
    _originalEmployeeId = employeeId;

    // Initialize clock controller
    _clockInOutController = ClockInOutController();
    _clockInOutController.addListener(_onClockStatusChanged);

    // Load user data and initialize location check
    await Future.wait([
      _loadUserData(),
      _loadAuthData(),
      checkLocationRadius(),
    ]);
  }

  /// Load user data from SharedPreferences
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get data from SharedPreferences first, fallback to original parameters
      final firstName = prefs.getString('first_name') ?? _originalFirstName;
      final lastName = prefs.getString('last_name') ?? _originalLastName;
      final employeeId = prefs.getString('employee_id') ?? _originalEmployeeId;

      _displayFirstName = firstName;
      _displayLastName = lastName;
      _displayEmployeeId = employeeId;

      _logger.i('Loaded user data: $firstName $lastName ($employeeId)');
      notifyListeners();
    } catch (e) {
      _logger.e('Error loading user data: $e');
      // Fallback to original parameters if SharedPreferences fails
      _displayFirstName = _originalFirstName;
      _displayLastName = _originalLastName;
      _displayEmployeeId = _originalEmployeeId;
      notifyListeners();
    }
  }

  /// Load authentication data
  Future<void> _loadAuthData() async {
    try {
      final authData = await ProfileService.getAuthData();
      if (authData != null) {
        _accessToken = authData['access_token'];
        _instanceUrl = authData['instance_url'];
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Error loading auth data: $e');
    }
  }

  /// Handle clock status changes
  void _onClockStatusChanged() {
    notifyListeners();
  }

  /// Check location radius and update state
  Future<void> checkLocationRadius() async {
    _logger.i('Starting location radius check');

    // Set checking state
    _isLocationChecking = true;
    notifyListeners();

    try {
      // Get location result
      final result = await _locationLogic.isWithinRadius();

      // Update state with results
      _isWithinRadius = result['isInRadius'] ?? false;
      _locationMessage = result['message'] ?? 'Unknown location status';
      _distance = result['distance'] ?? 0.0;

      _logger.i('Location check completed: $_locationMessage');

    } catch (e, stackTrace) {
      _logger.e('Error checking location radius: $e', error: e, stackTrace: stackTrace);
      _isWithinRadius = false;
      _locationMessage = 'Unable to get location. Please try again.';
      _distance = 0.0;
    } finally {
      // Reset checking state
      _isLocationChecking = false;
      notifyListeners();
    }
  }

  /// Handle refresh action
  Future<void> onRefresh(BuildContext context) async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    notifyListeners();

    showUpdatingLocationSnackbar(context);
    await checkLocationRadius();

    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email') ?? 'default@example.com';
    await _clockInOutController.initializeEmployeeData(userEmail);

    // Reload user data to ensure it's up to date
    await _loadUserData();

    await Future.delayed(const Duration(milliseconds: 2000));

    _isRefreshing = false;
    notifyListeners();

    // Show location status after refresh
    Future.delayed(const Duration(milliseconds: 200), () {
      showLocationSnackbar(context);
    });
  }

  /// Handle bottom navigation tap
  void onBottomNavTap(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  /// Reset bottom navigation to home
  void resetBottomNavToHome() {
    _currentIndex = 0;
    notifyListeners();
  }

  /// Handle clock in action
  Future<void> onClockIn(BuildContext context) async {
    if (_clockInOutController.status != ClockStatus.clockedIn) {
      await _clockInOutController.clockIn(context);
    }
  }

  /// Handle clock out action
  Future<void> onClockOut(BuildContext context) async {
    if (_clockInOutController.status != ClockStatus.clockedOut) {
      await _clockInOutController.clockOut(context);
    }
  }

  /// Get current time formatted
  String getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    return "${hour.toString().padLeft(2, '0')}:$minute";
  }

  /// Get current date formatted
  String getCurrentDate() {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return "${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}";
  }

  /// Get location status color
  Color getLocationStatusColor(bool isDarkMode) {
    if (_isLocationChecking) {
      return Colors.blueAccent;
    } else if (_isWithinRadius) {
      return Colors.green;
    } else {
      return Colors.red;
    }
  }

  /// Get location icon
  IconData getLocationIcon() {
    if (_isLocationChecking) {
      return Icons.location_searching;
    } else if (_isWithinRadius) {
      return Icons.location_on;
    } else {
      return Icons.location_off;
    }
  }

  /// Get location text
  String getLocationText() {
    if (_isLocationChecking) {
      return "Checking location...";
    } else if (_isWithinRadius) {
      return "You are in Office reach";
    } else {
      return "You are not in Office reach";
    }
  }

  /// Get location status for header
  String getLocationHeaderText() {
    if (_isLocationChecking) {
      return "Checking...";
    } else if (_isWithinRadius) {
      return "In Range";
    } else {
      return "Out of Range";
    }
  }

  /// Get recent activities
  List<Map<String, dynamic>> getRecentActivities() {
    List<Map<String, dynamic>> activities = [];

    if (_clockInOutController.inTime != null) {
      final inTime = _clockInOutController.inTime!;
      final hour = inTime.hour > 12 ? inTime.hour - 12 : (inTime.hour == 0 ? 12 : inTime.hour);
      activities.add({
        'time': "${hour.toString().padLeft(2, '0')}:${inTime.minute.toString().padLeft(2, '0')}",
        'label': 'Clock In',
        'icon': Icons.login,
        'color': Colors.green,
      });
    }

    if (_clockInOutController.outTime != null) {
      final outTime = _clockInOutController.outTime!;
      final hour = outTime.hour > 12 ? outTime.hour - 12 : (outTime.hour == 0 ? 12 : outTime.hour);
      activities.add({
        'time': "${hour.toString().padLeft(2, '0')}:${outTime.minute.toString().padLeft(2, '0')}",
        'label': 'Clock Out',
        'icon': Icons.logout,
        'color': Colors.red,
      });
    }

    // Add working hours if both times are available
    if (_clockInOutController.inTime != null && _clockInOutController.outTime != null) {
      final workingDuration = _clockInOutController.outTime!.difference(_clockInOutController.inTime!);
      final hours = workingDuration.inHours;
      final minutes = workingDuration.inMinutes % 60;
      activities.add({
        'time': "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}",
        'label': 'Working Hrs',
        'icon': Icons.schedule,
        'color': Colors.blue,
      });
    }

    // Fill with placeholder if not enough activities
    while (activities.length < 3) {
      activities.add({
        'time': '--:--',
        'label': 'No Data',
        'icon': Icons.schedule,
        'color': Colors.grey,
      });
    }

    return activities.take(3).toList();
  }

  /// Handle navigation to different pages
  Future<void> navigateToPage(BuildContext context, int index) async {
    switch (index) {
      case 0:
      // Home - no navigation needed
        break;
      case 1:
      // Navigate to Leave Dashboard
        await Navigator.pushNamed(
          context,
          '/leave_dashboard',
          arguments: {'employeeId': _displayEmployeeId},
        );
        resetBottomNavToHome();
        break;
      case 2:
      // Navigate to Attendance History
        await Navigator.pushNamed(
          context,
          '/attendance_history',
          arguments: {'employeeId': _displayEmployeeId},
        );
        resetBottomNavToHome();
        break;
      case 3:
      // Navigate to Profile
        if (_accessToken == null || _instanceUrl == null) {
          _showAuthErrorSnackbar(context);
          await _loadAuthData();
          return;
        }
        await Navigator.pushNamed(context, '/profile');
        resetBottomNavToHome();
        break;
    }
  }

  /// Show authentication error snackbar
  void _showAuthErrorSnackbar(BuildContext context) {
    _showSnackbar(
      context,
      message: 'Authentication data not available. Please try again.',
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  /// Show location status snackbar
  void showLocationSnackbar(BuildContext context) {
    if (_isLocationChecking) {
      // Show updating location snackbar
      showUpdatingLocationSnackbar(context);
      return;
    }

    if (_isWithinRadius) {
      // Show success snackbar
      _showSnackbar(
        context,
        message: 'You are in the office radius',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } else {
      // Show error snackbar with distance
      final extraDistance = _distance - _locationLogic.radiusInMeters;
      _showSnackbar(
        context,
        message: 'You are ${extraDistance.toStringAsFixed(0)}m away from office radius',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  /// Show updating location snackbar (public method)
  void showUpdatingLocationSnackbar(BuildContext context) {
    _showSnackbar(
      context,
      message: 'Updating location',
      backgroundColor: Colors.blueAccent,
      textColor: Colors.white,
    );
  }

  /// Handle location icon tap
  void onLocationIconTap(BuildContext context) {
    if (_isLocationChecking) {
      showLocationSnackbar(context);
    } else {
      showUpdatingLocationSnackbar(context);

      checkLocationRadius().then((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          showLocationSnackbar(context);
        });
      });
    }
  }

  /// Private method to show snackbar
  void _showSnackbar(
      BuildContext context, {
        required String message,
        required Color backgroundColor,
        required Color textColor,
      }) {
    // Remove any existing snackbar
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    // Show new snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Initialize location check (call this on dashboard init)
  Future<void> initialize() async {
    _logger.i('Initializing dashboard logic location check');
    await checkLocationRadius();
  }

  /// Dispose method to clean up resources
  @override
  void dispose() {
    _clockInOutController.removeListener(_onClockStatusChanged);
    _clockInOutController.dispose();
    super.dispose();
  }
}