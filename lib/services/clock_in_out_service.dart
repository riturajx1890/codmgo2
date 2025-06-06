import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class ClockInOutService {
  static const String _apiVersion = 'v60.0';
  static final Logger _logger = Logger();

  /// Fetches all attendance records from the Salesforce Attendance__c object.
  static Future<List<Map<String, dynamic>>?> getAllAttendanceRecords(
      String accessToken,
      String instanceUrl,
      ) async {
    final query =
        "SELECT Id, In_Time__c, Out_Time__c, CreatedDate, Name, Employee__c, Total_Time__c FROM Attendance__c";
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
          return List<Map<String, dynamic>>.from(records);
        } else {
          _logger.w('No attendance records found');
        }
      } else {
        _logger.e('Failed to fetch attendance records. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching attendance records', error: e, stackTrace: stackTrace);
    }

    return null;
  }

  /// Fetches attendance records for a specific employee from the Salesforce Attendance__c object.
  static Future<List<Map<String, dynamic>>?> getAttendanceByEmployee(
      String accessToken,
      String instanceUrl,
      String employeeId,
      ) async {
    final query =
        "SELECT Id, In_Time__c, Out_Time__c, CreatedDate, Name, Employee__c, Total_Time__c FROM Attendance__c WHERE Employee__c = '$employeeId'";
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
          return List<Map<String, dynamic>>.from(records);
        } else {
          _logger.w('No attendance records found for employee: $employeeId');
        }
      } else {
        _logger.e('Failed to fetch attendance records for employee. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching attendance records for employee', error: e, stackTrace: stackTrace);
    }

    return null;
  }

  /// Creates a new attendance record (Clock In) in Salesforce Attendance__c object.
  static Future<String?> clockIn(
      String accessToken,
      String instanceUrl,
      String employeeId,
      DateTime inTime,
      ) async {
    final url = Uri.parse('$instanceUrl/services/data/$_apiVersion/sobjects/Attendance__c');

    final body = json.encode({
      'Employee__c': employeeId,
      'In_Time__c': inTime.toIso8601String(),
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _logger.i('Clock in successful. Record ID: ${data['id']}');
        return data['id'];
      } else {
        _logger.e('Failed to clock in. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error during clock in', error: e, stackTrace: stackTrace);
    }

    return null;
  }

  /// Updates an existing attendance record (Clock Out) in Salesforce Attendance__c object.
  static Future<bool> clockOut(
      String accessToken,
      String instanceUrl,
      String attendanceRecordId,
      DateTime outTime,
      ) async {
    final url = Uri.parse('$instanceUrl/services/data/$_apiVersion/sobjects/Attendance__c/$attendanceRecordId');

    final body = json.encode({
      'Out_Time__c': outTime.toIso8601String(),
    });

    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 204) {
        _logger.i('Clock out successful for record ID: $attendanceRecordId');
        return true;
      } else {
        _logger.e('Failed to clock out. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error during clock out', error: e, stackTrace: stackTrace);
    }

    return false;
  }

  /// Gets today's attendance record for a specific employee.
  static Future<Map<String, dynamic>?> getTodayAttendance(
      String accessToken,
      String instanceUrl,
      String employeeId,
      ) async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(Duration(days: 1));

    final query =
        "SELECT Id, In_Time__c, Out_Time__c, CreatedDate, Name, Employee__c, Total_Time__c FROM Attendance__c WHERE Employee__c = '$employeeId' AND CreatedDate >= ${todayStart.toIso8601String()} AND CreatedDate < ${todayEnd.toIso8601String()}";
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
          return records[0]; // Return today's attendance record
        } else {
          _logger.w('No attendance record found for today for employee: $employeeId');
        }
      } else {
        _logger.e('Failed to fetch today\'s attendance. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching today\'s attendance', error: e, stackTrace: stackTrace);
    }

    return null;
  }
}