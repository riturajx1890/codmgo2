import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:codmgo2/utils/shared_prefs_utils.dart';
import 'package:codmgo2/services/leave_api_service.dart';
import 'package:codmgo2/services/config.dart';

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

      // Send email notifications to HR with Manager in CC
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

  /// Send email notifications to HR with Manager in CC
  static Future<void> _sendEmailNotifications({
    required String employeeId,
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String description,
    required Map<String, String> credentials,
  }) async {
    try {
      _logger.i('Fetching employee details for email notifications');

      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      // Get current employee details
      final employeeQuery = '''
        SELECT Id, First_Name__c, Last_Name__c, Designation__c, Employee_Official_Email__c 
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
      final employeeEmail = currentEmployee['Employee_Official_Email__c'] ?? '';

      // Get HR and Manager emails from config
      final hrEmail = Config.hrEmail;
      final managerEmail = Config.managerEmail;

      _logger.i('Using HR email: $hrEmail');
      _logger.i('Using Manager email: $managerEmail');

      // Validate emails
      if (!_isValidEmail(hrEmail)) {
        _logger.e('Invalid HR email address: $hrEmail');
        return;
      }

      if (!_isValidEmail(managerEmail)) {
        _logger.e('Invalid Manager email address: $managerEmail');
        return;
      }

      // Send email notification
      await _sendEmail(
        employeeName: employeeName,
        employeeId: employeeId,
        employeeEmail: employeeEmail,
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        description: description,
        hrEmail: hrEmail,
        managerEmail: managerEmail,
        credentials: credentials,
      );

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

  /// Send email using multiple methods with HR as TO and Manager as CC
  static Future<void> _sendEmail({
    required String employeeName,
    required String employeeId,
    required String employeeEmail,
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String description,
    required String hrEmail,
    required String managerEmail,
    required Map<String, String> credentials,
  }) async {
    try {
      _logger.i('Sending email notification to HR: $hrEmail with Manager: $managerEmail in CC');

      final leaveTypeDisplay = _getLeaveTypeDisplayName(leaveType);
      final subject = 'Leave Request: $leaveTypeDisplay - $employeeName';
      final duration = _calculateLeaveDuration(startDate, endDate);

      // Updated email body format as requested
      final emailBody = '''Dear HR,

I hope this email finds you well. I am writing to formally request leave from work.

Leave Request Details:
• Leave Type: $leaveTypeDisplay
• Start Date: ${_formatDate(startDate)}
• End Date: ${_formatDate(endDate)}
• Duration: $duration${description.isNotEmpty ? '\n• Reason: $description' : ''}

I have ensured all my responsibilities are up to date and will make appropriate arrangements for any urgent matters during my absence. 
I kindly request your approval for this leave. Please let me know if additional information is needed.

Thank you for your consideration.

Best regards,
$employeeName
Employee ID: $employeeId

---
This email was automatically generated from the Employee Leave Management System.''';

      // Try multiple email sending methods
      bool emailSent = false;

      // Method 1: Try emailSimple
      emailSent = await _sendViaEmailSimple(
        hrEmail: hrEmail,
        managerEmail: managerEmail,
        subject: subject,
        body: emailBody,
        credentials: credentials,
      );

      if (!emailSent) {
        // Method 2: Try SingleEmailMessage
        emailSent = await _sendViaSingleEmailMessage(
          hrEmail: hrEmail,
          managerEmail: managerEmail,
          subject: subject,
          body: emailBody,
          credentials: credentials,
        );
      }

      if (!emailSent) {
        // Method 3: Try sending separate emails
        await _sendSeparateEmails(
          hrEmail: hrEmail,
          managerEmail: managerEmail,
          subject: subject,
          body: emailBody,
          credentials: credentials,
        );
      }

      if (emailSent) {
        _logger.i('Email notification sent successfully');
      } else {
        _logger.w('All email sending methods attempted, check logs for details');
      }

    } catch (e, stackTrace) {
      _logger.e('Error sending email: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Method 1: Send via emailSimple with CC
  static Future<bool> _sendViaEmailSimple({
    required String hrEmail,
    required String managerEmail,
    required String subject,
    required String body,
    required Map<String, String> credentials,
  }) async {
    try {
      _logger.i('Attempting to send email via emailSimple');

      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      final emailPayload = {
        'inputs': [
          {
            'emailAddresses': hrEmail,
            'emailSubject': subject,
            'emailBody': body,
            'ccEmailAddresses': managerEmail,
          }
        ]
      };

      final connectUrl = '$instanceUrl/services/data/$_apiVersion/actions/standard/emailSimple';

      final response = await http.post(
        Uri.parse(connectUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(emailPayload),
      );

      _logger.i('emailSimple response status: ${response.statusCode}');
      _logger.i('emailSimple response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is List && responseData.isNotEmpty && responseData[0]['isSuccess'] == true) {
          _logger.i('Email sent successfully via emailSimple');
          return true;
        } else {
          _logger.w('emailSimple returned success but with errors: ${response.body}');
        }
      } else {
        _logger.w('emailSimple failed. Status: ${response.statusCode}, Body: ${response.body}');
      }

      return false;
    } catch (e, stackTrace) {
      _logger.e('Error in emailSimple: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Method 2: Send via SingleEmailMessage with CC
  static Future<bool> _sendViaSingleEmailMessage({
    required String hrEmail,
    required String managerEmail,
    required String subject,
    required String body,
    required Map<String, String> credentials,
  }) async {
    try {
      _logger.i('Attempting to send email via SingleEmailMessage');

      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      final emailPayload = {
        'inputs': [
          {
            'emailMessage': {
              'subject': subject,
              'plainTextBody': body,
              'toAddresses': [hrEmail],
              'ccAddresses': [managerEmail],
            }
          }
        ]
      };

      final url = '$instanceUrl/services/data/$_apiVersion/actions/standard/sendSingleEmail';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(emailPayload),
      );

      _logger.i('SingleEmailMessage response status: ${response.statusCode}');
      _logger.i('SingleEmailMessage response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is List && responseData.isNotEmpty && responseData[0]['isSuccess'] == true) {
          _logger.i('Email sent successfully via SingleEmailMessage');
          return true;
        } else {
          _logger.w('SingleEmailMessage returned errors: ${response.body}');
        }
      } else {
        _logger.e('SingleEmailMessage failed. Status: ${response.statusCode}, Body: ${response.body}');
      }

      return false;
    } catch (e, stackTrace) {
      _logger.e('Error in SingleEmailMessage: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Method 3: Send separate emails to HR and Manager
  static Future<void> _sendSeparateEmails({
    required String hrEmail,
    required String managerEmail,
    required String subject,
    required String body,
    required Map<String, String> credentials,
  }) async {
    try {
      _logger.i('Attempting to send separate emails');

      // Send to HR
      final hrSuccess = await _sendSingleEmail(
        recipient: hrEmail,
        subject: subject,
        body: body + '\n\n(Manager has been notified separately)',
        credentials: credentials,
      );

      // Send to Manager
      final managerSuccess = await _sendSingleEmail(
        recipient: managerEmail,
        subject: 'CC: ' + subject,
        body: body + '\n\n(This is a copy of the leave request sent to HR)',
        credentials: credentials,
      );

      if (hrSuccess || managerSuccess) {
        _logger.i('At least one separate email sent successfully');
      } else {
        _logger.e('Failed to send separate emails to both HR and Manager');
      }

    } catch (e, stackTrace) {
      _logger.e('Error sending separate emails: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Send email to a single recipient
  static Future<bool> _sendSingleEmail({
    required String recipient,
    required String subject,
    required String body,
    required Map<String, String> credentials,
  }) async {
    try {
      _logger.i('Sending single email to: $recipient');

      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      // Try emailSimple first
      final emailPayload = {
        'inputs': [
          {
            'emailAddresses': recipient,
            'emailSubject': subject,
            'emailBody': body,
          }
        ]
      };

      final connectUrl = '$instanceUrl/services/data/$_apiVersion/actions/standard/emailSimple';

      final response = await http.post(
        Uri.parse(connectUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(emailPayload),
      );

      _logger.i('Single email response status for $recipient: ${response.statusCode}');
      _logger.i('Single email response body for $recipient: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData is List && responseData.isNotEmpty && responseData[0]['isSuccess'] == true) {
          _logger.i('Single email sent successfully to $recipient');
          return true;
        } else {
          _logger.w('Single email API returned success but with errors for $recipient: ${response.body}');
        }
      } else {
        _logger.w('Single email failed for $recipient. Status: ${response.statusCode}, Body: ${response.body}');
      }

      return false;
    } catch (e, stackTrace) {
      _logger.e('Error sending single email to $recipient: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Validate email address format
  static bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email.trim());
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

  /// Check email logs in Salesforce (for debugging)
  static Future<void> checkEmailLogs(Map<String, String> credentials) async {
    try {
      final accessToken = credentials['access_token']!;
      final instanceUrl = credentials['instance_url']!;

      // Query recent email logs
      final emailLogQuery = '''
        SELECT Id, Subject, Status, CreatedDate, ToAddress 
        FROM EmailStatus 
        WHERE CreatedDate = TODAY 
        ORDER BY CreatedDate DESC 
        LIMIT 10
      ''';

      final emailLogs = await _executeSalesforceQuery(emailLogQuery, accessToken, instanceUrl);

      if (emailLogs != null && emailLogs.isNotEmpty) {
        _logger.i('Recent email logs:');
        for (final log in emailLogs) {
          _logger.i('Email: ${log['Subject']} - Status: ${log['Status']} - To: ${log['ToAddress']}');
        }
      } else {
        _logger.i('No recent email logs found');
      }
    } catch (e) {
      _logger.e('Error checking email logs: $e');
    }
  }
}