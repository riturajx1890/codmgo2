import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';

class LocationLogic {
  static final Logger _logger = Logger();

  double officeLat = 28.55122201233124;
  double officeLng = 77.32420167559967;
  double radiusInMeters = 250;

  Future<Map<String, dynamic>> isWithinRadius() async {
    _logger.i('Checking if user is within office radius');

    try {
      _logger.i('Getting current position...');
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 30),
        ),
      );

      _logger.i('Current position: lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}m');

      double distance = Geolocator.distanceBetween(
        officeLat,
        officeLng,
        position.latitude,
        position.longitude,
      );

      _logger.i('Distance from office: ${distance.toStringAsFixed(2)}m (radius limit: ${radiusInMeters}m)');

      bool isInRadius = distance <= radiusInMeters;

      String message;
      if (isInRadius) {
        message = "Within office radius";
        _logger.i('User is within office radius');
      } else {
        double extraDistance = distance - radiusInMeters;
        message = "You are ${extraDistance.toStringAsFixed(0)}m away from office";
        _logger.w('User is outside office radius by ${extraDistance.toStringAsFixed(0)}m');
      }

      return {
        'isInRadius': isInRadius,
        'message': message,
        'distance': distance,
        'accuracy': position.accuracy,
      };
    } catch (e, stackTrace) {
      _logger.e('Error getting location: $e', error: e, stackTrace: stackTrace);
      return {
        'isInRadius': false,
        'message': 'Unable to get location. Please try again.',
      };
    }
  }
}