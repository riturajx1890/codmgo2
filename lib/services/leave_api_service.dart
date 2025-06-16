import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class LeaveApiService {
  static const String _apiVersion = 'v60.0';
  static final Logger _logger = Logger();

  // Leave types enum for better type safety
  static const Map<String, String> leaveTypes = {
    'casual': 'Casual Leave',
    'halfDay': 'Half-Day Leave',
    'oneDay': 'One Day Leave',
    'sick': 'Sick Leave/ Medical Leave',
  };

  /// Fetches leave records for a specific employee using Employee__c ID.
  static Future<List<Map<String, dynamic>>?> getLeavesByEmployee(
      String accessToken,
      String instanceUrl,
      String employeeId,
      ) async {
    _logger.i('Fetching leave records for employee: $employeeId');

    final query =
        "SELECT Id, Name, Employee__c, Leave_Type__c, Start_Date__c, End_Date__c, Description__c, LastModifiedById, CreatedDate FROM Leave__c WHERE Employee__c = '$employeeId' ORDER BY CreatedDate DESC";
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
          _logger.i('Fetched ${records.length} leave records for employee: $employeeId');
          return List<Map<String, dynamic>>.from(records);
        } else {
          _logger.w('No leave records found for employee: $employeeId');
          return [];
        }
      } else {
        _logger.e('Failed to fetch leave records for employee. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching leave records for employee: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Creates a new leave request.
  static Future<String?> createLeaveRequest(
      String accessToken,
      String instanceUrl,
      String employeeId,
      String leaveType,
      DateTime startDate,
      DateTime? endDate,
      String? description,
      ) async {
    _logger.i('Creating leave request for employee: $employeeId');
    _logger.i('Leave type: $leaveType');
    _logger.i('Start date: ${startDate.toIso8601String()}');
    _logger.i('End date: ${endDate?.toIso8601String() ?? 'Same as start date'}');

    final url = Uri.parse('$instanceUrl/services/data/$_apiVersion/sobjects/Leave__c');

    // Prepare the request body
    final Map<String, dynamic> requestBody = {
      'Employee__c': employeeId,
      'Leave_Type__c': leaveType,
      'Start_Date__c': startDate.toIso8601String().split('T')[0], // Date only format
    };

    // Add end date if provided, otherwise use start date
    if (endDate != null) {
      requestBody['End_Date__c'] = endDate.toIso8601String().split('T')[0];
    } else {
      requestBody['End_Date__c'] = startDate.toIso8601String().split('T')[0];
    }

    // Add description if provided
    if (description != null && description.isNotEmpty) {
      requestBody['Description__c'] = description;
    }

    final body = json.encode(requestBody);

    _logger.i('Leave request URL: $url');
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

      _logger.i('Leave request response status: ${response.statusCode}');
      _logger.d('Leave request response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final recordId = data['id'];
        _logger.i('Leave request created successfully. Record ID: $recordId');
        return recordId;
      } else {
        _logger.e('Failed to create leave request. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error creating leave request: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Updates an existing leave request.
  static Future<bool> updateLeaveRequest(
      String accessToken,
      String instanceUrl,
      String leaveRecordId,
      String? leaveType,
      DateTime? startDate,
      DateTime? endDate,
      String? description,
      ) async {
    _logger.i('Updating leave request: $leaveRecordId');

    final url = Uri.parse('$instanceUrl/services/data/$_apiVersion/sobjects/Leave__c/$leaveRecordId');

    // Prepare the request body with only provided fields
    final Map<String, dynamic> requestBody = {};

    if (leaveType != null) {
      requestBody['Leave_Type__c'] = leaveType;
      _logger.i('Updating leave type to: $leaveType');
    }

    if (startDate != null) {
      requestBody['Start_Date__c'] = startDate.toIso8601String().split('T')[0];
      _logger.i('Updating start date to: ${startDate.toIso8601String()}');
    }

    if (endDate != null) {
      requestBody['End_Date__c'] = endDate.toIso8601String().split('T')[0];
      _logger.i('Updating end date to: ${endDate.toIso8601String()}');
    }

    if (description != null) {
      requestBody['Description__c'] = description;
      _logger.i('Updating description');
    }

    if (requestBody.isEmpty) {
      _logger.w('No fields to update for leave request: $leaveRecordId');
      return false;
    }

    final body = json.encode(requestBody);

    _logger.i('Update leave request URL: $url');
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

      _logger.i('Update leave request response status: ${response.statusCode}');
      _logger.d('Update leave request response body: ${response.body}');

      if (response.statusCode == 204) {
        _logger.i('Leave request updated successfully for record ID: $leaveRecordId');
        return true;
      } else {
        _logger.e('Failed to update leave request. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating leave request: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Deletes a leave request.
  static Future<bool> deleteLeaveRequest(
      String accessToken,
      String instanceUrl,
      String leaveRecordId,
      ) async {
    _logger.i('Deleting leave request: $leaveRecordId');

    final url = Uri.parse('$instanceUrl/services/data/$_apiVersion/sobjects/Leave__c/$leaveRecordId');

    _logger.i('Delete leave request URL: $url');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      _logger.i('Delete leave request response status: ${response.statusCode}');
      _logger.d('Delete leave request response body: ${response.body}');

      if (response.statusCode == 204) {
        _logger.i('Leave request deleted successfully for record ID: $leaveRecordId');
        return true;
      } else {
        _logger.e('Failed to delete leave request. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting leave request: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Gets leave requests for a specific date range.
  static Future<List<Map<String, dynamic>>?> getLeavesByDateRange(
      String accessToken,
      String instanceUrl,
      String employeeId,
      DateTime startDate,
      DateTime endDate,
      ) async {
    _logger.i('Fetching leave records for employee: $employeeId');
    _logger.i('Date range: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');

    final startDateStr = startDate.toIso8601String().split('T')[0];
    final endDateStr = endDate.toIso8601String().split('T')[0];

    final query =
        "SELECT Id, Name, Employee__c, Leave_Type__c, Start_Date__c, End_Date__c, Description__c, LastModifiedById, CreatedDate FROM Leave__c WHERE Employee__c = '$employeeId' AND Start_Date__c >= $startDateStr AND End_Date__c <= $endDateStr ORDER BY Start_Date__c DESC";
    final encodedQuery = Uri.encodeComponent(query);

    final url =
    Uri.parse('$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery');

    _logger.i('Date range query URL: $url');
    _logger.d('Query: $query');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      _logger.i('Date range response status: ${response.statusCode}');
      _logger.d('Date range response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'];

        if (records != null && records.isNotEmpty) {
          _logger.i('Fetched ${records.length} leave records for date range');
          return List<Map<String, dynamic>>.from(records);
        } else {
          _logger.w('No leave records found for the specified date range');
          return [];
        }
      } else {
        _logger.e('Failed to fetch leave records for date range. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching leave records for date range: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Gets today's leave requests for a specific employee.
  static Future<List<Map<String, dynamic>>?> getTodayLeaves(
      String accessToken,
      String instanceUrl,
      String employeeId,
      ) async {
    _logger.i('Fetching today\'s leave requests for employee: $employeeId');

    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T')[0];

    final query =
        "SELECT Id, Name, Employee__c, Leave_Type__c, Start_Date__c, End_Date__c, Description__c, LastModifiedById, CreatedDate FROM Leave__c WHERE Employee__c = '$employeeId' AND Start_Date__c <= $todayStr AND End_Date__c >= $todayStr ORDER BY CreatedDate DESC";
    final encodedQuery = Uri.encodeComponent(query);

    final url =
    Uri.parse('$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery');

    _logger.i('Today\'s leave query URL: $url');
    _logger.d('Query: $query');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      _logger.i('Today\'s leave response status: ${response.statusCode}');
      _logger.d('Today\'s leave response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'];

        if (records != null && records.isNotEmpty) {
          _logger.i('Found ${records.length} leave request(s) for today');
          return List<Map<String, dynamic>>.from(records);
        } else {
          _logger.w('No leave requests found for today for employee: $employeeId');
          return [];
        }
      } else {
        _logger.e('Failed to fetch today\'s leave requests. Status: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching today\'s leave requests: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Quick method to apply for different types of leave.
  static Future<String> quickLeaveRequest(
      String accessToken,
      String instanceUrl,
      String employeeId,
      String leaveTypeKey,
      DateTime startDate,
      DateTime? endDate,
      String? description,
      ) async {
    _logger.i('Starting quick leave request for employee: $employeeId');
    _logger.i('Leave type key: $leaveTypeKey');

    try {
      // Validate leave type
      if (!leaveTypes.containsKey(leaveTypeKey)) {
        _logger.e('Invalid leave type key: $leaveTypeKey');
        return '❌ Invalid leave type. Available types: ${leaveTypes.keys.join(', ')}';
      }

      final leaveTypeName = leaveTypes[leaveTypeKey]!;
      _logger.i('Leave type name: $leaveTypeName');

      // For half-day leave, ensure it's only for one day
      if (leaveTypeKey == 'halfDay' && endDate != null && !_isSameDay(startDate, endDate)) {
        _logger.w('Half-day leave cannot span multiple days');
        return '❌ Half-day leave can only be applied for a single day';
      }

      // For one-day leave, ensure it's only for one day
      if (leaveTypeKey == 'oneDay' && endDate != null && !_isSameDay(startDate, endDate)) {
        _logger.w('One-day leave cannot span multiple days');
        return '❌ One-day leave can only be applied for a single day';
      }

      final recordId = await createLeaveRequest(
        accessToken,
        instanceUrl,
        employeeId,
        leaveTypeName,
        startDate,
        endDate,
        description,
      );

      if (recordId != null) {
        _logger.i('Leave request created successfully with ID: $recordId');
        final dateRange = endDate != null && !_isSameDay(startDate, endDate)
            ? '${_formatDate(startDate)} to ${_formatDate(endDate)}'
            : _formatDate(startDate);
        return '✅ $leaveTypeName request submitted successfully for $dateRange';
      } else {
        _logger.e('Failed to create leave request');
        return '❌ Failed to submit leave request';
      }
    } catch (e, stackTrace) {
      _logger.e('Error in quick leave request: $e', error: e, stackTrace: stackTrace);
      return '⚠️ Error occurred while submitting leave request';
    }
  }

  /// Helper method to check if two dates are the same day.
  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Helper method to format date for display.
  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Gets leave balance or summary (if your Salesforce org has such functionality).
  /// This is a placeholder method - you'll need to implement based on your org's structure.
  static Future<Map<String, dynamic>?> getLeaveBalance(
      String accessToken,
      String instanceUrl,
      String employeeId,
      ) async {
    _logger.i('Fetching leave balance for employee: $employeeId');

    // This would typically query a leave balance object or calculate from existing leaves
    // Implementation depends on your Salesforce org's structure
    _logger.w('Leave balance functionality not implemented - depends on org structure');
    return null;
  }
}