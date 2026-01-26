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
          "&components=country:ng"
          "&types=address|establishment";

      if (city != null) {
        // We can add location bias here if we had the city coords, 
        // but adding it to the query string is often enough for Google.
        // url += "&locationbias=circle:5000@lat,lng"; // Advanced
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
