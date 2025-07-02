import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:codmgo2/services/salesforce_auth_service.dart';

class SharedPrefsUtils {
  static final Logger _logger = Logger();
  static SharedPreferences? _prefs;

  // Keys for SharedPreferences
  static const String _keyRememberMe = 'remember_me';
  static const String _keyEmployeeId = 'employee_id';
  static const String _keyFirstName = 'first_name';
  static const String _keyLastName = 'last_name';
  static const String _keyEmail = 'email';
  static const String _keyAccessToken = 'access_token';
  static const String _keyInstanceUrl = 'instance_url';
  static const String _keyTokenExpiry = 'token_expiry';
  static const String _keyEmployeeData = 'employee_data';

  // Initialize SharedPreferences instance
  static Future<SharedPreferences> get _instance async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  // Generic helper methods
  static Future<bool> _setBool(String key, bool value) async {
    try {
      final prefs = await _instance;
      return await prefs.setBool(key, value);
    } catch (e) {
      _logger.e('Error setting bool for key $key: $e');
      return false;
    }
  }

  static Future<bool> _setString(String key, String value) async {
    try {
      final prefs = await _instance;
      return await prefs.setString(key, value);
    } catch (e) {
      _logger.e('Error setting string for key $key: $e');
      return false;
    }
  }

  static Future<bool> _getBool(String key, {bool defaultValue = false}) async {
    try {
      final prefs = await _instance;
      return prefs.getBool(key) ?? defaultValue;
    } catch (e) {
      _logger.e('Error getting bool for key $key: $e');
      return defaultValue;
    }
  }

  static Future<String?> _getString(String key) async {
    try {
      final prefs = await _instance;
      return prefs.getString(key);
    } catch (e) {
      _logger.e('Error getting string for key $key: $e');
      return null;
    }
  }

  static Future<bool> _remove(String key) async {
    try {
      final prefs = await _instance;
      return await prefs.remove(key);
    } catch (e) {
      _logger.e('Error removing key $key: $e');
      return false;
    }
  }

  static Future<bool> _removeMultiple(List<String> keys) async {
    try {
      final results = await Future.wait(keys.map((key) => _remove(key)));
      return results.every((result) => result);
    } catch (e) {
      _logger.e('Error removing multiple keys: $e');
      return false;
    }
  }

  // Employee Data Management
  /// Always saves employee data regardless of remember me status
  static Future<bool> saveEmployeeData(
      String employeeId,
      String firstName,
      String lastName, {
        String? email,
      }) async {
    try {
      _logger.i('Saving employee data for: $employeeId');

      final tasks = [
        _setString(_keyEmployeeId, employeeId),
        _setString(_keyFirstName, firstName),
        _setString(_keyLastName, lastName),
      ];

      if (email != null) {
        tasks.add(_setString(_keyEmail, email));
      }

      final results = await Future.wait(tasks);
      final success = results.every((result) => result);

      if (success) {
        _logger.i('Employee data saved successfully');
      } else {
        _logger.e('Failed to save employee data');
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error saving employee data: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Gets saved employee data regardless of remember me status
  static Future<Map<String, dynamic>?> getSavedEmployeeData() async {
    try {
      final employeeId = await _getString(_keyEmployeeId);
      final firstName = await _getString(_keyFirstName);
      final lastName = await _getString(_keyLastName);
      final email = await _getString(_keyEmail);

      if (employeeId != null && firstName != null && lastName != null) {
        return {
          'employee_id': employeeId,
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
        };
      }

      return null;
    } catch (e, stackTrace) {
      _logger.e('Error getting saved employee data: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  // Remember Me Management
  /// Sets the remember me flag separately
  static Future<bool> setRememberMeFlag(bool rememberMe) async {
    try {
      _logger.i('Setting remember me flag: $rememberMe');
      return await _setBool(_keyRememberMe, rememberMe);
    } catch (e, stackTrace) {
      _logger.e('Error setting remember me flag: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Saves employee data with remember me status
  static Future<bool> saveRememberMeStatus(
      String employeeId,
      String firstName,
      String lastName, {
        String? email,
      }) async {
    try {
      _logger.i('Saving remember me status for employee: $employeeId');

      final tasks = [
        saveEmployeeData(employeeId, firstName, lastName, email: email),
        setRememberMeFlag(true),
      ];

      final results = await Future.wait(tasks);
      final success = results.every((result) => result);

      if (success) {
        _logger.i('Remember me status saved successfully');
      } else {
        _logger.e('Failed to save remember me status');
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error saving remember me status: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Only returns data if remember me flag is true
  static Future<Map<String, dynamic>?> checkRememberMeStatus() async {
    try {
      _logger.i('Checking remember me status');

      final rememberMe = await _getBool(_keyRememberMe);
      if (!rememberMe) {
        _logger.i('Remember me is not enabled');
        return null;
      }

      final employeeData = await getSavedEmployeeData();
      if (employeeData != null) {
        employeeData['remember_me'] = true;
        _logger.i('Found remembered user data for employee: ${employeeData['employee_id']}');
        return employeeData;
      }

      _logger.i('No valid remember me data found');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error checking remember me status: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Clears only the remember me flag, keeps employee data
  static Future<bool> clearRememberMeFlag() async {
    try {
      _logger.i('Clearing remember me flag');
      return await _remove(_keyRememberMe);
    } catch (e, stackTrace) {
      _logger.e('Error clearing remember me flag: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Clears all remember me related data including employee data
  static Future<bool> clearRememberMeData() async {
    try {
      _logger.i('Clearing remember me data');

      final success = await _removeMultiple([
        _keyRememberMe,
        _keyEmployeeId,
        _keyFirstName,
        _keyLastName,
        _keyEmail,
      ]);

      if (success) {
        _logger.i('Remember me data cleared successfully');
      } else {
        _logger.e('Failed to clear remember me data');
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error clearing remember me data: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get remember me status without checking employee data (for UI state)
  static Future<bool> getRememberMeCheckboxState() async {
    return await _getBool(_keyRememberMe);
  }

  // Salesforce Credentials Management
  /// Saves Salesforce authentication credentials
  static Future<bool> saveSalesforceCredentials(
      String accessToken,
      String instanceUrl, {
        Duration? tokenLifetime,
      }) async {
    try {
      _logger.i('Saving Salesforce credentials');

      final lifetime = tokenLifetime ?? const Duration(hours: 2);
      final expiryDate = DateTime.now().add(lifetime);

      final tasks = [
        _setString(_keyAccessToken, accessToken),
        _setString(_keyInstanceUrl, instanceUrl),
        _setString(_keyTokenExpiry, expiryDate.toIso8601String()),
      ];

      final results = await Future.wait(tasks);
      final success = results.every((result) => result);

      if (success) {
        _logger.i('Salesforce credentials saved successfully. Token expires: ${expiryDate.toIso8601String()}');
      } else {
        _logger.e('Failed to save Salesforce credentials');
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error saving Salesforce credentials: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Gets valid Salesforce credentials, refreshing if needed
  static Future<Map<String, String>?> getSalesforceCredentials() async {
    try {
      _logger.i('Getting Salesforce credentials');

      final accessToken = await _getString(_keyAccessToken);
      final instanceUrl = await _getString(_keyInstanceUrl);
      final tokenExpiryString = await _getString(_keyTokenExpiry);

      if (accessToken == null || instanceUrl == null || tokenExpiryString == null) {
        _logger.w('Incomplete Salesforce credentials found');
        return await _refreshSalesforceCredentials();
      }

      final tokenExpiry = DateTime.parse(tokenExpiryString);
      final now = DateTime.now();

      // Check if token is expired (with 5 minute buffer)
      if (now.isAfter(tokenExpiry.subtract(const Duration(minutes: 5)))) {
        _logger.i('Access token is expired or about to expire, refreshing');
        return await _refreshSalesforceCredentials();
      }

      _logger.i('Using cached Salesforce credentials');
      return {
        'access_token': accessToken,
        'instance_url': instanceUrl,
      };
    } catch (e, stackTrace) {
      _logger.e('Error getting Salesforce credentials: $e', error: e, stackTrace: stackTrace);
      return await _refreshSalesforceCredentials();
    }
  }

  /// Refreshes Salesforce credentials
  static Future<Map<String, String>?> _refreshSalesforceCredentials() async {
    try {
      _logger.i('Refreshing Salesforce credentials');

      final authData = await SalesforceAuthService.authenticate();
      if (authData == null) {
        _logger.e('Failed to refresh Salesforce credentials');
        await clearSalesforceCredentials();
        return null;
      }

      final accessToken = authData['access_token'];
      final instanceUrl = authData['instance_url'];

      if (accessToken == null || instanceUrl == null) {
        _logger.e('Invalid auth data received');
        return null;
      }

      // Save the refreshed credentials
      await saveSalesforceCredentials(accessToken, instanceUrl);

      _logger.i('Salesforce credentials refreshed successfully');
      return {
        'access_token': accessToken,
        'instance_url': instanceUrl,
      };
    } catch (e, stackTrace) {
      _logger.e('Error refreshing Salesforce credentials: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Clears Salesforce credentials
  static Future<bool> clearSalesforceCredentials() async {
    try {
      _logger.i('Clearing Salesforce credentials');

      final success = await _removeMultiple([
        _keyAccessToken,
        _keyInstanceUrl,
        _keyTokenExpiry,
      ]);

      if (success) {
        _logger.i('Salesforce credentials cleared successfully');
      } else {
        _logger.e('Failed to clear Salesforce credentials');
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error clearing Salesforce credentials: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Combined Operations
  /// Gets current employee ID from saved data
  static Future<String?> getCurrentEmployeeId() async {
    try {
      final employeeData = await getSavedEmployeeData();
      return employeeData?['employee_id'];
    } catch (e, stackTrace) {
      _logger.e('Error getting current employee ID: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Gets valid credentials with employee ID for API calls
  static Future<Map<String, String>?> getValidCredentialsWithEmployeeId() async {
    try {
      _logger.i('Getting valid credentials with employee ID');

      final credentials = await getSalesforceCredentials();
      if (credentials == null) {
        _logger.e('Failed to get valid Salesforce credentials');
        return null;
      }

      final employeeId = await getCurrentEmployeeId();
      if (employeeId == null) {
        _logger.e('Failed to get employee ID');
        return null;
      }

      return {
        'access_token': credentials['access_token']!,
        'instance_url': credentials['instance_url']!,
        'employee_id': employeeId,
      };
    } catch (e, stackTrace) {
      _logger.e('Error getting valid credentials with employee ID: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Saves complete employee data with Salesforce credentials
  static Future<bool> saveEmployeeDataToPrefs(
      Map<String, dynamic> employee,
      String accessToken,
      String instanceUrl,
      ) async {
    try {
      _logger.i('Saving employee data to preferences');

      final tasks = [
        saveSalesforceCredentials(accessToken, instanceUrl),
        _setString(_keyEmployeeData, employee.toString()),
      ];

      final results = await Future.wait(tasks);
      final success = results.every((result) => result);

      if (success) {
        _logger.i('Employee data saved to preferences successfully');
      } else {
        _logger.e('Failed to save employee data to preferences');
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error saving employee data to preferences: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Gets employee data from preferences
  static Future<String?> getEmployeeDataFromPrefs() async {
    return await _getString(_keyEmployeeData);
  }

  // Session and Validation
  /// Check if user has a valid session (for auto-login scenarios)
  static Future<bool> hasValidUserSession() async {
    try {
      final rememberedData = await checkRememberMeStatus();
      final credentials = await getSalesforceCredentials();
      return rememberedData != null && credentials != null;
    } catch (e, stackTrace) {
      _logger.e('Error checking valid user session: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Cleanup
  /// Clear all data (logout)
  static Future<bool> clearAllData() async {
    try {
      _logger.i('Clearing all stored data');

      final tasks = [
        clearRememberMeData(),
        clearSalesforceCredentials(),
        _remove(_keyEmployeeData),
      ];

      final results = await Future.wait(tasks);
      final success = results.every((result) => result);

      if (success) {
        _logger.i('All stored data cleared successfully');
      } else {
        _logger.e('Failed to clear all data');
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error clearing all data: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Dispose resources
  static void dispose() {
    _prefs = null;
  }
}