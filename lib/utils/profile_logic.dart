import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codmgo2/services/profile_service.dart';
import 'package:codmgo2/services/salesforce_api_service.dart';
import 'package:logger/logger.dart';

class ProfileLogic with ChangeNotifier {
  static final Logger _logger = Logger();

  Map<String, dynamic>? _profileData;
  bool _isLoading = false;
  String? _errorMessage;

  String? accessToken;
  String? instanceUrl;
  String? employeeId;
  String? userEmail;

  Map<String, dynamic>? get profileData => _profileData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ProfileLogic() {
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    _logger.i('Loading credentials from SharedPreferences');

    try {
      final prefs = await SharedPreferences.getInstance();
      accessToken = prefs.getString('access_token');
      instanceUrl = prefs.getString('instance_url');
      employeeId = prefs.getString('employee_id') ?? prefs.getString('current_employee_id');
      userEmail = prefs.getString('user_email');

      _logger.i('Credentials loaded - employeeId: $employeeId, userEmail: $userEmail');
    } catch (e) {
      _logger.e('Error loading credentials: $e');
    }
  }

  Future<void> _saveEmployeeId(String empId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employee_id', empId);
      await prefs.setString('current_employee_id', empId);
      employeeId = empId;
    } catch (e) {
      _logger.e('Error saving employee ID: $e');
    }
  }

  Future<String?> _getEmployeeId() async {
    if (employeeId != null && employeeId!.isNotEmpty) {
      return employeeId;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedEmployeeId = prefs.getString('employee_id') ?? prefs.getString('current_employee_id');

      if (storedEmployeeId != null && storedEmployeeId.isNotEmpty) {
        employeeId = storedEmployeeId;
        return employeeId;
      }
    } catch (e) {
      _logger.e('Error loading employee ID from SharedPreferences: $e');
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
          await _saveEmployeeId(fetchedEmployeeId);
          return fetchedEmployeeId;
        }
      } catch (e) {
        _logger.e('Error fetching employee from Salesforce: $e');
      }
    }

    return null;
  }

  Future<void> loadProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadCredentials();

      if (accessToken == null || instanceUrl == null) {
        throw Exception('Authentication data not found. Please login again.');
      }

      final currentEmployeeId = await _getEmployeeId();
      if (currentEmployeeId == null || currentEmployeeId.isEmpty) {
        throw Exception('Employee record not found. Please contact administrator.');
      }

      _logger.i('Loading profile for employee ID: $currentEmployeeId');

      final profile = await ProfileService.getEmployeeProfileWithAuth(
        accessToken!,
        instanceUrl!,
        currentEmployeeId,
      );

      if (profile != null) {
        _profileData = profile;
        _logger.i('Profile loaded successfully');
      } else {
        throw Exception('Failed to load profile data');
      }
    } catch (e) {
      _errorMessage = e.toString();
      _logger.e('Error loading profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> updatedData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadCredentials();

      if (accessToken == null || instanceUrl == null) {
        throw Exception('Authentication data not found. Please login again.');
      }

      final currentEmployeeId = await _getEmployeeId();
      if (currentEmployeeId == null || currentEmployeeId.isEmpty) {
        throw Exception('Employee record not found. Please contact administrator.');
      }

      final success = await ProfileService.updateEmployeeProfileWithAuth(
        accessToken!,
        instanceUrl!,
        currentEmployeeId,
        updatedData,
      );

      if (success) {
        // Reload profile data after successful update
        await loadProfile();
        return true;
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      _errorMessage = e.toString();
      _logger.e('Error updating profile: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> searchEmployees(String searchTerm) async {
    try {
      await _loadCredentials();

      if (accessToken == null || instanceUrl == null) {
        return [];
      }

      final employees = await ProfileService.searchEmployeesWithAuth(
        accessToken!,
        instanceUrl!,
        searchTerm,
      );

      return employees ?? [];
    } catch (e) {
      _logger.e('Error searching employees: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllEmployees() async {
    try {
      await _loadCredentials();

      if (accessToken == null || instanceUrl == null) {
        return [];
      }

      final employees = await ProfileService.getAllEmployeesWithAuth(
        accessToken!,
        instanceUrl!,
      );

      return employees ?? [];
    } catch (e) {
      _logger.e('Error getting all employees: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getEmployeesByDepartment(String department) async {
    try {
      await _loadCredentials();

      if (accessToken == null || instanceUrl == null) {
        return [];
      }

      final employees = await ProfileService.getEmployeesByDepartmentWithAuth(
        accessToken!,
        instanceUrl!,
        department,
      );

      return employees ?? [];
    } catch (e) {
      _logger.e('Error getting employees by department: $e');
      return [];
    }
  }

  Future<String?> createEmployee(Map<String, dynamic> employeeData) async {
    try {
      await _loadCredentials();

      if (accessToken == null || instanceUrl == null) {
        return null;
      }

      final newEmployeeId = await ProfileService.createEmployeeWithAuth(
        accessToken!,
        instanceUrl!,
        employeeData,
      );

      return newEmployeeId;
    } catch (e) {
      _logger.e('Error creating employee: $e');
      return null;
    }
  }

  Future<bool> validateEmployeeExists(String employeeId) async {
    try {
      await _loadCredentials();

      if (accessToken == null || instanceUrl == null) {
        return false;
      }

      final profile = await ProfileService.getEmployeeProfileWithAuth(
        accessToken!,
        instanceUrl!,
        employeeId,
      );

      return profile != null;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getEmployeeBasicInfo(String employeeId) async {
    try {
      await _loadCredentials();

      if (accessToken == null || instanceUrl == null) {
        return null;
      }

      final basicInfo = await ProfileService.getEmployeeBasicInfoWithAuth(
        accessToken!,
        instanceUrl!,
        employeeId,
      );

      return basicInfo;
    } catch (e) {
      return null;
    }
  }

  Future<void> initializeEmployeeData(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      userEmail = email;

      // Clear existing employee ID
      employeeId = null;
      await prefs.remove('employee_id');
      await prefs.remove('current_employee_id');

      // Get employee ID using the email
      await _getEmployeeId();
    } catch (e) {
      _logger.e('Error initializing employee data: $e');
    }
  }

  void clearProfile() {
    _profileData = null;
    _errorMessage = null;
    notifyListeners();
  }
}