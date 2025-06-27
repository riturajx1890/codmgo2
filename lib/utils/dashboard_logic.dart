import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:codmgo2/utils/location_logic.dart';
import 'package:codmgo2/screens/clock_in_out.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codmgo2/services/profile_service.dart';
import 'package:codmgo2/utils/clock_in_out_logic.dart';

class DashboardLogic extends ChangeNotifier {
  static final Logger _logger = Logger();
  final LocationLogic _locationLogic = LocationLogic();
  late final ClockInOutController _clockInOutController;

  // Location state
  bool _isLocationChecking = false;
  bool _isWithinRadius = false;
  String _locationMessage = '';
  double _distance = 0.0;

  // Dashboard state
  int _currentIndex = 0;
  bool _isRefreshing = false;
  String? _accessToken;
  String? _instanceUrl;

  // User data
  String _displayFirstName = '';
  String _displayLastName = '';
  String _displayEmployeeId = '';
  String _originalFirstName = '';
  String _originalLastName = '';
  String _originalEmployeeId = '';

  // Clock timing
  DateTime? _lastClockInTime;
  DateTime? _lastClockOutTime;
  static const int _minClockOutMinutes = 5;
  static const int _clockInCooldownMinutes = 1;

  // Getters
  bool get isLocationChecking => _isLocationChecking;
  bool get isWithinRadius => _isWithinRadius;
  String get locationMessage => _locationMessage;
  double get distance => _distance;
  int get currentIndex => _currentIndex;
  bool get isRefreshing => _isRefreshing;
  String? get accessToken => _accessToken;
  String? get instanceUrl => _instanceUrl;
  String get displayFirstName => _displayFirstName;
  String get displayLastName => _displayLastName;
  String get displayEmployeeId => _displayEmployeeId;
  ClockInOutController get clockInOutController => _clockInOutController;
  DateTime? get lastClockInTime => _lastClockInTime;
  DateTime? get lastClockOutTime => _lastClockOutTime;

  /// Initialize dashboard with user data
  Future<void> initializeDashboard({
    required String firstName,
    required String lastName,
    required String employeeId,
  }) async {
    _logger.i('Initializing dashboard logic');

    _originalFirstName = firstName;
    _originalLastName = lastName;
    _originalEmployeeId = employeeId;

    _clockInOutController = ClockInOutController();
    _clockInOutController.addListener(_onClockStatusChanged);

    await Future.wait([
      _loadUserData(),
      _loadAuthData(),
      checkLocationRadius(),
      _loadClockTimes(),
    ]);
  }

  /// Load user data from SharedPreferences
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _displayFirstName = prefs.getString('first_name') ?? _originalFirstName;
      _displayLastName = prefs.getString('last_name') ?? _originalLastName;
      _displayEmployeeId = prefs.getString('employee_id') ?? _originalEmployeeId;

      _logger.i('Loaded user data: $_displayFirstName $_displayLastName ($_displayEmployeeId)');
      notifyListeners();
    } catch (e) {
      _logger.e('Error loading user data: $e');
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

  /// Load and save clock times
  Future<void> _loadClockTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clockInTime = prefs.getString('last_clock_in_time');
      final clockOutTime = prefs.getString('last_clock_out_time');

      if (clockInTime != null) _lastClockInTime = DateTime.parse(clockInTime);
      if (clockOutTime != null) _lastClockOutTime = DateTime.parse(clockOutTime);

      _refreshClockTimes();
      notifyListeners();
    } catch (e) {
      _logger.e('Error loading clock times: $e');
    }
  }

  Future<void> _saveClockTime(String key, DateTime? time) async {
    if (time == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, time.toIso8601String());
    } catch (e) {
      _logger.e('Error saving clock time: $e');
    }
  }

  /// Handle clock status changes
  void _onClockStatusChanged() {
    _refreshClockTimes();
    notifyListeners();
  }

  /// Check location radius
  Future<void> checkLocationRadius() async {
    _logger.i('Starting location radius check');
    _isLocationChecking = true;
    notifyListeners();

    try {
      final result = await _locationLogic.isWithinRadius();
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

    await Future.wait([_loadUserData(), _loadClockTimes()]);
    _refreshClockTimes();
    await Future.delayed(const Duration(milliseconds: 2000));

    _isRefreshing = false;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 200), () {
      showLocationSnackbar(context);
    });
  }

  /// Navigation methods
  void onBottomNavTap(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void resetBottomNavToHome() {
    _currentIndex = 0;
    notifyListeners();
  }

  /// Clock in/out actions
  Future<void> onClockIn(BuildContext context) async {
    if (_clockInOutController.status != ClockStatus.clockedIn && canClockIn()) {
      await _clockInOutController.clockIn(context);
      _lastClockInTime = _clockInOutController.inTime;
      await _saveClockTime('last_clock_in_time', _lastClockInTime);
      notifyListeners();
    }
  }

  Future<void> onClockOut(BuildContext context) async {
    if (_clockInOutController.status != ClockStatus.clockedOut && canClockOut()) {
      await _clockInOutController.clockOut(context);
      _lastClockOutTime = _clockInOutController.outTime;
      await _saveClockTime('last_clock_out_time', _lastClockOutTime);
      notifyListeners();
    }
  }

  /// Clock validation methods
  bool canClockIn() {
    if (_lastClockInTime == null) return true;
    final minutesSinceLastClockIn = DateTime.now().difference(_lastClockInTime!).inMinutes;
    return minutesSinceLastClockIn >= _clockInCooldownMinutes;
  }

  bool canClockOut() {
    if (_lastClockInTime == null || _clockInOutController.status == ClockStatus.clockedOut) {
      return false;
    }
    final minutesSinceClockIn = DateTime.now().difference(_lastClockInTime!).inMinutes;
    return minutesSinceClockIn >= _minClockOutMinutes;
  }

  int getRemainingTimeForClockOut() {
    if (_lastClockInTime == null) return _minClockOutMinutes;
    final minutesSinceClockIn = DateTime.now().difference(_lastClockInTime!).inMinutes;
    final remainingMinutes = _minClockOutMinutes - minutesSinceClockIn;
    return remainingMinutes > 0 ? remainingMinutes : 0;
  }

  /// Refresh clock times from controller
  void _refreshClockTimes() {
    if (_clockInOutController.inTime != null) {
      _lastClockInTime = _clockInOutController.inTime;
    }
    if (_clockInOutController.outTime != null) {
      _lastClockOutTime = _clockInOutController.outTime;
    }
  }

  /// Time formatting helpers
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return "${hour.toString().padLeft(2, '0')}:$minute";
  }

  String getCurrentTime() => _formatTime(DateTime.now());

  String getCurrentDate() {
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}";
  }

  /// Location status helpers
  Color getLocationStatusColor(bool isDarkMode) {
    if (_isLocationChecking) return Colors.blueAccent;
    return _isWithinRadius ? Colors.green : Colors.red;
  }

  IconData getLocationIcon() {
    if (_isLocationChecking) return Icons.location_searching;
    return _isWithinRadius ? Icons.location_on : Icons.location_off;
  }

  String getLocationText() {
    if (_isLocationChecking) return "Checking location...";
    return _isWithinRadius ? "You are in Office reach" : "You are not in Office reach";
  }

  String getLocationHeaderText() {
    if (_isLocationChecking) return "Checking...";
    return _isWithinRadius ? "In Range" : "Out of Range";
  }

  /// Get recent activities
  List<Map<String, dynamic>> getRecentActivities() {
    List<Map<String, dynamic>> activities = [];

    if (_clockInOutController.inTime != null) {
      activities.add({
        'time': _formatTime(_clockInOutController.inTime!),
        'label': 'Clock In',
        'icon': Icons.login,
        'color': Colors.green,
      });
    }

    if (_clockInOutController.outTime != null) {
      activities.add({
        'time': _formatTime(_clockInOutController.outTime!),
        'label': 'Clock Out',
        'icon': Icons.logout,
        'color': Colors.red,
      });
    }

    // Fill with placeholder data
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

  /// Navigation handler
  Future<void> navigateToPage(BuildContext context, int index) async {
    const routes = ['', '/leave_dashboard', '/attendance_history', '/profile'];

    if (index == 0) return;

    if (index == 3 && (_accessToken == null || _instanceUrl == null)) {
      _showAuthErrorSnackbar(context);
      await _loadAuthData();
      return;
    }

    final args = (index == 1 || index == 2) ? {'employeeId': _displayEmployeeId} : null;
    await Navigator.pushNamed(context, routes[index], arguments: args);
    resetBottomNavToHome();
  }

  /// Snackbar methods
  void _showAuthErrorSnackbar(BuildContext context) {
    _showSnackbar(context, 'Authentication data not available. Please try again.', Colors.red);
  }

  void showLocationSnackbar(BuildContext context) {
    if (_isLocationChecking) {
      showUpdatingLocationSnackbar(context);
      return;
    }

    if (_isWithinRadius) {
      _showSnackbar(context, 'You are in the office radius', Colors.green);
    } else {
      final extraDistance = _distance - _locationLogic.radiusInMeters;
      _showSnackbar(context, 'You are ${extraDistance.toStringAsFixed(0)}m away from office radius', Colors.red);
    }
  }

  void showUpdatingLocationSnackbar(BuildContext context) {
    _showSnackbar(context, 'Updating location', Colors.blueAccent);
  }

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

  void _showSnackbar(BuildContext context, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Initialize location check
  Future<void> initialize() async {
    _logger.i('Initializing dashboard logic location check');
    await checkLocationRadius();
  }

  @override
  void dispose() {
    _clockInOutController.removeListener(_onClockStatusChanged);
    _clockInOutController.dispose();
    super.dispose();
  }
}