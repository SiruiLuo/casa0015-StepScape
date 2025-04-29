import 'package:latlong2/latlong.dart';

class SavedRoute {
  final String id;
  final String name;
  final LatLng startPosition;
  final LatLng endPosition;
  final String startName;
  final String endName;
  final List<LatLng> routePoints;
  final Set<String> moods;
  final String theme;
  final DateTime savedAt;

  SavedRoute({
    required this.id,
    required this.name,
    required this.startPosition,
    required this.endPosition,
    required this.startName,
    required this.endName,
    required this.routePoints,
    required this.moods,
    required this.theme,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startPosition': {
        'latitude': startPosition.latitude,
        'longitude': startPosition.longitude,
      },
      'endPosition': {
        'latitude': endPosition.latitude,
        'longitude': endPosition.longitude,
      },
      'startName': startName,
      'endName': endName,
      'routePoints': routePoints.map((point) => {
        'latitude': point.latitude,
        'longitude': point.longitude,
      }).toList(),
      'moods': moods.toList(),
      'theme': theme,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory SavedRoute.fromJson(Map<String, dynamic> json) {
    return SavedRoute(
      id: json['id'],
      name: json['name'],
      startPosition: LatLng(
        json['startPosition']['latitude'],
        json['startPosition']['longitude'],
      ),
      endPosition: LatLng(
        json['endPosition']['latitude'],
        json['endPosition']['longitude'],
      ),
      startName: json['startName'] ?? '未知起点',
      endName: json['endName'] ?? '未知终点',
      routePoints: (json['routePoints'] as List).map((point) => 
        LatLng(point['latitude'], point['longitude'])
      ).toList(),
      moods: Set<String>.from(json['moods']),
      theme: json['theme'],
      savedAt: DateTime.parse(json['savedAt']),
    );
  }
} 