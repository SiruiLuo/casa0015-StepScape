import 'package:latlong2/latlong.dart';

class NavigationStep {
  final String instruction;
  final LatLng startLocation;
  final LatLng endLocation;
  final double distance; // 以米为单位的距离

  NavigationStep({
    required this.instruction,
    required this.startLocation,
    required this.endLocation,
    required this.distance,
  });

  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    return NavigationStep(
      instruction: json['instruction'] as String,
      startLocation: LatLng(
        (json['start_location'][1] as num).toDouble(),
        (json['start_location'][0] as num).toDouble(),
      ),
      endLocation: LatLng(
        (json['end_location'][1] as num).toDouble(),
        (json['end_location'][0] as num).toDouble(),
      ),
      distance: (json['distance'] as num).toDouble(),
    );
  }
} 