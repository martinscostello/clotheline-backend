import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class GranularLocation {
  final String description;
  final String placeId;
  final String? mainText;
  final String? secondaryText;
  final double? lat;
  final double? lng;
  final String? city;

  GranularLocation({
    required this.description,
    required this.placeId,
    this.mainText,
    this.secondaryText,
    this.lat,
    this.lng,
    this.city,
  });
}

class LocationSearchService {
  static const String _apiKey = 'AIzaSyCOEbOxOUfub7VvtoZZIkegBhifpNUqPfY';
  final Dio _dio = Dio();

  // 1. Get Autocomplete Suggestions
  Future<List<GranularLocation>> getAutocomplete(String input, String? city) async {
    if (input.isEmpty) return [];

    try {
      // Use component restriction for Nigeria (country:ng)
      // Use location bias/restriction if we want to be strict about Benin/Abuja
      String url = "https://maps.googleapis.com/maps/api/place/autocomplete/json"
          "?input=$input"
          "&key=$_apiKey"
          "&components=country:ng";

      print("DEBUG: Google Autocomplete URL: ${url.replaceFirst(_apiKey, 'KEY_HIDDEN')}");

      if (city != null) {
        // Strict location restriction based on the branch city
        // Benin City: 6.3350, 5.6037
        // Abuja: 9.0765, 7.3986
        if (city.toLowerCase().contains("benin")) {
          url += "&locationrestriction=circle:15000@6.3350,5.6037";
        } else if (city.toLowerCase().contains("abuja")) {
          url += "&locationrestriction=circle:20000@9.0765,7.3986";
        }
      }

      final response = await _dio.get(url);

      if (response.data['status'] == 'OK') {
        final predictions = response.data['predictions'] as List;
        return predictions.map((p) => GranularLocation(
          description: p['description'],
          placeId: p['place_id'],
          mainText: p['structured_formatting']['main_text'],
          secondaryText: p['structured_formatting']['secondary_text'],
        )).toList();
      }
      return [];
    } catch (e) {
      print("Google Places Error: $e");
      return [];
    }
  }

  // 2. Get Lat/Lng from Place ID
  Future<LatLng?> getPlaceDetails(String placeId) async {
    try {
      final url = "https://maps.googleapis.com/maps/api/place/details/json"
          "?place_id=$placeId"
          "&fields=geometry"
          "&key=$_apiKey";

      final response = await _dio.get(url);

      if (response.data['status'] == 'OK') {
        final location = response.data['result']['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      }
      return null;
    } catch (e) {
      print("Google Geocoding Error: $e");
      return null;
    }
  }
}
