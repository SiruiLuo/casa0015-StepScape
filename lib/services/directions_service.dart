import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import '../models/navigation_step.dart';
import '../services/route_optimizer_service.dart';

class DirectionsService {
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1/foot';
  final RouteOptimizerService _optimizer = RouteOptimizerService();

  Future<DirectionsResult> getDirections({
    required LatLng origin,
    required LatLng destination,
    String theme = 'Short Trip',
    Set<String> moods = const {},
  }) async {
    try {
      // 1. 首先获取优化后的途经点
      final optimizedWaypoints = await _optimizer.getOptimizedWaypoints(
        start: origin,
        end: destination,
        theme: theme,
        moods: moods,
      );

      // 2. 构建包含所有途经点的 OSRM 请求
      final coordinates = optimizedWaypoints.map((point) => 
        '${point.longitude},${point.latitude}'
      ).join(';');

      final url = Uri.parse(
        '$_baseUrl/$coordinates?overview=full&steps=true&geometries=geojson'
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('获取路线时出错：HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (data['code'] != 'Ok') {
        throw Exception('获取路线时出错：${data['message']}');
      }

      final route = data['routes'][0];
      final legs = route['legs'][0];
      final steps = legs['steps'] as List;
      
      List<NavigationStep> navigationSteps = [];
      List<LatLng> polylinePoints = [];

      // 解析路线几何信息
      if (route['geometry'] != null && route['geometry']['coordinates'] != null) {
        final coordinates = route['geometry']['coordinates'] as List;
        for (var coord in coordinates) {
          if (coord is List && coord.length >= 2) {
            polylinePoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
          }
        }
      }

      // 解析步骤信息
      for (var step in steps) {
        final startLocation = step['maneuver']['location'] as List;
        final endLocation = step['intersections']?.last?['location'] as List? ?? startLocation;
        final maneuver = step['maneuver'];
        
        String instruction = _cleanInstruction(
          maneuver['type'] as String? ?? '',
          maneuver['modifier'] as String? ?? '',
          (step['name'] as String?) ?? '',
          (step['distance'] as num).toDouble()
        );
        
        navigationSteps.add(NavigationStep(
          instruction: instruction,
          startLocation: LatLng(startLocation[1].toDouble(), startLocation[0].toDouble()),
          endLocation: LatLng(endLocation[1].toDouble(), endLocation[0].toDouble()),
          distance: (step['distance'] as num).toDouble(),
        ));
      }

      return DirectionsResult(
        polyline: polylinePoints,
        steps: navigationSteps,
      );
    } catch (e) {
      throw Exception('获取路线时出错：$e');
    }
  }

  String _cleanInstruction(String type, String modifier, String name, double distance) {
    // Convert OSRM navigation instructions to user-friendly English descriptions
    String instruction = '';
    String distanceText = '';
    
    // Format distance
    if (distance >= 1000) {
      distanceText = '${(distance / 1000).toStringAsFixed(1)} km';
    } else {
      distanceText = '${distance.round()} m';
    }
    
    switch (type) {
      case 'turn':
        switch (modifier) {
          case 'left':
            instruction = 'Turn left';
            break;
          case 'right':
            instruction = 'Turn right';
            break;
          case 'slight left':
            instruction = 'Slight left turn';
            break;
          case 'slight right':
            instruction = 'Slight right turn';
            break;
          case 'sharp left':
            instruction = 'Sharp left turn';
            break;
          case 'sharp right':
            instruction = 'Sharp right turn';
            break;
          case 'straight':
            instruction = 'Continue straight';
            break;
          case 'uturn':
            instruction = 'Make a U-turn';
            break;
          default:
            instruction = 'Continue forward';
        }
        break;
      case 'new name':
        if (name.isNotEmpty) {
          instruction = 'Continue along $name';
        } else {
          instruction = 'Continue along current road';
        }
        break;
      case 'depart':
        instruction = 'Start from here';
        break;
      case 'arrive':
        instruction = 'You have reached your destination';
        break;
      case 'roundabout':
        instruction = 'Enter the roundabout';
        break;
      case 'exit roundabout':
        instruction = 'Exit the roundabout';
        break;
      case 'fork':
        switch (modifier) {
          case 'left':
            instruction = 'Take the left fork';
            break;
          case 'right':
            instruction = 'Take the right fork';
            break;
          case 'slight left':
            instruction = 'Take the slight left fork';
            break;
          case 'slight right':
            instruction = 'Take the slight right fork';
            break;
          default:
            instruction = 'Continue at the fork';
        }
        break;
      case 'merge':
        instruction = 'Merge onto the road';
        break;
      case 'end of road':
        switch (modifier) {
          case 'left':
            instruction = 'Turn left at the end of the road';
            break;
          case 'right':
            instruction = 'Turn right at the end of the road';
            break;
          default:
            instruction = 'Road ends ahead';
        }
        break;
      default:
        if (name.isNotEmpty) {
          instruction = 'Continue along $name';
        } else {
          instruction = 'Continue forward';
        }
    }
    
    // Add distance information if not start or end point
    if (type != 'depart' && type != 'arrive') {
      instruction = '$instruction for $distanceText';
    }
    
    return instruction;
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      return '$hours hour ${remainingMinutes > 0 ? '$remainingMinutes min' : ''}';
    }
  }

  String _generateDirectionInstruction(NavigationStep step) {
    if (step.instruction.contains('从此处出发')) {
      return 'Start from here';
    } else if (step.instruction.contains('继续沿')) {
      final distance = step.instruction.split('前进')[1].split('米')[0].trim();
      final street = step.instruction.split('继续沿')[1].split('前进')[0].trim();
      return 'Continue along $street for $distance meters';
    } else if (step.instruction.contains('左转')) {
      return 'Turn left';
    } else if (step.instruction.contains('右转')) {
      return 'Turn right';
    } else if (step.instruction.contains('到达目的地')) {
      return 'You have reached your destination';
    }
    return step.instruction;
  }
}

class DirectionsResult {
  final List<LatLng> polyline;
  final List<NavigationStep> steps;

  DirectionsResult({
    required this.polyline,
    required this.steps,
  });
} 