import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class SharedPrefsUtils {
  static final Logger _logger = Logger();

  static Future<void> saveEmployeeDataToPrefs(
      Map<String, dynamic> employee, String accessToken, String instanceUrl) async {
    _logger.i('Saving employee data to SharedPreferences');

    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeId = employee['Id']?.toString() ?? '';
      final firstName = employee['First_Name__c']?.toString() ?? '';
      final lastName = employee['Last_Name__c']?.toString() ?? '';
      final email = employee['Email__c']?.toString() ?? '';

      // Save all employee and session data
      await prefs.setString('employee_id', employeeId);
      await prefs.setString('current_employee_id', employeeId);
      await prefs.setString('first_name', firstName);
      await prefs.setString('last_name', lastName);
      await prefs.setString('user_email', email);
      await prefs.setString('access_token', accessToken);
      await prefs.setString('instance_url', instanceUrl);

      _logger.i('Employee data saved: employeeId=$employeeId, firstName=$firstName, lastName=$lastName, email=$email');
    } catch (e, stackTrace) {
      _logger.e('Error saving employee data: $e', error: e, stackTrace: stackTrace);
    }
  }
}