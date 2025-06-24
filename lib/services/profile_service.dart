import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:codmgo2/utils/shared_prefs_utils.dart';

class ProfileService {
  static const String _apiVersion = 'v52.0';
  static final Logger _logger = Logger();

  /// Gets access token and instance URL from SharedPrefsUtils
  static Future<Map<String, String>?> getAuthData() async {
    try {
      _logger.i('Getting auth data from SharedPrefsUtils');

      // Use SharedPrefsUtils to get valid credentials (handles refresh automatically)
      final credentials = await SharedPrefsUtils.getSalesforceCredentials();

      if (credentials == null) {
        _logger.e('Failed to get valid credentials from SharedPrefsUtils');
        return null;
      }

      final normalizedUrl = credentials['instance_url']!.endsWith('/')
          ? credentials['instance_url']!.substring(0, credentials['instance_url']!.length - 1)
          : credentials['instance_url']!;

      return {
        'access_token': credentials['access_token']!,
        'instance_url': normalizedUrl,
      };
    } catch (e, stackTrace) {
      _logger.e('Error getting auth data: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Gets complete auth data with employee ID
  static Future<Map<String, String>?> getAuthDataWithEmployeeId() async {
    try {
      _logger.i('Getting auth data with employee ID from SharedPrefsUtils');

      // Use SharedPrefsUtils comprehensive method
      final credentials = await SharedPrefsUtils.getValidCredentialsWithEmployeeId();

      if (credentials == null) {
        _logger.e('Failed to get valid credentials with employee ID');
        return null;
      }

      final normalizedUrl = credentials['instance_url']!.endsWith('/')
          ? credentials['instance_url']!.substring(0, credentials['instance_url']!.length - 1)
          : credentials['instance_url']!;

      return {
        'access_token': credentials['access_token']!,
        'instance_url': normalizedUrl,
        'employee_id': credentials['employee_id']!,
      };
    } catch (e, stackTrace) {
      _logger.e('Error getting auth data with employee ID: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Fetches current user's profile data
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      _logger.i('Getting current user profile');

      final authData = await getAuthDataWithEmployeeId();
      if (authData == null) {
        _logger.e('Authentication data not available for current user');
        return null;
      }

      final employeeId = authData['employee_id']!;
      return await _getEmployeeProfileWithAuth(
        authData['access_token']!,
        authData['instance_url']!,
        employeeId,
      );
    } catch (e, stackTrace) {
      _logger.e('Error getting current user profile: $e', error: e, stackTrace: stackTrace);
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
        _logger.e('Unauthorized - token may be expired, attempting to refresh credentials');

        // Try to refresh credentials and retry once
        final refreshedAuth = await getAuthData();
        if (refreshedAuth != null) {
          _logger.i('Credentials refreshed, retrying request');
          return await _getEmployeeProfileWithAuth(
            refreshedAuth['access_token']!,
            refreshedAuth['instance_url']!,
            employeeId,
          );
        }

        return null;
      } else {
        _logger.e('Request failed with status: ${response.statusCode}, body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Exception occurred during API call: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Updates current user's profile data
  static Future<bool> updateCurrentUserProfile(Map<String, dynamic> profileData) async {
    try {
      final authData = await getAuthDataWithEmployeeId();
      if (authData == null) {
        _logger.e('Authentication data not available for current user');
        return false;
      }

      final employeeId = authData['employee_id']!;
      return await _updateEmployeeProfileWithAuth(
        authData['access_token']!,
        authData['instance_url']!,
        employeeId,
        profileData,
      );
    } catch (e, stackTrace) {
      _logger.e('Error updating current user profile: $e', error: e, stackTrace: stackTrace);
      return false;
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
      _logger.e('Employee ID is empty or profile data is empty');
      return false;
    }

    final url = '$instanceUrl/services/data/$_apiVersion/sobjects/Employee__c/$employeeId';

    try {
      _logger.i('Updating employee profile for ID: $employeeId');

      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(profileData),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 204) {
        _logger.i('Profile update successful for employee ID: $employeeId');
        return true;
      } else if (response.statusCode == 401) {
        _logger.e('Unauthorized during update - token may be expired, attempting to refresh');

        // Try to refresh credentials and retry once
        final refreshedAuth = await getAuthData();
        if (refreshedAuth != null) {
          _logger.i('Credentials refreshed, retrying update');
          return await _updateEmployeeProfileWithAuth(
            refreshedAuth['access_token']!,
            refreshedAuth['instance_url']!,
            employeeId,
            profileData,
          );
        }

        return false;
      } else {
        _logger.e('Update failed with status: ${response.statusCode}, body: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating employee profile: $e', error: e, stackTrace: stackTrace);
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
    final query = "SELECT Id, Name, First_Name__c, Last_Name__c, Email__c, Department__c, Employee_Code__c FROM Employee__c ORDER BY Last_Name__c, First_Name__c";
    final encodedQuery = Uri.encodeComponent(query);
    final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

    try {
      _logger.i('Getting all employees');

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
        _logger.i('Retrieved ${records.length} employees');
        return records.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        _logger.e('Unauthorized - token may be expired, attempting to refresh');

        // Try to refresh credentials and retry once
        final refreshedAuth = await getAuthData();
        if (refreshedAuth != null) {
          _logger.i('Credentials refreshed, retrying get all employees');
          return await _getAllEmployeesWithAuth(
            refreshedAuth['access_token']!,
            refreshedAuth['instance_url']!,
          );
        }

        return null;
      } else {
        _logger.e('Get all employees failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error getting all employees: $e', error: e, stackTrace: stackTrace);
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
    if (employeeData.isEmpty) {
      _logger.e('Employee data is empty');
      return null;
    }

    final url = '$instanceUrl/services/data/$_apiVersion/sobjects/Employee__c';

    try {
      _logger.i('Creating new employee');

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
        _logger.i('Employee created successfully with ID: $newId');
        return newId;
      } else if (response.statusCode == 401) {
        _logger.e('Unauthorized during create - token may be expired, attempting to refresh');

        // Try to refresh credentials and retry once
        final refreshedAuth = await getAuthData();
        if (refreshedAuth != null) {
          _logger.i('Credentials refreshed, retrying create employee');
          return await _createEmployeeWithAuth(
            refreshedAuth['access_token']!,
            refreshedAuth['instance_url']!,
            employeeData,
          );
        }

        return null;
      } else {
        _logger.e('Create employee failed with status: ${response.statusCode}, body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error creating employee: $e', error: e, stackTrace: stackTrace);
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
      _logger.e('Search term is empty');
      return null;
    }

    final escapedSearchTerm = searchTerm.replaceAll("'", "\\'");
    final query = "SELECT Id, Name, First_Name__c, Last_Name__c, Employee_Code__c, Email__c, Department__c FROM Employee__c WHERE First_Name__c LIKE '%$escapedSearchTerm%' OR Last_Name__c LIKE '%$escapedSearchTerm%' OR Email__c LIKE '%$escapedSearchTerm%' OR Employee_Code__c LIKE '%$escapedSearchTerm%' ORDER BY Last_Name__c, First_Name__c";

    final encodedQuery = Uri.encodeComponent(query);
    final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

    try {
      _logger.i('Searching employees with term: $searchTerm');

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
        _logger.i('Found ${records.length} employees matching search term');
        return records.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        _logger.e('Unauthorized during search - token may be expired, attempting to refresh');

        // Try to refresh credentials and retry once
        final refreshedAuth = await getAuthData();
        if (refreshedAuth != null) {
          _logger.i('Credentials refreshed, retrying search');
          return await _searchEmployeesWithAuth(
            refreshedAuth['access_token']!,
            refreshedAuth['instance_url']!,
            searchTerm,
          );
        }

        return null;
      } else {
        _logger.e('Search failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error searching employees: $e', error: e, stackTrace: stackTrace);
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
      _logger.e('Department is empty');
      return null;
    }

    final escapedDepartment = department.replaceAll("'", "\\'");
    final query = "SELECT Id, Name, First_Name__c, Last_Name__c, Employee_Code__c, Email__c, Department__c FROM Employee__c WHERE Department__c = '$escapedDepartment' ORDER BY Last_Name__c, First_Name__c";

    final encodedQuery = Uri.encodeComponent(query);
    final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

    try {
      _logger.i('Getting employees by department: $department');

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
        _logger.i('Found ${records.length} employees in department: $department');
        return records.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        _logger.e('Unauthorized - token may be expired, attempting to refresh');

        // Try to refresh credentials and retry once
        final refreshedAuth = await getAuthData();
        if (refreshedAuth != null) {
          _logger.i('Credentials refreshed, retrying get by department');
          return await _getEmployeesByDepartmentWithAuth(
            refreshedAuth['access_token']!,
            refreshedAuth['instance_url']!,
            department,
          );
        }

        return null;
      } else {
        _logger.e('Get by department failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error getting employees by department: $e', error: e, stackTrace: stackTrace);
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
    if (employeeId.isEmpty) {
      _logger.e('Employee ID is empty');
      return null;
    }

    final query = "SELECT Id, Name, First_Name__c, Last_Name__c, Employee_Code__c FROM Employee__c WHERE Id = '$employeeId'";
    final encodedQuery = Uri.encodeComponent(query);
    final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

    try {
      _logger.i('Getting basic info for employee ID: $employeeId');

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
          _logger.i('Basic info found for employee ID: $employeeId');
          return records.first;
        } else {
          _logger.w('No basic info found for employee ID: $employeeId');
          return null;
        }
      } else if (response.statusCode == 401) {
        _logger.e('Unauthorized - token may be expired, attempting to refresh');

        // Try to refresh credentials and retry once
        final refreshedAuth = await getAuthData();
        if (refreshedAuth != null) {
          _logger.i('Credentials refreshed, retrying get basic info');
          return await getEmployeeBasicInfoWithAuth(
            refreshedAuth['access_token']!,
            refreshedAuth['instance_url']!,
            employeeId,
          );
        }

        return null;
      } else {
        _logger.e('Get basic info failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error getting employee basic info: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Checks if user has valid session for profile operations
  static Future<bool> hasValidSession() async {
    try {
      return await SharedPrefsUtils.hasValidUserSession();
    } catch (e, stackTrace) {
      _logger.e('Error checking valid session: $e', error: e, stackTrace: stackTrace);
      return false;
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