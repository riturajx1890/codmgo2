import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class SalesforceAuthService {
  static final Logger _logger = Logger();

  static const String _clientId = '3MVG9g4ncJRWcPBAkl0kWpnZgvu1HXq8AOCdHvOBJ_VHoWzqK6zG7VNEqlC1vvOIGUIDa.ZBqNFz.IdA99cyO';
  static const String _clientSecret = '4ED3ECDBA2D428C616DF961FB7D3127421F0A5A0AB655DE27CAC6430E6EF1CDC';
  static const String _username = 'codmsoftware@pboedition.com.riturajsb';
  static const String _passwordWithToken = 'RituRaj@20258onQrKhcHZwQHO0USxeyjABlU';
  static const String _loginUrl = 'https://test.salesforce.com/services/oauth2/token';

  static Future<Map<String, dynamic>?> authenticate() async {
    _logger.i('Starting Salesforce authentication');
    _logger.d('Using login URL: $_loginUrl');
    _logger.d('Using username: $_username');

    try {
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'password',
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'username': _username,
          'password': _passwordWithToken,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _logger.e('Authentication request timed out');
          throw TimeoutException('Authentication request timed out', const Duration(seconds: 30));
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