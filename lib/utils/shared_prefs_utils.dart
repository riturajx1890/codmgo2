import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:codmgo2/services/salesforce_auth_service.dart';

class SharedPrefsUtils {
  static final Logger _logger = Logger();

  // Keys for SharedPreferences
  static const String _keyRememberMe = 'remember_me';
  static const String _keyEmployeeId = 'employee_id';
  static const String _keyFirstName = 'first_name';
  static const String _keyLastName = 'last_name';
  static const String _keyEmail = 'email';
  static const String _keyAccessToken = 'access_token';
  static const String _keyInstanceUrl = 'instance_url';
  static const String _keyTokenExpiry = 'token_expiry';
  static const String _keyRememberMeExpiry = 'remember_me_expiry';
  static const String _keyEmployeeData = 'employee_data';

  // Remember me duration (45 days)
  static const int _rememberMeDays = 45;

  /// Saves the remember me status with expiration (45 days)
  static Future<bool> saveRememberMeStatus(
      String employeeId,
      String firstName,
      String lastName,
      {String? email}
      ) async {
    try {
      _logger.i('Saving remember me status for employee: $employeeId');

      final prefs = await SharedPreferences.getInstance();
      final expiryDate = DateTime.now().add(Duration(days: _rememberMeDays));

      final success = await Future.wait([
        prefs.setBool(_keyRememberMe, true),
        prefs.setString(_keyEmployeeId, employeeId),
        prefs.setString(_keyFirstName, firstName),
        prefs.setString(_keyLastName, lastName),
        if (email != null) prefs.setString(_keyEmail, email),
        prefs.setString(_keyRememberMeExpiry, expiryDate.toIso8601String()),
      ]).then((_) => true).catchError((_) => false);

      if (success) {
        _logger.i('Remember me status saved successfully. Expires: ${expiryDate.toIso8601String()}');
      } else {
        _logger.e('Failed to save remember me status');
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error saving remember me status: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Checks remember me status and returns user data if valid
  static Future<Map<String, dynamic>?> checkRememberMeStatus() async {
    try {
      _logger.i('Checking remember me status');

      final prefs = await SharedPreferences.getInstance();
      final isRemembered = prefs.getBool(_keyRememberMe) ?? false;

      if (!isRemembered) {
        _logger.i('Remember me is not enabled');
        return null;
      }

      final expiryString = prefs.getString(_keyRememberMeExpiry);
      if (expiryString == null) {
        _logger.w('Remember me expiry date not found, clearing data');
        await clearRememberMeData();
        return null;
      }

      final expiryDate = DateTime.parse(expiryString);
      if (DateTime.now().isAfter(expiryDate)) {
        _logger.w('Remember me has expired, clearing data');
        await clearRememberMeData();
        return null;
      }

      final employeeId = prefs.getString(_keyEmployeeId);
      final firstName = prefs.getString(_keyFirstName);
      final lastName = prefs.getString(_keyLastName);
      final email = prefs.getString(_keyEmail);

      if (employeeId == null || firstName == null || lastName == null) {
        _logger.w('Incomplete remember me data, clearing');
        await clearRememberMeData();
        return null;
      }

      _logger.i('Remember me data is valid for employee: $employeeId');

      return {
        'employee_id': employeeId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'expires_at': expiryDate.toIso8601String(),
      };
    } catch (e, stackTrace) {
      _logger.e('Error checking remember me status: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Clears all remember me data
  static Future<void> clearRememberMeData() async {
    try {
      _logger.i('Clearing remember me data');

      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_keyRememberMe),
        prefs.remove(_keyEmployeeId),
        prefs.remove(_keyFirstName),
        prefs.remove(_keyLastName),
        prefs.remove(_keyEmail),
        prefs.remove(_keyRememberMeExpiry),
      ]);

      _logger.i('Remember me data cleared successfully');
    } catch (e, stackTrace) {
      _logger.e('Error clearing remember me data: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Saves Salesforce authentication credentials
  static Future<bool> saveSalesforceCredentials(
      String accessToken,
      String instanceUrl,
      {Duration? tokenLifetime}
      ) async {
    try {
      _logger.i('Saving Salesforce credentials');

      final prefs = await SharedPreferences.getInstance();

      // Default token lifetime is 2 hours if not specified
      final lifetime = tokenLifetime ?? Duration(hours: 2);
      final expiryDate = DateTime.now().add(lifetime);

      final success = await Future.wait([
        prefs.setString(_keyAccessToken, accessToken),
        prefs.setString(_keyInstanceUrl, instanceUrl),
        prefs.setString(_keyTokenExpiry, expiryDate.toIso8601String()),
      ]).then((_) => true).catchError((_) => false);

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

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_keyAccessToken);
      final instanceUrl = prefs.getString(_keyInstanceUrl);
      final tokenExpiryString = prefs.getString(_keyTokenExpiry);

      if (accessToken == null || instanceUrl == null || tokenExpiryString == null) {
        _logger.w('Incomplete Salesforce credentials found');
        return await _refreshSalesforceCredentials();
      }

      final tokenExpiry = DateTime.parse(tokenExpiryString);
      final now = DateTime.now();

      // Check if token is expired (with 5 minute buffer)
      if (now.isAfter(tokenExpiry.subtract(Duration(minutes: 5)))) {
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
  static Future<void> clearSalesforceCredentials() async {
    try {
      _logger.i('Clearing Salesforce credentials');

      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_keyAccessToken),
        prefs.remove(_keyInstanceUrl),
        prefs.remove(_keyTokenExpiry),
      ]);

      _logger.i('Salesforce credentials cleared successfully');
    } catch (e, stackTrace) {
      _logger.e('Error clearing Salesforce credentials: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Saves complete employee data to preferences
  static Future<bool> saveEmployeeDataToPrefs(
      Map<String, dynamic> employee,
      String accessToken,
      String instanceUrl,
      ) async {
    try {
      _logger.i('Saving employee data to preferences');

      // Save Salesforce credentials
      await saveSalesforceCredentials(accessToken, instanceUrl);

      // Save employee data
      final prefs = await SharedPreferences.getInstance();
      final employeeJson = employee.toString(); // You might want to use json.encode() here

      final success = await prefs.setString(_keyEmployeeData, employeeJson);

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
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyEmployeeData);
    } catch (e, stackTrace) {
      _logger.e('Error getting employee data from preferences: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Enhanced method to get current user's employee ID
  static Future<String?> getCurrentEmployeeId() async {
    try {
      _logger.i('Getting current employee ID');

      // First try from remember me data
      final rememberedData = await checkRememberMeStatus();
      if (rememberedData != null) {
        final employeeId = rememberedData['employee_id'];
        _logger.i('Found employee ID from remember me: $employeeId');
        return employeeId;
      }

      // If not found, try from stored preferences (for current session)
      final prefs = await SharedPreferences.getInstance();
      final employeeId = prefs.getString(_keyEmployeeId);

      if (employeeId != null) {
        _logger.i('Found employee ID from current session: $employeeId');
        return employeeId;
      }

      _logger.w('No employee ID found in storage');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error getting current employee ID: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Method to save current session employee ID (without remember me)
  static Future<bool> saveCurrentSessionEmployeeId(String employeeId) async {
    try {
      _logger.i('Saving current session employee ID: $employeeId');

      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_keyEmployeeId, employeeId);

      if (success) {
        _logger.i('Current session employee ID saved successfully');
      } else {
        _logger.e('Failed to save current session employee ID');
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error saving current session employee ID: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Comprehensive method to get valid credentials and employee ID for API calls
  static Future<Map<String, String>?> getValidCredentialsWithEmployeeId() async {
    try {
      _logger.i('Getting valid credentials with employee ID');

      // Get Salesforce credentials (will refresh if needed)
      final credentials = await getSalesforceCredentials();
      if (credentials == null) {
        _logger.e('Failed to get valid Salesforce credentials');
        return null;
      }

      // Get employee ID
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

  /// Clear all data (logout)
  static Future<void> clearAllData() async {
    try {
      _logger.i('Clearing all stored data');

      await Future.wait([
        clearRememberMeData(),
        clearSalesforceCredentials(),
      ]);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyEmployeeData);

      _logger.i('All stored data cleared successfully');
    } catch (e, stackTrace) {
      _logger.e('Error clearing all data: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Check if user data is available (for auto-login scenarios)
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

  /// Get remember me status without checking expiry (for UI state)
  static Future<bool> getRememberMeCheckboxState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyRememberMe) ?? false;
    } catch (e, stackTrace) {
      _logger.e('Error getting remember me checkbox state: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}