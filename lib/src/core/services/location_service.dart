import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Gets current location, updates profile, and returns the position
  static Future<Position?> updateLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Check if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      permission = await Geolocator.checkPermission();
      
      // On Web, we often need to request permission directly if it's denied
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return null;
      }

      // Get current position - forces popup on Web if not already showing
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // Save to Supabase Profile (Only if we have a user)
      final user = _client.auth.currentUser;
      if (user != null) {
        await _client.from('profiles').update({
          'last_lat': position.latitude,
          'last_long': position.longitude,
        }).eq('id', user.id);
      }

      return position;
    } catch (e) {
      debugPrint('GPS Error: $e');
      return null;
    }
  }

  /// Calculates distance between two points in KM
  static double calculateDistance(double startLat, double startLong, double endLat, double endLong) {
    return Geolocator.distanceBetween(startLat, startLong, endLat, endLong) / 1000;
  }
}
