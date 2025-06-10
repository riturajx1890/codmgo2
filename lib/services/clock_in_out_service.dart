import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class ClockInOutService {
  static const String _apiVersion = 'v60.0';
  static final Logger _logger = Logger();

  /// Fetches attendance records for a specific employee using Employee__c ID.
  static Future<List<Map<String, dynamic>>?> getAttendanceByEmployee(
      String accessToken,
      String instanceUrl,
      String employeeId,
      ) async {
    _logger.i('Fetching attendance records for employee: $employeeId');

    final query =
        "SELECT Id, In_Time__c, Out_Time__c, CreatedDate, Name, Employee__c, Total_Time__c FROM Attendance__c WHERE Employee__c = '$employeeId' ORDER BY CreatedDate DESC";
    final encodedQuery = Uri.encodeComponent(query);

    final url =
    Uri.parse('$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery');

    _logger.i('Query URL: $url');
    _logger.d('Query: $query');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      _logger.i('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'];

        if (records != null && records.isNotEmpty) {
          _logger.i('Fetched ${records.length} attendance records for employee: $employeeId');
          return List<Map<String, dynamic>>.from(records);
        } else {
          _logger.w('No attendance records found for employee: $employeeId');
          return [];
        }
      } else {
        _logger.e('Failed to fetch attendance records for employee. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching attendance records for employee: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Creates a new attendance record (Clock In).
  static Future<String?> clockIn(
      String accessToken,
      String instanceUrl,
      String employeeId,
      DateTime inTime,
      ) async {
    _logger.i('Starting clock in process for employee: $employeeId');
    _logger.i('Clock in time: ${inTime.toIso8601String()}');

    final url = Uri.parse('$instanceUrl/services/data/$_apiVersion/sobjects/Attendance__c');

    final body = json.encode({
      'Employee__c': employeeId,
      'In_Time__c': inTime.toIso8601String(),
    });

    _logger.i('Clock in request URL: $url');
    _logger.d('Request body: $body');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      _logger.i('Clock in response status: ${response.statusCode}');
      _logger.d('Clock in response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final recordId = data['id'];
        _logger.i('Clock in successful. Record ID: $recordId');
        return recordId;
      } else {
        _logger.e('Failed to clock in. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error during clock in: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Updates an existing attendance record (Clock Out).
  static Future<bool> clockOut(
      String accessToken,
      String instanceUrl,
      String attendanceRecordId,
      DateTime outTime,
      ) async {
    _logger.i('Starting clock out process for attendance record: $attendanceRecordId');
    _logger.i('Clock out time: ${outTime.toIso8601String()}');

    final utcOutTime = outTime.toUtc();
    _logger.i('Clock out time (UTC): ${utcOutTime.toIso8601String()}');
    _logger.i('Clock out time (Local): ${outTime.toLocal().toString()}');

    final url = Uri.parse('$instanceUrl/services/data/$_apiVersion/sobjects/Attendance__c/$attendanceRecordId');

    final body = json.encode({
      'Out_Time__c': outTime.toIso8601String(),
    });

    _logger.i('Clock out request URL: $url');
    _logger.d('Request body: $body');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      _logger.i('Clock out response status: ${response.statusCode}');
      _logger.d('Clock out response body: ${response.body}');

      if (response.statusCode == 204) {
        _logger.i('Clock out successful for record ID: $attendanceRecordId');
        return true;
      } else {
        _logger.e('Failed to clock out. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Error during clock out: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Gets today's attendance record for a specific employee.
  static Future<Map<String, dynamic>?> getTodayAttendance(
      String accessToken,
      String instanceUrl,
      String employeeId,
      ) async {
    _logger.i('Fetching today\'s attendance for employee: $employeeId');

    final today = DateTime.now().toUtc();
    final todayStart = DateTime.utc(today.year, today.month, today.day);
    final todayEnd = todayStart.add(Duration(days: 1));

    _logger.i('Today\'s date range: ${todayStart.toIso8601String()} to ${todayEnd.toIso8601String()}');

    final query =
        "SELECT Id, In_Time__c, Out_Time__c, CreatedDate, Name, Employee__c, Total_Time__c FROM Attendance__c WHERE Employee__c = '$employeeId' AND CreatedDate >= ${todayStart.toIso8601String()} AND CreatedDate < ${todayEnd.toIso8601String()} ORDER BY CreatedDate DESC LIMIT 1";
    final encodedQuery = Uri.encodeComponent(query);

    final url =
    Uri.parse('$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery');

    _logger.i('Today\'s attendance query URL: $url');
    _logger.d('Query: $query');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      _logger.i('Today\'s attendance response status: ${response.statusCode}');
      _logger.d('Today\'s attendance response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'];

        if (records != null && records.isNotEmpty) {
          final attendanceRecord = records[0];
          _logger.i('Today\'s attendance record found: ${attendanceRecord['Id']}');
          _logger.i('In Time: ${attendanceRecord['In_Time__c']}, Out Time: ${attendanceRecord['Out_Time__c']}');
          return attendanceRecord;
        } else {
          _logger.w('No attendance record found for today for employee: $employeeId');
          return null;
        }
      } else {
        _logger.e('Failed to fetch today\'s attendance. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching today\'s attendance: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Handles the full process: clock in if not already, otherwise clock out if in.
  static Future<String> handleAttendance(
      String accessToken,
      String instanceUrl,
      String employeeId,
      ) async {
    _logger.i('Starting handleAttendance for employee: $employeeId');

    final nowUtc = DateTime.now().toUtc();
    _logger.i('Current UTC time: ${nowUtc.toIso8601String()}');

    try {
      _logger.i('Checking today\'s attendance status...');
      final todayRecord = await getTodayAttendance(accessToken, instanceUrl, employeeId);

      if (todayRecord == null) {
        // No record → Clock In
        _logger.i('No today\'s record found, attempting clock in...');
        final newId = await clockIn(accessToken, instanceUrl, employeeId, nowUtc);
        if (newId != null) {
          _logger.i('Successfully clocked in with record ID: $newId');
          return 'Clocked In at ${nowUtc.toLocal()}';
        } else {
          _logger.e('Failed to clock in');
          return '❌ Failed to Clock In';
        }
      } else if (todayRecord['Out_Time__c'] == null) {
        // Already clocked in, now clock out
        _logger.i('Already clocked in, attempting clock out...');
        final recordId = todayRecord['Id'];
        final success = await clockOut(accessToken, instanceUrl, recordId, nowUtc);
        if (success) {
          _logger.i('Successfully clocked out');
          return 'Clocked Out at ${nowUtc.toLocal()}';
        } else {
          _logger.e('Failed to clock out');
          return '❌ Failed to Clock Out';
        }
      } else {
        // Already completed
        _logger.i('Attendance already completed for today');
        return '✅ Attendance already completed today';
      }
    } catch (e, stackTrace) {
      _logger.e('Error handling attendance flow: $e', error: e, stackTrace: stackTrace);
      return '⚠️ Error occurred while handling attendance';
    }
  }
}