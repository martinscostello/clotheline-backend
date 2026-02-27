import 'package:latlong2/latlong.dart';

class AreaModel {
  final String name;
  final String city; // Added to filter by branch city
  final LatLng centroid;

  AreaModel({required this.name, required this.city, required this.centroid});
}

final List<AreaModel> nigeriaAreas = [
  // --- BENIN CITY ---
  AreaModel(name: "Uselu", city: "Benin", centroid: LatLng(6.3644, 5.6062)),
  AreaModel(name: "GRA (Government Reservation Area)", city: "Benin", centroid: LatLng(6.3155, 5.6186)),
  AreaModel(name: "Ikpoba Hill", city: "Benin", centroid: LatLng(6.3592, 5.6565)),
  AreaModel(name: "Ekenwan", city: "Benin", centroid: LatLng(6.3323, 5.5746)),
  AreaModel(name: "Aduwawa", city: "Benin", centroid: LatLng(6.3888, 5.6558)),
  AreaModel(name: "Oluku", city: "Benin", centroid: LatLng(6.4170, 5.6030)),
  AreaModel(name: "Evbuotubu", city: "Benin", centroid: LatLng(6.3033, 5.5682)),
  AreaModel(name: "Sapele Road", city: "Benin", centroid: LatLng(6.2825, 5.6353)),
  AreaModel(name: "Airport Road", city: "Benin", centroid: LatLng(6.3150, 5.5900)),
  AreaModel(name: "University of Benin (UNIBEN)", city: "Benin", centroid: LatLng(6.3995, 5.6212)),
  
  // --- ABUJA ---
  AreaModel(name: "Wuse", city: "Abuja", centroid: LatLng(9.0667, 7.4833)),
  AreaModel(name: "Garki", city: "Abuja", centroid: LatLng(9.0333, 7.4833)),
  AreaModel(name: "Maitama", city: "Abuja", centroid: LatLng(9.0833, 7.5000)),
  AreaModel(name: "Asokoro", city: "Abuja", centroid: LatLng(9.0500, 7.5167)),
  AreaModel(name: "Gwarimpa", city: "Abuja", centroid: LatLng(9.1167, 7.4000)),
  AreaModel(name: "Jabi", city: "Abuja", centroid: LatLng(9.0667, 7.4167)),
  AreaModel(name: "Utako", city: "Abuja", centroid: LatLng(9.0667, 7.4333)),
  AreaModel(name: "Kubwa", city: "Abuja", centroid: LatLng(9.1500, 7.3333)),
  AreaModel(name: "Lugbe", city: "Abuja", centroid: LatLng(8.9833, 7.3667)),
];
