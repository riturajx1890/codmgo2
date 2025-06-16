import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static const String _apiVersion = 'v60.0';
  static final Logger _logger = Logger();

  /// Validates instanceUrl format - more flexible validation
  static bool _isValidInstanceUrl(String? instanceUrl) {
    if (instanceUrl == null || instanceUrl.isEmpty) {
      return false;
    }

    // Remove trailing slash if present for validation
    String cleanUrl = instanceUrl.endsWith('/') ? instanceUrl.substring(0, instanceUrl.length - 1) : instanceUrl;

    // Should start with https:// and contain domain
    if (!cleanUrl.startsWith('https://')) {
      return false;
    }

    // Check for valid domain pattern
    try {
      Uri.parse(cleanUrl);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Normalizes instanceUrl by removing trailing slash
  static String _normalizeInstanceUrl(String instanceUrl) {
    return instanceUrl.endsWith('/') ? instanceUrl.substring(0, instanceUrl.length - 1) : instanceUrl;
  }

  /// Gets access token and instance URL from SharedPreferences
  static Future<Map<String, String>?> getAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final instanceUrl = prefs.getString('instance_url');

      if (accessToken == null || accessToken.isEmpty) {
        _logger.e('Access token not found in SharedPreferences');
        return null;
      }

      if (instanceUrl == null || instanceUrl.isEmpty) {
        _logger.e('Instance URL not found in SharedPreferences');
        return null;
      }

      return {
        'access_token': accessToken,
        'instance_url': _normalizeInstanceUrl(instanceUrl),
      };
    } catch (e, stackTrace) {
      _logger.e('Error getting auth data from SharedPreferences: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Fetches employee profile data by Employee ID.
  /// This method will automatically get the access token from SharedPreferences
  static Future<Map<String, dynamic>?> getEmployeeProfile(String employeeId) async {
    if (employeeId.isEmpty) {
      _logger.e('Employee ID is empty');
      return null;
    }

    // Get auth data from SharedPreferences
    final authData = await getAuthData();
    if (authData == null) {
      _logger.e('Could not retrieve authentication data');
      return null;
    }

    final accessToken = authData['access_token']!;
    final instanceUrl = authData['instance_url']!;

    return await _getEmployeeProfileWithAuth(accessToken, instanceUrl, employeeId);
  }

  /// Fetches employee profile data by Employee ID with provided auth data.
  static Future<Map<String, dynamic>?> getEmployeeProfileWithAuth(
      String accessToken,
      String instanceUrl,
      String employeeId,
      ) async {
    return await _getEmployeeProfileWithAuth(accessToken, instanceUrl, employeeId);
  }

  /// Internal method to fetch employee profile with auth data
  static Future<Map<String, dynamic>?> _getEmployeeProfileWithAuth(
      String accessToken,
      String instanceUrl,
      String employeeId,
      ) async {

    // Validate inputs
    if (accessToken.isEmpty) {
      _logger.e('Access token is empty');
      return null;
    }

    final normalizedUrl = _normalizeInstanceUrl(instanceUrl);
    if (!_isValidInstanceUrl(normalizedUrl)) {
      _logger.e('Invalid instance URL: $instanceUrl. Should be like: https://your-domain.salesforce.com');
      return null;
    }

    if (employeeId.isEmpty) {
      _logger.e('Employee ID is empty');
      return null;
    }

    _logger.i('Fetching employee profile for ID: $employeeId');
    _logger.i('Using instance URL: $normalizedUrl');

    // Escape single quotes in employeeId to prevent SOQL injection
    final escapedEmployeeId = employeeId.replaceAll("'", "\\'");

    final query = '''
      SELECT Id, First_Name__c, Last_Name__c, Employee_Code__c, Performance_Flag__c, 
             Phone__c, Email__c, Bank_Name__c, IFSC_Code__c, Bank_Account_Number__c, 
             Aadhar_Number__c, PAN_Card__c, Date_of_Birth__c, Work_Location__c, 
             Joining_Date__c, Reporting_Manager__c, Annual_Review_Date__c, Department__c 
      FROM Employee__c 
      WHERE Id = '$escapedEmployeeId'
    ''';
    final encodedQuery = Uri.encodeComponent(query);

    // Construct the full URL properly
    final urlString = '$normalizedUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

    try {
      final url = Uri.parse(urlString);

      _logger.i('Profile query URL: $url');
      _logger.d('Query: $query');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timeout after 30 seconds');
        },
      );

      _logger.i('Profile response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'];

        if (records != null && records.isNotEmpty) {
          final profile = records[0];
          _logger.i('Employee profile found for ID: $employeeId');
          return profile;
        } else {
          _logger.w('No employee profile found for ID: $employeeId');
          return null;
        }
      } else if (response.statusCode == 401) {
        _logger.e('Unauthorized: Invalid or expired access token');
        return null;
      } else {
        _logger.e('Failed to fetch employee profile. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return null;
      }
    } on FormatException catch (e) {
      _logger.e('Invalid URL format: $urlString');
      _logger.e('Format error: $e');
      return null;
    } on TimeoutException catch (e) {
      _logger.e('Request timeout: $e');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error fetching employee profile: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Updates employee profile data.
  static Future<bool> updateEmployeeProfile(
      String employeeId,
      Map<String, dynamic> profileData,
      ) async {

    if (employeeId.isEmpty) {
      _logger.e('Employee ID is empty');
      return false;
    }

    if (profileData.isEmpty) {
      _logger.e('Profile data is empty');
      return false;
    }

    // Get auth data from SharedPreferences
    final authData = await getAuthData();
    if (authData == null) {
      _logger.e('Could not retrieve authentication data');
      return false;
    }

    final accessToken = authData['access_token']!;
    final instanceUrl = authData['instance_url']!;

    return await _updateEmployeeProfileWithAuth(accessToken, instanceUrl, employeeId, profileData);
  }

  /// Updates employee profile data with provided auth data.
  static Future<bool> updateEmployeeProfileWithAuth(
      String accessToken,
      String instanceUrl,
      String employeeId,
      Map<String, dynamic> profileData,
      ) async {
    return await _updateEmployeeProfileWithAuth(accessToken, instanceUrl, employeeId, profileData);
  }

  /// Internal method to update employee profile with auth data
  static Future<bool> _updateEmployeeProfileWithAuth(
      String accessToken,
      String instanceUrl,
      String employeeId,
      Map<String, dynamic> profileData,
      ) async {

    // Validate inputs
    if (accessToken.isEmpty) {
      _logger.e('Access token is empty');
      return false;
    }

    final normalizedUrl = _normalizeInstanceUrl(instanceUrl);
    if (!_isValidInstanceUrl(normalizedUrl)) {
      _logger.e('Invalid instance URL: $instanceUrl');
      return false;
    }

    if (employeeId.isEmpty) {
      _logger.e('Employee ID is empty');
      return false;
    }

    if (profileData.isEmpty) {
      _logger.e('Profile data is empty');
      return false;
    }

    _logger.i('Updating employee profile for ID: $employeeId');

    final urlString = '$normalizedUrl/services/data/$_apiVersion/sobjects/Employee__c/$employeeId';
    final body = json.encode(profileData);

    try {
      final url = Uri.parse(urlString);

      _logger.i('Profile update request URL: $url');
      _logger.d('Request body: $body');

      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timeout after 30 seconds');
        },
      );

      _logger.i('Profile update response status: ${response.statusCode}');
      _logger.d('Profile update response body: ${response.body}');

      if (response.statusCode == 204) {
        _logger.i('Profile update successful for employee ID: $employeeId');
        return true;
      } else if (response.statusCode == 401) {
        _logger.e('Unauthorized: Invalid or expired access token');
        return false;
      } else {
        _logger.e('Failed to update profile. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return false;
      }
    } on FormatException catch (e) {
      _logger.e('Invalid URL format: $urlString');
      _logger.e('Format error: $e');
      return false;
    } on TimeoutException catch (e) {
      _logger.e('Request timeout: $e');
      return false;
    } catch (e, stackTrace) {
      _logger.e('Error updating employee profile: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Updates specific profile field.
  static Future<bool> updateProfileField(
      String employeeId,
      String fieldName,
      dynamic fieldValue,
      ) async {

    if (fieldName.isEmpty) {
      _logger.e('Field name is empty');
      return false;
    }

    _logger.i('Updating profile field $fieldName for employee ID: $employeeId');

    final profileData = {fieldName: fieldValue};

    return await updateEmployeeProfile(employeeId, profileData);
  }

  /// Updates specific profile field with provided auth data.
  static Future<bool> updateProfileFieldWithAuth(
      String accessToken,
      String instanceUrl,
      String employeeId,
      String fieldName,
      dynamic fieldValue,
      ) async {

    if (fieldName.isEmpty) {
      _logger.e('Field name is empty');
      return false;
    }

    _logger.i('Updating profile field $fieldName for employee ID: $employeeId');

    final profileData = {fieldName: fieldValue};

    return await _updateEmployeeProfileWithAuth(accessToken, instanceUrl, employeeId, profileData);
  }

  /// Gets all employees (for admin/manager use).
  static Future<List<Map<String, dynamic>>?> getAllEmployees() async {
    // Get auth data from SharedPreferences
    final authData = await getAuthData();
    if (authData == null) {
      _logger.e('Could not retrieve authentication data');
      return null;
    }

    final accessToken = authData['access_token']!;
    final instanceUrl = authData['instance_url']!;

    return await _getAllEmployeesWithAuth(accessToken, instanceUrl);
  }

  /// Gets all employees with provided auth data.
  static Future<List<Map<String, dynamic>>?> getAllEmployeesWithAuth(
      String accessToken,
      String instanceUrl,
      ) async {
    return await _getAllEmployeesWithAuth(accessToken, instanceUrl);
  }

  /// Internal method to get all employees with auth data
  static Future<List<Map<String, dynamic>>?> _getAllEmployeesWithAuth(
      String accessToken,
      String instanceUrl,
      ) async {

    // Validate inputs
    if (accessToken.isEmpty) {
      _logger.e('Access token is empty');
      return null;
    }

    final normalizedUrl = _normalizeInstanceUrl(instanceUrl);
    if (!_isValidInstanceUrl(normalizedUrl)) {
      _logger.e('Invalid instance URL: $instanceUrl');
      return null;
    }

    _logger.i('Fetching all employees');

    final query = '''
      SELECT Id, First_Name__c, Last_Name__c, Employee_Code__c, Performance_Flag__c, 
             Phone__c, Email__c, Bank_Name__c, IFSC_Code__c, Bank_Account_Number__c, 
             Aadhar_Number__c, PAN_Card__c, Date_of_Birth__c, Work_Location__c, 
             Joining_Date__c, Reporting_Manager__c, Annual_Review_Date__c, Department__c 
      FROM Employee__c 
      ORDER BY Last_Name__c, First_Name__c
    ''';
    final encodedQuery = Uri.encodeComponent(query);

    final urlString = '$normalizedUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

    try {
      final url = Uri.parse(urlString);

      _logger.i('All employees query URL: $url');
      _logger.d('Query: $query');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException('Request timeout after 45 seconds');
        },
      );

      _logger.i('All employees response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'];

        if (records != null && records.isNotEmpty) {
          _logger.i('Fetched ${records.length} employee records');
          return List<Map<String, dynamic>>.from(records);
        } else {
          _logger.w('No employee records found');
          return [];
        }
      } else if (response.statusCode == 401) {
        _logger.e('Unauthorized: Invalid or expired access token');
        return null;
      } else {
        _logger.e('Failed to fetch all employees. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return null;
      }
    } on FormatException catch (e) {
      _logger.e('Invalid URL format: $urlString');
      _logger.e('Format error: $e');
      return null;
    } on TimeoutException catch (e) {
      _logger.e('Request timeout: $e');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error fetching all employees: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Creates a new employee record.
  static Future<String?> createEmployee(
      Map<String, dynamic> employeeData,
      ) async {

    if (employeeData.isEmpty) {
      _logger.e('Employee data is empty');
      return null;
    }

    // Get auth data from SharedPreferences
    final authData = await getAuthData();
    if (authData == null) {
      _logger.e('Could not retrieve authentication data');
      return null;
    }

    final accessToken = authData['access_token']!;
    final instanceUrl = authData['instance_url']!;

    return await _createEmployeeWithAuth(accessToken, instanceUrl, employeeData);
  }

  /// Creates a new employee record with provided auth data.
  static Future<String?> createEmployeeWithAuth(
      String accessToken,
      String instanceUrl,
      Map<String, dynamic> employeeData,
      ) async {
    return await _createEmployeeWithAuth(accessToken, instanceUrl, employeeData);
  }

  /// Internal method to create employee with auth data
  static Future<String?> _createEmployeeWithAuth(
      String accessToken,
      String instanceUrl,
      Map<String, dynamic> employeeData,
      ) async {

    // Validate inputs
    if (accessToken.isEmpty) {
      _logger.e('Access token is empty');
      return null;
    }

    final normalizedUrl = _normalizeInstanceUrl(instanceUrl);
    if (!_isValidInstanceUrl(normalizedUrl)) {
      _logger.e('Invalid instance URL: $instanceUrl');
      return null;
    }

    if (employeeData.isEmpty) {
      _logger.e('Employee data is empty');
      return null;
    }

    _logger.i('Creating new employee record');

    final urlString = '$normalizedUrl/services/data/$_apiVersion/sobjects/Employee__c';
    final body = json.encode(employeeData);

    try {
      final url = Uri.parse(urlString);

      _logger.i('Create employee request URL: $url');
      _logger.d('Request body: $body');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timeout after 30 seconds');
        },
      );

      _logger.i('Create employee response status: ${response.statusCode}');
      _logger.d('Create employee response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final recordId = data['id'];
        _logger.i('Employee creation successful. Record ID: $recordId');
        return recordId;
      } else if (response.statusCode == 401) {
        _logger.e('Unauthorized: Invalid or expired access token');
        return null;
      } else {
        _logger.e('Failed to create employee. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return null;
      }
    } on FormatException catch (e) {
      _logger.e('Invalid URL format: $urlString');
      _logger.e('Format error: $e');
      return null;
    } on TimeoutException catch (e) {
      _logger.e('Request timeout: $e');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error creating employee: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Searches employees by name, email, or employee code.
  static Future<List<Map<String, dynamic>>?> searchEmployees(
      String searchTerm,
      ) async {

    if (searchTerm.isEmpty) {
      _logger.e('Search term is empty');
      return null;
    }

    // Get auth data from SharedPreferences
    final authData = await getAuthData();
    if (authData == null) {
      _logger.e('Could not retrieve authentication data');
      return null;
    }

    final accessToken = authData['access_token']!;
    final instanceUrl = authData['instance_url']!;

    return await _searchEmployeesWithAuth(accessToken, instanceUrl, searchTerm);
  }

  /// Searches employees with provided auth data.
  static Future<List<Map<String, dynamic>>?> searchEmployeesWithAuth(
      String accessToken,
      String instanceUrl,
      String searchTerm,
      ) async {
    return await _searchEmployeesWithAuth(accessToken, instanceUrl, searchTerm);
  }

  /// Internal method to search employees with auth data
  static Future<List<Map<String, dynamic>>?> _searchEmployeesWithAuth(
      String accessToken,
      String instanceUrl,
      String searchTerm,
      ) async {

    // Validate inputs
    if (accessToken.isEmpty) {
      _logger.e('Access token is empty');
      return null;
    }

    final normalizedUrl = _normalizeInstanceUrl(instanceUrl);
    if (!_isValidInstanceUrl(normalizedUrl)) {
      _logger.e('Invalid instance URL: $instanceUrl');
      return null;
    }

    if (searchTerm.isEmpty) {
      _logger.e('Search term is empty');
      return null;
    }

    _logger.i('Searching employees with term: $searchTerm');

    // Escape single quotes in search term to prevent SOQL injection
    final escapedSearchTerm = searchTerm.replaceAll("'", "\\'");

    final query = '''
      SELECT Id, First_Name__c, Last_Name__c, Employee_Code__c, Performance_Flag__c, 
             Phone__c, Email__c, Bank_Name__c, IFSC_Code__c, Bank_Account_Number__c, 
             Aadhar_Number__c, PAN_Card__c, Date_of_Birth__c, Work_Location__c, 
             Joining_Date__c, Reporting_Manager__c, Annual_Review_Date__c, Department__c 
      FROM Employee__c 
      WHERE First_Name__c LIKE '%$escapedSearchTerm%' 
         OR Last_Name__c LIKE '%$escapedSearchTerm%' 
         OR Email__c LIKE '%$escapedSearchTerm%' 
         OR Employee_Code__c LIKE '%$escapedSearchTerm%'
      ORDER BY Last_Name__c, First_Name__c
    ''';
    final encodedQuery = Uri.encodeComponent(query);

    final urlString = '$normalizedUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

    try {
      final url = Uri.parse(urlString);

      _logger.i('Search employees query URL: $url');
      _logger.d('Query: $query');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timeout after 30 seconds');
        },
      );

      _logger.i('Search employees response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'];

        if (records != null && records.isNotEmpty) {
          _logger.i('Found ${records.length} employees matching search term: $searchTerm');
          return List<Map<String, dynamic>>.from(records);
        } else {
          _logger.w('No employees found matching search term: $searchTerm');
          return [];
        }
      } else if (response.statusCode == 401) {
        _logger.e('Unauthorized: Invalid or expired access token');
        return null;
      } else {
        _logger.e('Failed to search employees. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return null;
      }
    } on FormatException catch (e) {
      _logger.e('Invalid URL format: $urlString');
      _logger.e('Format error: $e');
      return null;
    } on TimeoutException catch (e) {
      _logger.e('Request timeout: $e');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error searching employees: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Gets employees by department.
  static Future<List<Map<String, dynamic>>?> getEmployeesByDepartment(
      String department,
      ) async {

    if (department.isEmpty) {
      _logger.e('Department is empty');
      return null;
    }

    // Get auth data from SharedPreferences
    final authData = await getAuthData();
    if (authData == null) {
      _logger.e('Could not retrieve authentication data');
      return null;
    }

    final accessToken = authData['access_token']!;
    final instanceUrl = authData['instance_url']!;

    return await _getEmployeesByDepartmentWithAuth(accessToken, instanceUrl, department);
  }

  /// Gets employees by department with provided auth data.
  static Future<List<Map<String, dynamic>>?> getEmployeesByDepartmentWithAuth(
      String accessToken,
      String instanceUrl,
      String department,
      ) async {
    return await _getEmployeesByDepartmentWithAuth(accessToken, instanceUrl, department);
  }

  /// Internal method to get employees by department with auth data
  static Future<List<Map<String, dynamic>>?> _getEmployeesByDepartmentWithAuth(
      String accessToken,
      String instanceUrl,
      String department,
      ) async {

    // Validate inputs
    if (accessToken.isEmpty) {
      _logger.e('Access token is empty');
      return null;
    }

    final normalizedUrl = _normalizeInstanceUrl(instanceUrl);
    if (!_isValidInstanceUrl(normalizedUrl)) {
      _logger.e('Invalid instance URL: $instanceUrl');
      return null;
    }

    if (department.isEmpty) {
      _logger.e('Department is empty');
      return null;
    }

    _logger.i('Fetching employees for department: $department');

    // Escape single quotes in department name to prevent SOQL injection
    final escapedDepartment = department.replaceAll("'", "\\'");

    final query = '''
      SELECT Id, First_Name__c, Last_Name__c, Employee_Code__c, Performance_Flag__c, 
             Phone__c, Email__c, Bank_Name__c, IFSC_Code__c, Bank_Account_Number__c, 
             Aadhar_Number__c, PAN_Card__c, Date_of_Birth__c, Work_Location__c, 
             Joining_Date__c, Reporting_Manager__c, Annual_Review_Date__c, Department__c 
      FROM Employee__c 
      WHERE Department__c = '$escapedDepartment'
      ORDER BY Last_Name__c, First_Name__c
    ''';
    final encodedQuery = Uri.encodeComponent(query);

    final urlString = '$normalizedUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

    try {
      final url = Uri.parse(urlString);

      _logger.i('Department employees query URL: $url');
      _logger.d('Query: $query');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timeout after 30 seconds');
        },
      );

      _logger.i('Department employees response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'];

        if (records != null && records.isNotEmpty) {
          _logger.i('Found ${records.length} employees in department: $department');
          return List<Map<String, dynamic>>.from(records);
        } else {
          _logger.w('No employees found in department: $department');
          return [];
        }
      } else if (response.statusCode == 401) {
        _logger.e('Unauthorized: Invalid or expired access token');
        return null;
      } else {
        _logger.e('Failed to fetch department employees. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return null;
      }
    } on FormatException catch (e) {
      _logger.e('Invalid URL format: $urlString');
      _logger.e('Format error: $e');
      return null;
    } on TimeoutException catch (e) {
      _logger.e('Request timeout: $e');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error fetching department employees: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}

// Add TimeoutException import if not already present
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}