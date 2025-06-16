import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class SessionManager {
  static final Logger _logger = Logger();

  // Session keys
  static const String _accessTokenKey = 'access_token';
  static const String _instanceUrlKey = 'instance_url';
  static const String _employeeIdKey = 'employee_id';
  static const String _firstNameKey = 'first_name';
  static const String _lastNameKey = 'last_name';
  static const String _sessionExpiryKey = 'session_expiry';
  static const String _refreshTokenKey = 'refresh_token';

  // Session duration (45 days in milliseconds)
  static const int sessionDurationDays = 45;
  static const int sessionDurationMs = sessionDurationDays * 24 * 60 * 60 * 1000;

  /// Save user session with 45-day expiry
  static Future<bool> saveSession({
    required String accessToken,
    required String instanceUrl,
    required String employeeId,
    required String firstName,
    required String lastName,
    String? refreshToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Calculate expiry time (45 days from now)
      final expiryTime = DateTime.now().millisecondsSinceEpoch + sessionDurationMs;

      // Save all session data
      await Future.wait([
        prefs.setString(_accessTokenKey, accessToken),
        prefs.setString(_instanceUrlKey, instanceUrl),
        prefs.setString(_employeeIdKey, employeeId),
        prefs.setString(_firstNameKey, firstName),
        prefs.setString(_lastNameKey, lastName),
        prefs.setInt(_sessionExpiryKey, expiryTime),
        if (refreshToken != null) prefs.setString(_refreshTokenKey, refreshToken),
      ]);

      _logger.i('Session saved successfully. Expires at: ${DateTime.fromMillisecondsSinceEpoch(expiryTime)}');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error saving session: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Check if session is valid and not expired
  static Future<bool> isSessionValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if access token exists
      final accessToken = prefs.getString(_accessTokenKey);
      if (accessToken == null || accessToken.isEmpty) {
        _logger.w('No access token found');
        return false;
      }

      // Check if session has expired
      final expiryTime = prefs.getInt(_sessionExpiryKey);
      if (expiryTime == null) {
        _logger.w('No expiry time found, considering session invalid');
        return false;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now >= expiryTime) {
        _logger.w('Session has expired');
        await clearSession(); // Clear expired session
        return false;
      }

      _logger.i('Session is valid. Expires at: ${DateTime.fromMillisecondsSinceEpoch(expiryTime)}');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error checking session validity: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get stored session data
  static Future<Map<String, String>?> getSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if session is valid first
      if (!await isSessionValid()) {
        return null;
      }

      final accessToken = prefs.getString(_accessTokenKey);
      final instanceUrl = prefs.getString(_instanceUrlKey);
      final employeeId = prefs.getString(_employeeIdKey);
      final firstName = prefs.getString(_firstNameKey);
      final lastName = prefs.getString(_lastNameKey);
      final refreshToken = prefs.getString(_refreshTokenKey);

      if (accessToken == null || instanceUrl == null || employeeId == null ||
          firstName == null || lastName == null) {
        _logger.w('Incomplete session data found');
        await clearSession();
        return null;
      }

      return {
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
        'employeeId': employeeId,
        'firstName': firstName,
        'lastName': lastName,
        if (refreshToken != null) 'refreshToken': refreshToken,
      };
    } catch (e, stackTrace) {
      _logger.e('Error getting session data: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Extend session by another 45 days (useful for active users)
  static Future<bool> extendSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!await isSessionValid()) {
        _logger.w('Cannot extend invalid session');
        return false;
      }

      // Extend expiry by another 45 days
      final newExpiryTime = DateTime.now().millisecondsSinceEpoch + sessionDurationMs;
      await prefs.setInt(_sessionExpiryKey, newExpiryTime);

      _logger.i('Session extended. New expiry: ${DateTime.fromMillisecondsSinceEpoch(newExpiryTime)}');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error extending session: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Clear all session data
  static Future<bool> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await Future.wait([
        prefs.remove(_accessTokenKey),
        prefs.remove(_instanceUrlKey),
        prefs.remove(_employeeIdKey),
        prefs.remove(_firstNameKey),
        prefs.remove(_lastNameKey),
        prefs.remove(_sessionExpiryKey),
        prefs.remove(_refreshTokenKey),
      ]);

      _logger.i('Session cleared successfully');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error clearing session: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get remaining session time in days
  static Future<int> getRemainingSessionDays() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryTime = prefs.getInt(_sessionExpiryKey);

      if (expiryTime == null) {
        return 0;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final remainingMs = expiryTime - now;

      if (remainingMs <= 0) {
        return 0;
      }

      return (remainingMs / (24 * 60 * 60 * 1000)).ceil();
    } catch (e) {
      _logger.e('Error getting remaining session days: $e');
      return 0;
    }
  }

  /// Check if session needs renewal (less than 7 days remaining)
  static Future<bool> needsRenewal() async {
    final remainingDays = await getRemainingSessionDays();
    return remainingDays <= 7 && remainingDays > 0;
  }
}