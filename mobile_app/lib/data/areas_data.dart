import 'package:latlong2/latlong.dart';

class AreaModel {
  final String name;
  final LatLng centroid;

  AreaModel({required this.name, required this.centroid});
}

final List<AreaModel> nigeriaAreas = [
  AreaModel(name: "Uselu", centroid: LatLng(6.3644, 5.6062)),
  AreaModel(name: "GRA (Government Reservation Area)", centroid: LatLng(6.3155, 5.6186)),
  AreaModel(name: "Ikpoba Hill", centroid: LatLng(6.3592, 5.6565)),
  AreaModel(name: "Ekenwan", centroid: LatLng(6.3323, 5.5746)),
  AreaModel(name: "Aduwawa", centroid: LatLng(6.3888, 5.6558)),
  AreaModel(name: "Oluku", centroid: LatLng(6.4170, 5.6030)),
  AreaModel(name: "Evbuotubu", centroid: LatLng(6.3033, 5.5682)),
  AreaModel(name: "Sapele Road", centroid: LatLng(6.2825, 5.6353)),
  AreaModel(name: "Airport Road", centroid: LatLng(6.3150, 5.5900)),
  AreaModel(name: "University of Benin (UNIBEN)", centroid: LatLng(6.3995, 5.6212)),
];
