import '../services/api_service.dart';

class SavedAddress {
  final String id;
  final String label;
  final String addressLabel;
  final double lat;
  final double lng;
  final String city;
  final String? landmark;

  SavedAddress({
    required this.id,
    required this.label,
    required this.addressLabel,
    required this.lat,
    required this.lng,
    required this.city,
    this.landmark,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['_id'],
      label: json['label'],
      addressLabel: json['addressLabel'],
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      city: json['city'],
      landmark: json['landmark'],
    );
  }
}

class AddressService {
  final ApiService _api = ApiService();

  Future<List<SavedAddress>> getSavedAddresses() async {
    try {
      final response = await _api.client.get('/users/addresses');
      if (response.statusCode == 200) {
        return (response.data as List).map((json) => SavedAddress.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching saved addresses: $e");
      return [];
    }
  }

  Future<bool> addAddress(Map<String, dynamic> data) async {
    try {
      final response = await _api.client.post('/users/addresses', data: data);
      return response.statusCode == 200;
    } catch (e) {
      print("Error adding address: $e");
      return false;
    }
  }

  Future<bool> deleteAddress(String id) async {
    try {
      final response = await _api.client.delete('/users/addresses/$id');
      return response.statusCode == 200;
    } catch (e) {
      print("Error deleting address: $e");
      return false;
    }
  }
}
