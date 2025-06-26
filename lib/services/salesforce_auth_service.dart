import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:codmgo2/services/config.dart';

class SalesforceAuthService {
  static final Logger _logger = Logger();

  static Future<Map<String, dynamic>?> authenticate() async {
    _logger.i('Starting Salesforce authentication');
    _logger.d('Using login URL: ${Config.salesforceLoginUrl}');
    _logger.d('Using username: ${Config.salesforceUsername}');

    try {
      final response = await http.post(
        Uri.parse(Config.salesforceLoginUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'password',
          'client_id': Config.salesforceClientId,
          'client_secret': Config.salesforceClientSecret,
          'username': Config.salesforceUsername,
          'password': Config.salesforcePasswordWithToken,
        },
      ).timeout(
        Duration(seconds: Config.requestTimeoutSeconds),
        onTimeout: () {
          _logger.e('Authentication request timed out');
          throw TimeoutException('Authentication request timed out', Duration(seconds: Config.requestTimeoutSeconds));
        },
      );

      _logger.i('Authentication response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final accessToken = data['access_token'];
        final instanceUrl = data['instance_url'];

        _logger.i('Authentication successful');
        _logger.d('Access token received: ${accessToken?.substring(0, 20)}...');
        _logger.d('Instance URL: $instanceUrl');

        return data;
      } else {
        _logger.e('Authentication failed with status ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        return null;
      }
    } on TimeoutException catch (e) {
      _logger.e('Authentication timeout: $e');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Authentication error: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}