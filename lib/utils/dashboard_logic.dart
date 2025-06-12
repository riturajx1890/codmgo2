import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:codmgo2/services/salesforce_api_service.dart'; // Assuming this path

class DashboardLogic with ChangeNotifier {
  static final Logger _logger = Logger();

  // Location properties
  bool _isWithinRadius = false;
  bool _isLocationChecking = true;
  String _locationMessage = '';
  double _currentDistance = 0.0;

  // Office coordinates
  double officeLat = 28.55122201233124;
  double officeLng = 77.32420167559967;
  double radiusInMeters = 250;

  // Employee data properties
  String? accessToken;
  String? instanceUrl;
  String? employeeId;
  String? userEmail;

  // Getters for location
  bool get isWithinRadius => _isWithinRadius;
  bool get isLocationChecking => _isLocationChecking;
  String get locationMessage => _locationMessage;
  double get currentDistance => _currentDistance;

  // Getters for employee data (if needed for UI, otherwise internal)
  String? get employeeIdValue => employeeId;
  String? get userEmailValue => userEmail;


  DashboardLogic() {
    _logger.i('DashboardLogic initialized');
    _initializeData();
  }

  Future<void> _initializeData() async {
    _logger.i('Starting initial data load for DashboardLogic');
    await _loadCredentials();
    await _getEmployeeId(); // Fetch employee ID after credentials are loaded
    await checkLocationRadius(); // Check location after essential data is loaded
  }

  @override
  void dispose() {
    _logger.i('DashboardLogic disposed');
    super.dispose();
  }

  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  /// Loads Salesforce access token, instance URL, and user email from SharedPreferences.
  Future<void> _loadCredentials() async {
    _logger.i('Loading credentials from SharedPreferences');
    try {
      final prefs = await SharedPreferences.getInstance();
      accessToken = prefs.getString('access_token');
      instanceUrl = prefs.getString('instance_url');
      userEmail = prefs.getString('user_email');
      employeeId = prefs.getString('employee_id') ?? prefs.getString('current_employee_id');

      _logger.i('Credentials loaded - accessToken: ${accessToken != null ? "present" : "null"}, instanceUrl: ${instanceUrl != null ? "present" : "null"}, userEmail: $userEmail, employeeId: $employeeId');
    } catch (e, stackTrace) {
      _logger.e('Error loading credentials: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Saves the provided employee ID to SharedPreferences.
  Future<void> _saveEmployeeId(String empId) async {
    _logger.i('Saving employee ID: $empId');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employee_id', empId);
      await prefs.setString('current_employee_id', empId); // Keep both for redundancy
      employeeId = empId;
      _logger.i('Employee ID saved successfully');
    } catch (e, stackTrace) {
      _logger.e('Error saving employee ID: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Retrieves the employee ID from SharedPreferences or by fetching it from Salesforce.
  /// Prioritizes existing `employeeId`, then SharedPreferences, then Salesforce API.
  Future<String?> _getEmployeeId() async {
    _logger.i('Getting employee ID - current employeeId: $employeeId');

    // 1. If employeeId is already available in the class, return it.
    if (employeeId != null && employeeId!.isNotEmpty) {
      _logger.i('Employee ID already available: $employeeId');
      return employeeId;
    }

    // 2. Try to get it from SharedPreferences.
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

    // 3. If not found, attempt to fetch from Salesforce using email.
    if (userEmail != null && userEmail!.isNotEmpty && accessToken != null && instanceUrl != null) {
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
          await _saveEmployeeId(fetchedEmployeeId); // Save for future use
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

  /// Checks if the user's current location is within the defined office radius.
  /// Updates `_isWithinRadius`, `_currentDistance`, `_locationMessage`, and `_isLocationChecking`.
  Future<void> checkLocationRadius() async {
    _logger.i('Checking if user is within office radius');

    setState(() {
      _isLocationChecking = true;
    });

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

      setState(() {
        _isWithinRadius = isInRadius;
        _currentDistance = distance;
        _isLocationChecking = false;

        if (isInRadius) {
          _locationMessage = "Within office radius";
          _logger.i('User is within office radius');
        } else {
          double extraDistance = distance - radiusInMeters;
          _locationMessage = "You are ${extraDistance.toStringAsFixed(0)}m away from office";
          _logger.w('User is outside office radius by ${extraDistance.toStringAsFixed(0)}m');
        }
      });
    } catch (e, stackTrace) {
      _logger.e('Error getting location: $e', error: e, stackTrace: stackTrace);
      setState(() {
        _isWithinRadius = false;
        _isLocationChecking = false;
        _locationMessage = 'Unable to get location. Please enable location services and try again.';
      });
    }
  }

  /// Initializes employee data by saving the provided email and then fetching the employee ID.
  Future<void> initializeEmployeeData(String email) async {
    _logger.i('Initializing employee data for email: $email');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      userEmail = email;

      // Clear existing employeeId and remove from SharedPreferences to force re-fetch
      employeeId = null;
      await prefs.remove('employee_id');
      await prefs.remove('current_employee_id');

      _logger.i('Employee data initialized, getting employee ID...');
      await _getEmployeeId(); // This will now fetch the new employee ID based on the provided email

      _logger.i('Employee data initialization complete');
      notifyListeners(); // Notify listeners if UI depends on employeeId directly after initialization
    } catch (e, stackTrace) {
      _logger.e('Error initializing employee data: $e', error: e, stackTrace: stackTrace);
    }
  }
}