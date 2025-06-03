import 'dart:convert';
import 'package:http/http.dart' as http;

class SalesforceAuthService {
  static const String _clientId = '3MVG9g4ncJRWcPBAkl0kWpnZgvu1HXq8AOCdHvOBJ_VHoWzqK6zG7VNEqlC1vvOIGUIDa.ZBqNFz.IdA99cyO';
  static const String _clientSecret = '4ED3ECDBA2D428C616DF961FB7D3127421F0A5A0AB655DE27CAC6430E6EF1CDC';
  static const String _username = 'codmsoftware@pboedition.com.riturajsb';
  static const String _passwordWithToken = 'RituRaj@20258onQrKhcHZwQHO0USxeyjABlU';
  static const String _loginUrl = 'https://test.salesforce.com/services/oauth2/token';

  static Future<Map<String, dynamic>?> authenticate() async {
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
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print('Auth failed: ${response.body}');
      return null;
    }
  }
}