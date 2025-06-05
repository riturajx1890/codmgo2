import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class ClockInOutService {
  static const String _apiVersion = 'v60.0';
  static final Logger _logger = Logger();

  /// Fetch today's attendance for the employee
  static Future<Map<String, dynamic>?> fetchTodayAttendance({
    required String accessToken,
    required String instanceUrl,
    required String employeeId,
  }) async {
    final today = DateTime.now().toUtc();
    final todayStr = today.toIso8601String().substring(0, 10); // YYYY-MM-DD

    final query =
        "SELECT Id, In_Time__c, Out_Time__c, CreatedDate, Name, Employee__c, Total_Time__c "
        "FROM Attendance__c "
        "WHERE Employee__c = '$employeeId' "
        "AND CreatedDate = TODAY";

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
          return records[0];
        }
      } else {
        _logger.e('Fetch attendance failed: ${response.statusCode}');
        _logger.e(response.body);
      }
    } catch (e, st) {
      _logger.e('Error fetching attendance', error: e, stackTrace: st);
    }

    return null;
  }

  /// Clock in: create a new Attendance__c record
  static Future<bool> clockIn({
    required String accessToken,
    required String instanceUrl,
    required String employeeId,
    required String inTime,
  }) async {
    final url = Uri.parse('$instanceUrl/services/data/$_apiVersion/sobjects/Attendance__c/');

    final body = json.encode({
      'Employee__c': employeeId,
      'In_Time__c': inTime,
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
        return true;
      } else {
        _logger.e('Clock In failed: ${response.statusCode}');
        _logger.e(response.body);
      }
    } catch (e, st) {
      _logger.e('Error during clock in', error: e, stackTrace: st);
    }

    return false;
  }

  /// Clock out: update an existing Attendance__c record
  static Future<bool> clockOut({
    required String accessToken,
    required String instanceUrl,
    required String attendanceId,
    required String outTime,
  }) async {
    final url = Uri.parse('$instanceUrl/services/data/$_apiVersion/sobjects/Attendance__c/$attendanceId');

    final body = json.encode({
      'Out_Time__c': outTime,
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
        return true;
      } else {
        _logger.e('Clock Out failed: ${response.statusCode}');
        _logger.e(response.body);
      }
    } catch (e, st) {
      _logger.e('Error during clock out', error: e, stackTrace: st);
    }

    return false;
  }
}
