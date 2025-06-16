import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:codmgo2/utils/location_logic.dart';

class DashboardLogic extends ChangeNotifier {
  static final Logger _logger = Logger();
  final LocationLogic _locationLogic = LocationLogic();

  bool _isLocationChecking = false;
  bool _isWithinRadius = false;
  String _locationMessage = '';
  double _distance = 0.0;

  // Getters
  bool get isLocationChecking => _isLocationChecking;
  bool get isWithinRadius => _isWithinRadius;
  String get locationMessage => _locationMessage;
  double get distance => _distance;

  /// Check location radius and update state
  Future<void> checkLocationRadius() async {
    _logger.i('Starting location radius check');

    // Set checking state
    _isLocationChecking = true;
    notifyListeners();

    try {
      // Get location result
      final result = await _locationLogic.isWithinRadius();

      // Update state with results
      _isWithinRadius = result['isInRadius'] ?? false;
      _locationMessage = result['message'] ?? 'Unknown location status';
      _distance = result['distance'] ?? 0.0;

      _logger.i('Location check completed: $_locationMessage');

    } catch (e, stackTrace) {
      _logger.e('Error checking location radius: $e', error: e, stackTrace: stackTrace);
      _isWithinRadius = false;
      _locationMessage = 'Unable to get location. Please try again.';
      _distance = 0.0;
    } finally {
      // Reset checking state
      _isLocationChecking = false;
      notifyListeners();
    }
  }

  /// Show location status snackbar
  void showLocationSnackbar(BuildContext context) {
    if (_isLocationChecking) {
      // Show updating location snackbar
      _showSnackbar(
        context,
        message: 'Updating location',
        backgroundColor: Colors.blueAccent,
        textColor: Colors.white,
      );
      return;
    }

    if (_isWithinRadius) {
      // Show success snackbar
      _showSnackbar(
        context,
        message: 'You are in the office radius',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } else {
      // Show error snackbar with distance
      final extraDistance = _distance - _locationLogic.radiusInMeters;
      _showSnackbar(
        context,
        message: 'You are ${extraDistance.toStringAsFixed(0)}m away from office radius',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  /// Show updating location snackbar (public method)
  void showUpdatingLocationSnackbar(BuildContext context) {
    _showSnackbar(
      context,
      message: 'Updating location',
      backgroundColor: Colors.blueAccent,
      textColor: Colors.white,
    );
  }

  /// Private method to show snackbar
  void _showSnackbar(
      BuildContext context, {
        required String message,
        required Color backgroundColor,
        required Color textColor,
      }) {
    // Remove any existing snackbar
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    // Show new snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Initialize location check (call this on dashboard init)
  Future<void> initialize() async {
    _logger.i('Initializing dashboard logic');
    await checkLocationRadius();
  }
}