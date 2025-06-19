import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class SharedPrefsUtils {
  static final Logger _logger = Logger();

  /// Save employee data to SharedPreferences with comprehensive error handling
  static Future<bool> saveEmployeeDataToPrefs(
      Map<String, dynamic> employee, String accessToken, String instanceUrl) async {
    _logger.i('Saving employee data to SharedPreferences');

    try {
      final prefs = await SharedPreferences.getInstance();

      // Extract data with null safety and proper conversion
      final employeeId = employee['Id']?.toString() ?? '';
      final firstName = employee['First_Name__c']?.toString() ?? '';
      final lastName = employee['Last_Name__c']?.toString() ?? '';
      final email = employee['Email__c']?.toString() ?? '';

      _logger.i('Processing employee data: ID=$employeeId, Name=$firstName $lastName, Email=$email');

      // Validate required fields
      if (employeeId.isEmpty) {
        _logger.w('Employee ID is empty');
      }
      if (firstName.isEmpty) {
        _logger.w('First name is empty');
      }
      if (lastName.isEmpty) {
        _logger.w('Last name is empty');
      }
      if (email.isEmpty) {
        _logger.w('Email is empty');
      }

      // Save all employee and session data
      final saveResults = await Future.wait([
        prefs.setString('employee_id', employeeId),
        prefs.setString('current_employee_id', employeeId),
        prefs.setString('first_name', firstName),
        prefs.setString('last_name', lastName),
        prefs.setString('user_email', email),
        prefs.setString('access_token', accessToken),
        prefs.setString('instance_url', instanceUrl),
      ]);

      // Check if all saves were successful
      final allSaved = saveResults.every((result) => result == true);

      if (allSaved) {
        _logger.i('✅ All employee data saved successfully');
        _logger.i('Saved data: employeeId=$employeeId, firstName=$firstName, lastName=$lastName, email=$email');

        // Verify the data was saved by reading it back
        await _verifyDataSaved(prefs, employeeId, firstName, lastName, email);
        return true;
      } else {
        _logger.e('❌ Some data failed to save');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Error saving employee data: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Verify that data was properly saved by reading it back
  static Future<void> _verifyDataSaved(SharedPreferences prefs, String employeeId,
      String firstName, String lastName, String email) async {
    try {
      final savedEmployeeId = prefs.getString('employee_id') ?? '';
      final savedFirstName = prefs.getString('first_name') ?? '';
      final savedLastName = prefs.getString('last_name') ?? '';
      final savedEmail = prefs.getString('user_email') ?? '';

      _logger.i('Verification - Saved vs Expected:');
      _logger.i('EmployeeId: "$savedEmployeeId" vs "$employeeId" ${savedEmployeeId == employeeId ? '✅' : '❌'}');
      _logger.i('FirstName: "$savedFirstName" vs "$firstName" ${savedFirstName == firstName ? '✅' : '❌'}');
      _logger.i('LastName: "$savedLastName" vs "$lastName" ${savedLastName == lastName ? '✅' : '❌'}');
      _logger.i('Email: "$savedEmail" vs "$email" ${savedEmail == email ? '✅' : '❌'}');
    } catch (e) {
      _logger.e('Error verifying saved data: $e');
    }
  }

  /// Get employee data from SharedPreferences
  static Future<Map<String, String?>> getEmployeeDataFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final data = {
        'employee_id': prefs.getString('employee_id'),
        'first_name': prefs.getString('first_name'),
        'last_name': prefs.getString('last_name'),
        'user_email': prefs.getString('user_email'),
        'access_token': prefs.getString('access_token'),
        'instance_url': prefs.getString('instance_url'),
      };

      _logger.i('Retrieved employee data from SharedPreferences:');
      data.forEach((key, value) {
        _logger.i('$key: ${value ?? 'null'}');
      });

      return data;
    } catch (e, stackTrace) {
      _logger.e('Error getting employee data: $e', error: e, stackTrace: stackTrace);
      return {};
    }
  }

  /// Clear all employee data from SharedPreferences
  static Future<bool> clearEmployeeDataFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final keysToRemove = [
        'employee_id',
        'current_employee_id',
        'first_name',
        'last_name',
        'user_email',
        'access_token',
        'instance_url',
        'remember_me_timestamp', // Add remember me to clear list
      ];

      for (String key in keysToRemove) {
        await prefs.remove(key);
      }

      _logger.i('✅ All employee data cleared from SharedPreferences');
      return true;
    } catch (e, stackTrace) {
      _logger.e('❌ Error clearing employee data: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Check if remember me is valid and return stored employee data if valid
  static Future<Map<String, String>?> checkRememberMeStatus() async {
    _logger.i('Checking remember me status');

    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMeTimestamp = prefs.getInt('remember_me_timestamp');

      if (rememberMeTimestamp != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final daysPassed = (now - rememberMeTimestamp) / (1000 * 60 * 60 * 24);

        _logger.i('Remember me found, days passed: $daysPassed');

        if (daysPassed < 45) {
          final employeeId = prefs.getString('employee_id') ?? '';
          final firstName = prefs.getString('first_name') ?? '';
          final lastName = prefs.getString('last_name') ?? '';

          _logger.i('Remember me is valid - employeeId=$employeeId, firstName=$firstName, lastName=$lastName');

          if (employeeId.isNotEmpty && firstName.isNotEmpty && lastName.isNotEmpty) {
            return {
              'employee_id': employeeId,
              'first_name': firstName,
              'last_name': lastName,
            };
          } else {
            _logger.w('Remember me data is incomplete, clearing...');
            await clearRememberMeData();
            return null;
          }
        } else {
          _logger.i('Remember me expired (${daysPassed.toStringAsFixed(1)} days), clearing stored data');
          await clearRememberMeData();
          return null;
        }
      } else {
        _logger.i('No remember me data found');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error checking remember me status: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Save remember me status with employee data
  static Future<bool> saveRememberMeStatus(String employeeId, String firstName, String lastName) async {
    _logger.i('Saving remember me status: employeeId=$employeeId');

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

      final saveResults = await Future.wait([
        prefs.setInt('remember_me_timestamp', currentTimestamp),
        prefs.setString('employee_id', employeeId),
        prefs.setString('first_name', firstName),
        prefs.setString('last_name', lastName),
      ]);

      final allSaved = saveResults.every((result) => result == true);

      if (allSaved) {
        _logger.i('✅ Remember me data saved successfully');
        return true;
      } else {
        _logger.e('❌ Some remember me data failed to save');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Error saving remember me data: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Clear remember me data specifically
  static Future<bool> clearRememberMeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final rememberMeKeys = [
        'remember_me_timestamp',
        'employee_id',
        'first_name',
        'last_name',
      ];

      for (String key in rememberMeKeys) {
        await prefs.remove(key);
      }

      _logger.i('✅ Remember me data cleared successfully');
      return true;
    } catch (e, stackTrace) {
      _logger.e('❌ Error clearing remember me data: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Debug method to print all SharedPreferences data
  static Future<void> debugPrintAllPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      _logger.i('🔍 All SharedPreferences data:');
      for (String key in keys) {
        final value = prefs.get(key);
        _logger.i('  $key: $value');
      }
    } catch (e) {
      _logger.e('Error debugging SharedPreferences: $e');
    }
  }
}