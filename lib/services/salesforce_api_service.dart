import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class SalesforceApiService {
  static final Logger _logger = Logger();

  // Update the getEmployeeByEmail method in SalesforceApiService
  static Future<Map<String, dynamic>?> getEmployeeByEmail(
      String accessToken,
      String instanceUrl,
      String email
      ) async {
    _logger.i('Starting getEmployeeByEmail for: $email');

    try {
      // Updated SOQL query to include Password__c field
      final query = "SELECT Id, Name, First_Name__c, Last_Name__c, Email__c, Password__c FROM Employee__c WHERE Email__c = '$email' LIMIT 1";
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$instanceUrl/services/data/v52.0/query/?q=$encodedQuery';

      _logger.i('Querying Salesforce for employee with email: $email');
      _logger.i('Query URL: $url');
      _logger.d('Query: $query');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _logger.e('Employee query request timed out for email: $email');
          throw TimeoutException('Employee query request timed out', const Duration(seconds: 30));
        },
      );

      _logger.i('Response status: ${response.statusCode}');
      _logger.d('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List;

        if (records.isNotEmpty) {
          final employee = records.first;
          _logger.i('Employee found: ${employee['Name']} with ID: ${employee['Id']}');
          _logger.d('Employee details: $employee');
          return employee;
        } else {
          _logger.w('No employee found with email: $email');
          return null;
        }
      } else {
        _logger.e('Failed to query employee: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on TimeoutException catch (e) {
      _logger.e('Employee query timeout: $e');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error querying employee: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> getAllEmployees(
      String accessToken,
      String instanceUrl
      ) async {
    _logger.i('Starting getAllEmployees');

    try {
      final query = "SELECT Id, Name, First_Name__c, Last_Name__c, Email__c FROM Employee__c";
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$instanceUrl/services/data/v52.0/query/?q=$encodedQuery';

      _logger.i('Query URL: $url');
      _logger.d('Query: $query');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _logger.e('Get all employees request timed out');
          throw TimeoutException('Get all employees request timed out', const Duration(seconds: 30));
        },
      );

      _logger.i('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List;
        _logger.i('Successfully retrieved ${records.length} employees');
        return records.cast<Map<String, dynamic>>();
      } else {
        _logger.e('Failed to get all employees: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on TimeoutException catch (e) {
      _logger.e('Get all employees timeout: $e');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error getting all employees: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}