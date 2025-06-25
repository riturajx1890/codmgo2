import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:codmgo2/utils/shared_prefs_utils.dart';
import 'package:codmgo2/services/leave_api_service.dart';

enum LeaveType { casual, halfDay, oneDay, sick }

class ApplyLeaveLogic {
  static final Logger _logger = Logger();
  static const String _apiVersion = 'v60.0';

  /// Map UI leave types to Salesforce picklist values
  static String _mapLeaveTypeToSalesforce(LeaveType leaveType) {
    switch (leaveType) {
      case LeaveType.casual:
        return 'CL(Casual leave)';
      case LeaveType.halfDay:
        return 'HL(Half-day leave)';
      case LeaveType.oneDay:
        return 'OL(one-day leave)';
      case LeaveType.sick:
        return 'SL/ML(Sick leave/Medical leave)';
    }
  }

  /// Get display name for leave type
  static String _getLeaveTypeDisplayName(LeaveType leaveType) {
    switch (leaveType) {
      case LeaveType.casual:
        return 'Casual Leave';
      case LeaveType.halfDay:
        return 'Half-Day Leave';
      case LeaveType.oneDay:
        return 'One Day Leave';
      case LeaveType.sick:
        return 'Medical Leave';
    }
  }

  /// Submit leave request with email notification
  static Future<bool> submitLeaveRequest({
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String description,
  }) async {
    try {
      _logger.i('Starting leave request submission process');

      // Get valid credentials with employee ID
      final credentials = await SharedPrefsUtils.getValidCredentialsWithEmployeeId();
      if (credentials == null) {
        _logger.e('Failed to get valid credentials');
        return false;
      }

      final employeeId = credentials['employee_id']!;
      final salesforceLeaveType = _mapLeaveTypeToSalesforce(leaveType);

      // Create leave request in Salesforce
      final leaveCreated = await LeaveApiService.createLeaveRequest(
        leaveType: salesforceLeaveType,
        startDate: startDate,
        endDate: endDate,
        description: description,
      );

      if (!leaveCreated) {
        _logger.e('Failed to create leave request in Salesforce');
        return false;
      }

      _logger.i('Leave request created successfully, now sending email notifications');

      // Send email notifications to HR and Manager
      await _sendEmailNotifications(
        employeeId: employeeId,
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        description: description,
        credentials: credentials,
      );

      return true;
    } catch (e, stackTrace) {
      _logger.e('Error in leave request submission: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Send email notifications to HR and Manager
  static Future<void> _sendEmailNotifications({
    required String employeeId,
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String description,
    required Map<String, String> credentials,
  }) async {
    try {
      _logger.i('Fetching employee and HR/Manager details for email notifications');

      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      // Get current employee details
      final employeeQuery = '''
        SELECT Id, First_Name__c, Last_Name__c, Designation__c, Reporting_Manager__c, Employee_Official_Email__c 
        FROM Employee__c 
        WHERE Id = '$employeeId'
      ''';

      final employeeDetails = await _executeSalesforceQuery(employeeQuery, accessToken, instanceUrl);
      if (employeeDetails == null || employeeDetails.isEmpty) {
        _logger.e('Failed to fetch current employee details');
        return;
      }

      final currentEmployee = employeeDetails.first;
      final employeeName = '${currentEmployee['First_Name__c'] ?? ''} ${currentEmployee['Last_Name__c'] ?? ''}'.trim();

      // Get HR and Manager details (active employees only)
      final hrManagerQuery = '''
        SELECT Id, First_Name__c, Last_Name__c, Designation__c, Employee_Official_Email__c, Active__c 
        FROM Employee__c 
        WHERE (Designation__c LIKE '%HR%' OR Designation__c LIKE '%Manager%' OR Designation__c LIKE '%Lead%') 
        AND Active__c = true
      ''';

      final hrManagerDetails = await _executeSalesforceQuery(hrManagerQuery, accessToken, instanceUrl);
      if (hrManagerDetails == null) {
        _logger.e('Failed to fetch HR/Manager details');
        return;
      }

      // Filter HR and Manager emails
      final hrEmails = <String>[];
      final managerEmails = <String>[];

      for (final person in hrManagerDetails) {
        final designation = (person['Designation__c'] ?? '').toString().toLowerCase();
        final email = person['Employee_Official_Email__c'];
        final isActive = person['Active__c'] == true;

        if (email != null && isActive) {
          if (designation.contains('hr')) {
            hrEmails.add(email);
          } else if (designation.contains('manager') || designation.contains('lead')) {
            managerEmails.add(email);
          }
        }
      }

      // Send email notification
      if (hrEmails.isNotEmpty || managerEmails.isNotEmpty) {
        await _sendEmail(
          employeeName: employeeName,
          employeeId: employeeId,
          leaveType: leaveType,
          startDate: startDate,
          endDate: endDate,
          description: description,
          hrEmails: hrEmails,
          managerEmails: managerEmails,
          credentials: credentials,
        );
      } else {
        _logger.w('No active HR or Manager emails found for notification');
      }
    } catch (e, stackTrace) {
      _logger.e('Error sending email notifications: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Execute Salesforce SOQL query
  static Future<List<Map<String, dynamic>>?> _executeSalesforceQuery(
      String query,
      String accessToken,
      String instanceUrl,
      ) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$instanceUrl/services/data/$_apiVersion/query/?q=$encodedQuery';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['records'] as List<dynamic>?)?.cast<Map<String, dynamic>>();
      } else {
        _logger.e('Query failed. Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('Error executing Salesforce query: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Send email using Salesforce Email API
  static Future<void> _sendEmail({
    required String employeeName,
    required String employeeId,
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String description,
    required List<String> hrEmails,
    required List<String> managerEmails,
    required Map<String, String> credentials,
  }) async {
    try {
      _logger.i('Sending email notification');

      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      final leaveTypeDisplay = _getLeaveTypeDisplayName(leaveType);
      final subject = 'Leave Request: $leaveTypeDisplay - $employeeName';

      final emailBody = '''
Dear HR Team and Manager,

A new leave request has been submitted and requires your attention.

EMPLOYEE DETAILS:
• Employee Name: $employeeName
• Employee ID: $employeeId

LEAVE REQUEST DETAILS:
• Leave Type: $leaveTypeDisplay
• Start Date: ${_formatDate(startDate)}
• End Date: ${_formatDate(endDate)}
• Duration: ${_calculateLeaveDuration(startDate, endDate)}
• Description: $description
• Status: Pending Approval
• Submission Date: ${_formatDate(DateTime.now())}

Please review and approve/reject this leave request at your earliest convenience.

Thank you,
Leave Management System
      ''';

      // Prepare recipients (HR as TO, Manager as CC)
      final toAddresses = hrEmails.isNotEmpty ? hrEmails : managerEmails.take(1).toList();
      final ccAddresses = hrEmails.isNotEmpty && managerEmails.isNotEmpty ? managerEmails : <String>[];

      final emailPayload = {
        'messages': [
          {
            'targets': [
              {
                'address': toAddresses.first,
                'type': 'Address'
              }
            ],
            'ccAddresses': ccAddresses.map((email) => {
              'address': email,
              'type': 'Address'
            }).toList(),
            'subject': subject,
            'plainTextBody': emailBody,
            'htmlBody': emailBody.replaceAll('\n', '<br>'),
          }
        ]
      };

      final emailUrl = '$instanceUrl/services/data/$_apiVersion/actions/standard/emailSimple';

      final response = await http.post(
        Uri.parse(emailUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(emailPayload),
      );

      if (response.statusCode == 200) {
        _logger.i('Email notification sent successfully');
      } else {
        _logger.e('Failed to send email. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error sending email: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Format date for display
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Calculate leave duration
  static String _calculateLeaveDuration(DateTime startDate, DateTime endDate) {
    final difference = endDate.difference(startDate).inDays + 1;
    return difference == 1 ? '1 day' : '$difference days';
  }
}