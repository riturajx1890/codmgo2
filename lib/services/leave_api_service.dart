import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:codmgo2/utils/shared_prefs_utils.dart';

class LeaveApiService {
  static const String _apiVersion = 'v60.0';
  static final Logger _logger = Logger();

  /// Enhanced method to get credentials automatically
  static Future<Map<String, String>?> _getValidCredentials() async {
    try {
      _logger.i('Getting valid credentials for API call');
      return await SharedPrefsUtils.getValidCredentialsWithEmployeeId();
    } catch (e, stackTrace) {
      _logger.e('Error getting valid credentials: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Get all leaves for the current employee
  static Future<List<Map<String, dynamic>>?> getEmployeeLeaves() async {
    try {
      _logger.i('Fetching employee leaves');

      final credentials = await _getValidCredentials();
      if (credentials == null) {
        _logger.e('Failed to get valid credentials');
        return null;
      }

      final employeeId = credentials['employee_id']!;
      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      // SOQL query to get leaves for the current employee
      final query = '''
        SELECT Name, Employee__c, End_Date__c, Description__c, Leave_Type__c, Start_Date__c, Status__c 
        FROM Leave__c 
        WHERE Employee__c = '$employeeId' 
        ORDER BY Start_Date__c DESC
      ''';

      final encodedQuery = Uri.encodeComponent(query);
      final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

      _logger.i('Making API call to: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      _logger.i('API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List<dynamic>?;

        if (records != null) {
          _logger.i('Successfully fetched ${records.length} leave records');
          return records.cast<Map<String, dynamic>>();
        } else {
          _logger.w('No leave records found');
          return [];
        }
      } else {
        _logger.e('Failed to fetch leaves. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching employee leaves: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Get employee details including leave balance and designation
  static Future<Map<String, dynamic>?> getEmployeeDetails() async {
    try {
      _logger.i('Fetching employee details');

      final credentials = await _getValidCredentials();
      if (credentials == null) {
        _logger.e('Failed to get valid credentials');
        return null;
      }

      final employeeId = credentials['employee_id']!;
      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      // SOQL query to get employee details
      final query = '''
        SELECT Leave_Balance__c, Leave_Balance_Formula__c, Designation__c, Id, Name 
        FROM Employee__c 
        WHERE Id = '$employeeId'
      ''';

      final encodedQuery = Uri.encodeComponent(query);
      final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

      _logger.i('Making API call to: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      _logger.i('API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List<dynamic>?;

        if (records != null && records.isNotEmpty) {
          final employeeData = records.first as Map<String, dynamic>;
          _logger.i('Successfully fetched employee details for: ${employeeData['Name']}');
          return employeeData;
        } else {
          _logger.w('No employee record found');
          return null;
        }
      } else {
        _logger.e('Failed to fetch employee details. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching employee details: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Create a new leave request
  static Future<bool> createLeaveRequest({
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String description,
    String status = 'Pending', // Default status is Pending
  }) async {
    try {
      _logger.i('Creating leave request');

      final credentials = await _getValidCredentials();
      if (credentials == null) {
        _logger.e('Failed to get valid credentials');
        return false;
      }

      final employeeId = credentials['employee_id']!;
      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      final leaveData = {
        'Employee__c': employeeId,
        'Leave_Type__c': leaveType,
        'Start_Date__c': startDate.toIso8601String().split('T')[0], // Format: YYYY-MM-DD
        'End_Date__c': endDate.toIso8601String().split('T')[0], // Format: YYYY-MM-DD
        'Description__c': description,
        'Status__c': status,
      };

      final url = '$instanceUrl/services/data/$_apiVersion/sobjects/Leave__c/';

      _logger.i('Making POST request to: $url');
      _logger.i('Leave data: $leaveData');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(leaveData),
      );

      _logger.i('API Response Status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final leaveId = responseData['id'];
        _logger.i('Successfully created leave request with ID: $leaveId');
        return true;
      } else {
        _logger.e('Failed to create leave request. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Error creating leave request: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Update leave status (for approvers)
  static Future<bool> updateLeaveStatus({
    required String leaveId,
    required String status, // 'Approved', 'Pending', or 'Rejected'
  }) async {
    try {
      _logger.i('Updating leave status to: $status');

      final credentials = await _getValidCredentials();
      if (credentials == null) {
        _logger.e('Failed to get valid credentials');
        return false;
      }

      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      final updateData = {
        'Status__c': status,
      };

      final url = '$instanceUrl/services/data/$_apiVersion/sobjects/Leave__c/$leaveId';

      _logger.i('Making PATCH request to: $url');

      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(updateData),
      );

      _logger.i('API Response Status: ${response.statusCode}');

      if (response.statusCode == 204) {
        _logger.i('Successfully updated leave status to: $status');
        return true;
      } else {
        _logger.e('Failed to update leave status. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating leave status: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get leaves that need approval (for managers/approvers)
  static Future<List<Map<String, dynamic>>?> getLeavesForApproval() async {
    try {
      _logger.i('Fetching leaves for approval');

      final credentials = await _getValidCredentials();
      if (credentials == null) {
        _logger.e('Failed to get valid credentials');
        return null;
      }

      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      // Get current employee's designation first
      final employeeDetails = await getEmployeeDetails();
      if (employeeDetails == null) {
        _logger.e('Failed to get employee details for approval check');
        return null;
      }

      final designation = employeeDetails['Designation__c'];
      _logger.i('Current employee designation: $designation');

      // SOQL query to get pending leaves
      final query = '''
        SELECT Id, Name, Employee__c, End_Date__c, Description__c, Leave_Type__c, Start_Date__c, Status__c,
               Employee__r.Name, Employee__r.Designation__c
        FROM Leave__c 
        WHERE Status__c = 'Pending'
        ORDER BY Start_Date__c ASC
      ''';

      final encodedQuery = Uri.encodeComponent(query);
      final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

      _logger.i('Making API call to: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      _logger.i('API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List<dynamic>?;

        if (records != null) {
          _logger.i('Successfully fetched ${records.length} leaves for approval');
          return records.cast<Map<String, dynamic>>();
        } else {
          _logger.w('No leaves found for approval');
          return [];
        }
      } else {
        _logger.e('Failed to fetch leaves for approval. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching leaves for approval: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Get leave statistics for dashboard
  static Future<Map<String, dynamic>?> getLeaveStatistics() async {
    try {
      _logger.i('Fetching leave statistics');

      // Get employee details for leave balance
      final employeeDetails = await getEmployeeDetails();
      if (employeeDetails == null) {
        _logger.e('Failed to get employee details for statistics');
        return null;
      }

      // Get all leaves for the employee
      final leaves = await getEmployeeLeaves();
      if (leaves == null) {
        _logger.e('Failed to get employee leaves for statistics');
        return null;
      }

      // Calculate statistics
      final totalLeaveBalance = employeeDetails['Leave_Balance__c'] ?? 0;
      final leaveBalanceFormula = employeeDetails['Leave_Balance_Formula__c'] ?? 0;

      // Count leaves by status
      final approvedLeaves = leaves.where((leave) => leave['Status__c'] == 'Approved').length;
      final pendingLeaves = leaves.where((leave) => leave['Status__c'] == 'Pending').length;
      final rejectedLeaves = leaves.where((leave) => leave['Status__c'] == 'Rejected').length;

      // Calculate used leaves (approved leaves this year)
      final currentYear = DateTime.now().year;
      final usedLeaves = leaves.where((leave) {
        if (leave['Status__c'] != 'Approved') return false;
        final startDate = DateTime.tryParse(leave['Start_Date__c'] ?? '');
        return startDate != null && startDate.year == currentYear;
      }).length;

      final remainingLeaves = (totalLeaveBalance is int ? totalLeaveBalance : 0) - usedLeaves;

      final statistics = {
        'total_leave_balance': totalLeaveBalance,
        'leave_balance_formula': leaveBalanceFormula,
        'used_leaves': usedLeaves,
        'remaining_leaves': remainingLeaves > 0 ? remainingLeaves : 0,
        'approved_leaves': approvedLeaves,
        'pending_leaves': pendingLeaves,
        'rejected_leaves': rejectedLeaves,
        'total_leaves_applied': leaves.length,
        'designation': employeeDetails['Designation__c'],
      };

      _logger.i('Successfully calculated leave statistics: $statistics');
      return statistics;
    } catch (e, stackTrace) {
      _logger.e('Error fetching leave statistics: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Get upcoming leaves for the current employee
  static Future<List<Map<String, dynamic>>?> getUpcomingLeaves() async {
    try {
      _logger.i('Fetching upcoming leaves');

      final credentials = await _getValidCredentials();
      if (credentials == null) {
        _logger.e('Failed to get valid credentials');
        return null;
      }

      final employeeId = credentials['employee_id']!;
      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      final today = DateTime.now().toIso8601String().split('T')[0];

      // SOQL query to get upcoming approved leaves
      final query = '''
        SELECT Name, Employee__c, End_Date__c, Description__c, Leave_Type__c, Start_Date__c, Status__c 
        FROM Leave__c 
        WHERE Employee__c = '$employeeId' 
        AND Start_Date__c >= $today 
        AND Status__c = 'Approved'
        ORDER BY Start_Date__c ASC
        LIMIT 10
      ''';

      final encodedQuery = Uri.encodeComponent(query);
      final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

      _logger.i('Making API call to: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      _logger.i('API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List<dynamic>?;

        if (records != null) {
          _logger.i('Successfully fetched ${records.length} upcoming leaves');
          return records.cast<Map<String, dynamic>>();
        } else {
          _logger.w('No upcoming leaves found');
          return [];
        }
      } else {
        _logger.e('Failed to fetch upcoming leaves. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error fetching upcoming leaves: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Check if current employee is on leave today
  static Future<Map<String, dynamic>?> getTodayLeaveStatus() async {
    try {
      _logger.i('Checking today\'s leave status');

      final credentials = await _getValidCredentials();
      if (credentials == null) {
        _logger.e('Failed to get valid credentials');
        return null;
      }

      final employeeId = credentials['employee_id']!;
      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      final today = DateTime.now().toIso8601String().split('T')[0];

      // SOQL query to check if employee is on leave today
      final query = '''
        SELECT Name, Employee__c, End_Date__c, Description__c, Leave_Type__c, Start_Date__c, Status__c 
        FROM Leave__c 
        WHERE Employee__c = '$employeeId' 
        AND Start_Date__c <= $today 
        AND End_Date__c >= $today 
        AND Status__c = 'Approved'
        LIMIT 1
      ''';

      final encodedQuery = Uri.encodeComponent(query);
      final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

      _logger.i('Making API call to: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      _logger.i('API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = data['records'] as List<dynamic>?;

        if (records != null && records.isNotEmpty) {
          final leaveRecord = records.first as Map<String, dynamic>;
          _logger.i('Employee is on leave today: ${leaveRecord['Leave_Type__c']}');
          return {
            'is_on_leave': true,
            'leave_details': leaveRecord,
          };
        } else {
          _logger.i('Employee is not on leave today');
          return {
            'is_on_leave': false,
            'leave_details': null,
          };
        }
      } else {
        _logger.e('Failed to check today\'s leave status. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error checking today\'s leave status: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Delete a leave request (only if status is Pending)
  static Future<bool> deleteLeaveRequest(String leaveId) async {
    try {
      _logger.i('Deleting leave request: $leaveId');

      final credentials = await _getValidCredentials();
      if (credentials == null) {
        _logger.e('Failed to get valid credentials');
        return false;
      }

      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      final url = '$instanceUrl/services/data/$_apiVersion/sobjects/Leave__c/$leaveId';

      _logger.i('Making DELETE request to: $url');

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      _logger.i('API Response Status: ${response.statusCode}');

      if (response.statusCode == 204) {
        _logger.i('Successfully deleted leave request');
        return true;
      } else {
        _logger.e('Failed to delete leave request. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting leave request: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}