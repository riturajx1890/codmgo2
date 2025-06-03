import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class SalesforceApiService {
  static const String _apiVersion = 'v60.0';
  static final Logger _logger = Logger();

  /// Fetches an employee record by email from the Salesforce Employee__c object.
  static Future<Map<String, dynamic>?> getEmployeeByEmail(
      String accessToken,
      String instanceUrl,
      String email,
      ) async {
    final query =
        "SELECT First_Name__c, Last_Name__c, Email__c FROM Employee__c WHERE Email__c = '$email'";
    final encodedQuery = Uri.encodeComponent(query);

    final url = Uri.parse('$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'];

        if (records != null && records.isNotEmpty) {
          return records[0]; // Return the first matching employee
        } else {
          _logger.w('No matching employee found for email: $email');
        }
      } else {
        _logger.e('Failed to fetch employee. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching employee by email', error: e, stackTrace: stackTrace);
    }

    return null;
  }
}
