import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static const String _apiVersion = 'v52.0';
  static final Logger _logger = Logger();

  /// Gets access token and instance URL from SharedPreferences
  static Future<Map<String, String>?> getAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final instanceUrl = prefs.getString('instance_url');

      if (accessToken == null || instanceUrl == null) {
        _logger.e('Auth data missing from SharedPreferences');
        return null;
      }

      final normalizedUrl = instanceUrl.endsWith('/')
          ? instanceUrl.substring(0, instanceUrl.length - 1)
          : instanceUrl;

      return {
        'access_token': accessToken,
        'instance_url': normalizedUrl,
      };
    } catch (e) {
      _logger.e('Error getting auth data: $e');
      return null;
    }
  }

  /// Fetches employee profile data by Employee ID
  static Future<Map<String, dynamic>?> getEmployeeProfile(String employeeId) async {
    if (employeeId.isEmpty) {
      _logger.e('Employee ID is empty or null');
      return null;
    }

    final authData = await getAuthData();
    if (authData == null) {
      _logger.e('Authentication data not available');
      return null;
    }

    return await _getEmployeeProfileWithAuth(
      authData['access_token']!,
      authData['instance_url']!,
      employeeId,
    );
  }

  /// Fetches employee profile with provided auth data
  static Future<Map<String, dynamic>?> getEmployeeProfileWithAuth(
      String accessToken,
      String instanceUrl,
      String employeeId,
      ) async {
    return await _getEmployeeProfileWithAuth(accessToken, instanceUrl, employeeId);
  }

  /// Internal method to fetch employee profile
  static Future<Map<String, dynamic>?> _getEmployeeProfileWithAuth(
      String accessToken,
      String instanceUrl,
      String employeeId,
      ) async {
    if (employeeId.isEmpty) {
      _logger.e('Employee ID is empty');
      return null;
    }

    final query = "SELECT Id, Name, First_Name__c, Last_Name__c, Employee_Code__c, Performance_Flag__c, Phone__c, Email__c, Bank_Name__c, IFSC_Code__c, Bank_Account_Number__c, Aadhar_Number__c, PAN_Card__c, Date_of_Birth__c, Work_Location__c, Joining_Date__c, Reporting_Manager_Formula__c, Annual_Review_Date__c, Department__c FROM Employee__c WHERE Id = '$employeeId'";

    final encodedQuery = Uri.encodeComponent(query);
    final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

    try {
      _logger.i('Making API request for employee ID: $employeeId');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      _logger.i('Response received - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is Map && data.containsKey('records')) {
          final records = data['records'] as List?;

          if (records != null && records.isNotEmpty) {
            final profileRecord = records.first as Map<String, dynamic>;
            _logger.i('Employee profile found for ID: $employeeId');
            return profileRecord;
          } else {
            _logger.w('No employee found with ID: $employeeId');
            return null;
          }
        } else {
          _logger.e('Response does not contain records field');
          return null;
        }
      } else if (response.statusCode == 401) {
        _logger.e('Unauthorized - token may be expired');
        return null;
      } else {
        _logger.e('Request failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _logger.e('Exception occurred during API call: $e');
      return null;
    }
  }

  /// Updates employee profile data
  static Future<bool> updateEmployeeProfile(
      String employeeId,
      Map<String, dynamic> profileData,
      ) async {
    final authData = await getAuthData();
    if (authData == null) {
      return false;
    }

    return await _updateEmployeeProfileWithAuth(
      authData['access_token']!,
      authData['instance_url']!,
      employeeId,
      profileData,
    );
  }

  /// Updates employee profile with provided auth data
  static Future<bool> updateEmployeeProfileWithAuth(
      String accessToken,
      String instanceUrl,
      String employeeId,
      Map<String, dynamic> profileData,
      ) async {
    return await _updateEmployeeProfileWithAuth(accessToken, instanceUrl, employeeId, profileData);
  }

  /// Internal method to update employee profile
  static Future<bool> _updateEmployeeProfileWithAuth(
      String accessToken,
      String instanceUrl,
      String employeeId,
      Map<String, dynamic> profileData,
      ) async {
    if (employeeId.isEmpty || profileData.isEmpty) {
      return false;
    }

    final url = '$instanceUrl/services/data/$_apiVersion/sobjects/Employee__c/$employeeId';

    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(profileData),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 204) {
        _logger.i('Profile update successful');
        return true;
      } else {
        _logger.e('Update failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('Error updating employee profile: $e');
      return false;
    }
  }

  /// Gets all employees
  static Future<List<Map<String, dynamic>>?> getAllEmployees() async {
    final authData = await getAuthData();
    if (authData == null) {
      return null;
    }

    return await _getAllEmployeesWithAuth(
      authData['access_token']!,
      authData['instance_url']!,
    );
  }

  /// Gets all employees with provided auth data
  static Future<List<Map<String, dynamic>>?> getAllEmployeesWithAuth(
      String accessToken,
      String instanceUrl,
      ) async {
    return await _getAllEmployeesWithAuth(accessToken, instanceUrl);
  }

  /// Internal method to get all employees
  static Future<List<Map<String, dynamic>>?> _getAllEmployeesWithAuth(
      String accessToken,
      String instanceUrl,
      ) async {
    final query = "SELECT Id, Name, First_Name__c, Last_Name__c, Email__c FROM Employee__c";
    final encodedQuery = Uri.encodeComponent(query);
    final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List;
        return records.cast<Map<String, dynamic>>();
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Creates a new employee record
  static Future<String?> createEmployee(Map<String, dynamic> employeeData) async {
    final authData = await getAuthData();
    if (authData == null) {
      return null;
    }

    return await _createEmployeeWithAuth(
      authData['access_token']!,
      authData['instance_url']!,
      employeeData,
    );
  }

  /// Creates employee with provided auth data
  static Future<String?> createEmployeeWithAuth(
      String accessToken,
      String instanceUrl,
      Map<String, dynamic> employeeData,
      ) async {
    return await _createEmployeeWithAuth(accessToken, instanceUrl, employeeData);
  }

  /// Internal method to create employee
  static Future<String?> _createEmployeeWithAuth(
      String accessToken,
      String instanceUrl,
      Map<String, dynamic> employeeData,
      ) async {
    final url = '$instanceUrl/services/data/$_apiVersion/sobjects/Employee__c';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(employeeData),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final newId = data['id'];
        return newId;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Searches employees by name, email, or employee code
  static Future<List<Map<String, dynamic>>?> searchEmployees(String searchTerm) async {
    final authData = await getAuthData();
    if (authData == null) {
      return null;
    }

    return await _searchEmployeesWithAuth(
      authData['access_token']!,
      authData['instance_url']!,
      searchTerm,
    );
  }

  /// Searches employees with provided auth data
  static Future<List<Map<String, dynamic>>?> searchEmployeesWithAuth(
      String accessToken,
      String instanceUrl,
      String searchTerm,
      ) async {
    return await _searchEmployeesWithAuth(accessToken, instanceUrl, searchTerm);
  }

  /// Internal method to search employees
  static Future<List<Map<String, dynamic>>?> _searchEmployeesWithAuth(
      String accessToken,
      String instanceUrl,
      String searchTerm,
      ) async {
    if (searchTerm.isEmpty) {
      return null;
    }

    final escapedSearchTerm = searchTerm.replaceAll("'", "\\'");
    final query = "SELECT Id, Name, First_Name__c, Last_Name__c, Employee_Code__c, Email__c, Department__c FROM Employee__c WHERE First_Name__c LIKE '%$escapedSearchTerm%' OR Last_Name__c LIKE '%$escapedSearchTerm%' OR Email__c LIKE '%$escapedSearchTerm%' OR Employee_Code__c LIKE '%$escapedSearchTerm%' ORDER BY Last_Name__c, First_Name__c";

    final encodedQuery = Uri.encodeComponent(query);
    final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List;
        return records.cast<Map<String, dynamic>>();
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Gets employees by department
  static Future<List<Map<String, dynamic>>?> getEmployeesByDepartment(String department) async {
    final authData = await getAuthData();
    if (authData == null) {
      return null;
    }

    return await _getEmployeesByDepartmentWithAuth(
      authData['access_token']!,
      authData['instance_url']!,
      department,
    );
  }

  /// Gets employees by department with provided auth data
  static Future<List<Map<String, dynamic>>?> getEmployeesByDepartmentWithAuth(
      String accessToken,
      String instanceUrl,
      String department,
      ) async {
    return await _getEmployeesByDepartmentWithAuth(accessToken, instanceUrl, department);
  }

  /// Internal method to get employees by department
  static Future<List<Map<String, dynamic>>?> _getEmployeesByDepartmentWithAuth(
      String accessToken,
      String instanceUrl,
      String department,
      ) async {
    if (department.isEmpty) {
      return null;
    }

    final escapedDepartment = department.replaceAll("'", "\\'");
    final query = "SELECT Id, Name, First_Name__c, Last_Name__c, Employee_Code__c, Email__c, Department__c FROM Employee__c WHERE Department__c = '$escapedDepartment' ORDER BY Last_Name__c, First_Name__c";

    final encodedQuery = Uri.encodeComponent(query);
    final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List;
        return records.cast<Map<String, dynamic>>();
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Validates employee exists
  static Future<bool> validateEmployeeExists(String employeeId) async {
    final profile = await getEmployeeProfile(employeeId);
    return profile != null;
  }

  /// Gets employee basic info (for quick lookups)
  static Future<Map<String, dynamic>?> getEmployeeBasicInfo(String employeeId) async {
    final authData = await getAuthData();
    if (authData == null) {
      return null;
    }

    return await getEmployeeBasicInfoWithAuth(
      authData['access_token']!,
      authData['instance_url']!,
      employeeId,
    );
  }

  /// Gets employee basic info with provided auth data
  static Future<Map<String, dynamic>?> getEmployeeBasicInfoWithAuth(
      String accessToken,
      String instanceUrl,
      String employeeId,
      ) async {
    final query = "SELECT Id, Name, First_Name__c, Last_Name__c, Employee_Code__c FROM Employee__c WHERE Id = '$employeeId'";
    final encodedQuery = Uri.encodeComponent(query);
    final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List;

        if (records.isNotEmpty) {
          return records.first;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Custom TimeoutException class
class TimeoutException implements Exception {
  final String message;
  final Duration? duration;

  TimeoutException(this.message, [this.duration]);

  @override
  String toString() => 'TimeoutException: $message';
}