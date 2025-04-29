import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:math' as math;

class RouteOptimizerService {
  static const String _overpassApi = 'https://overpass-api.de/api/interpreter';
  
  // 定义不同主题的路线长度系数
  static const Map<String, double> _themeDistanceFactors = {
    'Short Trip': 1.0,  // 最短距离
    'Walking': 1.2,     // 稍微可以绕路
    'Jogging': 1.4,     // 可以绕更多路
    'Cycling': 1.6,     // 可以绕更多路
    'Hiking': 2.0,      // 可以绕最多路
  };

  // 定义不同心情对应的 POI 类型
  static const Map<String, List<String>> _moodPoiTypes = {
    'Quiet': [
      'leisure=park',
      'leisure=garden',
    ],
    'Bustling': [
      'shop=mall',
      'amenity=marketplace',
    ],
    'Fresh Air': [
      'leisure=park',
      'natural=wood',
    ],
    'Scenic': [
      'tourism=viewpoint',
      'natural=water',
    ],
    'Cultural': [
      'historic=*',
      'tourism=museum',
    ],
    'Relaxing': [
      'leisure=park',
      'leisure=garden',
    ],
    'Natural': [
      'natural=*',
      'landuse=forest',
    ],
    'Urban': [
      'building=apartments',
      'shop=*',
    ],
  };

  Future<List<LatLng>> getOptimizedWaypoints({
    required LatLng start,
    required LatLng end,
    required String theme,
    required Set<String> moods,
  }) async {
    List<LatLng> waypoints = [];
    
    try {
      // 1. 首先获取最短路线的点
      final List<LatLng> shortestPath = [start, end];
      
      // 2. 如果是 Short Trip，直接返回最短路线
      if (theme == 'Short Trip' && moods.isEmpty) {
        return shortestPath;
      }

      // 3. 计算起点和终点之间的直线距离
      final Distance distance = const Distance();
      final double directDistance = distance.distance(start, end);
      
      // 4. 根据主题确定可以绕路的最小和最大距离
      final double minDistance = directDistance * 1.1; // 至少比直线距离多 10%
      final double maxDistance = directDistance * (_themeDistanceFactors[theme] ?? 1.0);
      
      // 5. 计算搜索范围（创建一个更小的矩形区域以限制搜索范围）
      final double searchRadius = directDistance * 0.3; // 减小搜索半径
      final boundingBox = _calculateBoundingBox(start, end, searchRadius);
      
      // 6. 如果选择了心情标签，查询相关的 POI
      if (moods.isNotEmpty) {
        // 限制每种心情最多查询的 POI 数量
        const int maxPoisPerMood = 50;
        
        for (String mood in moods) {
          final poiTypes = _moodPoiTypes[mood];
          if (poiTypes != null) {
            for (String poiType in poiTypes) {
              final query = '''
                [out:json][timeout:10];
                area[name="London"]->.searchArea;
                (
                  node[$poiType](${boundingBox['minLat']},${boundingBox['minLon']},${boundingBox['maxLat']},${boundingBox['maxLon']});
                  way[$poiType](${boundingBox['minLat']},${boundingBox['minLon']},${boundingBox['maxLat']},${boundingBox['maxLon']});
                )->.all;
                .all out body center ${maxPoisPerMood};
              ''';

              try {
                final response = await http.post(
                  Uri.parse(_overpassApi),
                  body: query,
                );

                if (response.statusCode == 200) {
                  final data = json.decode(response.body);
                  if (data['elements'] != null) {
                    final elements = data['elements'] as List;
                    final pois = elements.where((element) {
                      // 对于way类型的元素，使用center属性
                      final lat = element['lat'] ?? element['center']?['lat'];
                      final lon = element['lon'] ?? element['center']?['lon'];
                      return lat != null && lon != null;
                    }).map((element) {
                      // 获取正确的经纬度，无论是node还是way
                      final lat = element['lat'] ?? element['center']['lat'];
                      final lon = element['lon'] ?? element['center']['lon'];
                      return LatLng(lat.toDouble(), lon.toDouble());
                    }).toList();
                    
                    // 只添加距离路线合理范围内的POI
                    for (var poi in pois) {
                      if (_isPointNearPath(poi, start, end, maxDistance * 0.3)) {
                        waypoints.add(poi);
                      }
                    }
                  }
                }
              } catch (e) {
                print('查询 POI ($poiType) 时出错: $e');
              }
              
              // 添加短暂延迟以避免API限制
              await Future.delayed(const Duration(milliseconds: 200));
            }
          }
        }
        
        // 如果找到了POI，进行路径优化
        if (waypoints.isNotEmpty) {
          print('找到 ${waypoints.length} 个兴趣点');
          // 限制最大途经点数量
          if (waypoints.length > 100) {
            waypoints = _selectRepresentativePoints(waypoints, 100);
          }
          waypoints = _optimizeWaypoints(
            start: start,
            end: end,
            waypoints: waypoints,
            minDistance: minDistance,
            maxDistance: maxDistance,
          );
          print('优化后保留 ${waypoints.length} 个兴趣点');
        }
      }
      
      // 如果没有找到合适的 POI 或没有选择心情
      if (waypoints.isEmpty) {
        // 如果不是 Short Trip，至少生成一个绕路点以确保路线更长
        if (theme != 'Short Trip') {
          final midPoint = _generateMidPoint(start, end, minDistance);
          waypoints = [start, midPoint, end];
          return waypoints;
        }
        return shortestPath;
      }
      
      // 确保起点和终点在列表中
      if (waypoints.first != start) {
        waypoints.insert(0, start);
      }
      if (waypoints.last != end) {
        waypoints.add(end);
      }
      
      return waypoints;
    } catch (e) {
      print('路线优化错误: $e');
      return [start, end];
    }
  }

  Map<String, double> _calculateBoundingBox(LatLng start, LatLng end, double radius) {
    final double minLat = math.min(start.latitude, end.latitude) - (radius / 111320);
    final double maxLat = math.max(start.latitude, end.latitude) + (radius / 111320);
    final double minLon = math.min(start.longitude, end.longitude) - (radius / (111320 * math.cos(start.latitude * math.pi / 180)));
    final double maxLon = math.max(start.longitude, end.longitude) + (radius / (111320 * math.cos(start.latitude * math.pi / 180)));
    
    return {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLon': minLon,
      'maxLon': maxLon,
    };
  }

  // 生成一个确保路线更长的中间点
  LatLng _generateMidPoint(LatLng start, LatLng end, double minDistance) {
    final Distance distance = const Distance();
    final double bearing = distance.bearing(start, end);
    
    // 在起点和终点之间的垂直方向上偏移
    final double perpendicular = bearing + 90;
    final double offsetDistance = minDistance * 0.2; // 偏移距离为最小距离的 20%
    
    // 计算中点
    final midLat = (start.latitude + end.latitude) / 2;
    final midLng = (start.longitude + end.longitude) / 2;
    final midPoint = LatLng(midLat, midLng);
    
    // 在中点的基础上进行垂直偏移
    return distance.offset(midPoint, offsetDistance, perpendicular);
  }

  List<LatLng> _optimizeWaypoints({
    required LatLng start,
    required LatLng end,
    required List<LatLng> waypoints,
    required double minDistance,
    required double maxDistance,
  }) {
    if (waypoints.isEmpty) return [start, end];

    final Distance distance = const Distance();
    List<LatLng> optimizedPoints = [];
    double currentDistance = 0;
    LatLng currentPoint = start;

    // 对途经点进行聚类，避免过于密集
    waypoints = _clusterWaypoints(waypoints, 100);

    // 使用改进的贪心算法选择途经点
    while (waypoints.isNotEmpty && currentDistance < maxDistance) {
      LatLng? nextPoint = _findBestNextPoint(
        currentPoint,
        end,
        waypoints,
        maxDistance - currentDistance
      );
      
      if (nextPoint == null) break;

      // 计算添加这个点后的总距离
      double newDistance = currentDistance + distance.distance(currentPoint, nextPoint);
      double remainingDistance = distance.distance(nextPoint, end);
      double totalDistance = newDistance + remainingDistance;

      // 如果总距离小于最小距离且还有其他点可选，跳过这个点
      if (totalDistance < minDistance && waypoints.length > 1) {
        waypoints.remove(nextPoint);
        continue;
      }

      optimizedPoints.add(nextPoint);
      currentDistance = newDistance;
      currentPoint = nextPoint;
      waypoints.remove(nextPoint);
    }

    // 如果优化后的路线仍然太短，添加额外的绕路点
    if (currentDistance + distance.distance(currentPoint, end) < minDistance) {
      LatLng extraPoint = _generateMidPoint(currentPoint, end, minDistance - currentDistance);
      optimizedPoints.add(extraPoint);
    }

    return optimizedPoints;
  }

  List<LatLng> _clusterWaypoints(List<LatLng> points, double radius) {
    if (points.isEmpty) return points;

    final Distance distance = const Distance();
    List<LatLng> clustered = [];
    List<bool> used = List.filled(points.length, false);

    for (int i = 0; i < points.length; i++) {
      if (used[i]) continue;

      List<LatLng> cluster = [points[i]];
      used[i] = true;

      for (int j = i + 1; j < points.length; j++) {
        if (!used[j] && distance.distance(points[i], points[j]) <= radius) {
          cluster.add(points[j]);
          used[j] = true;
        }
      }

      // 使用聚类中心点
      if (cluster.length > 1) {
        double lat = cluster.map((p) => p.latitude).reduce((a, b) => a + b) / cluster.length;
        double lon = cluster.map((p) => p.longitude).reduce((a, b) => a + b) / cluster.length;
        clustered.add(LatLng(lat, lon));
      } else {
        clustered.add(cluster[0]);
      }
    }

    return clustered;
  }

  LatLng? _findBestNextPoint(
    LatLng current,
    LatLng end,
    List<LatLng> points,
    double remainingDistance
  ) {
    if (points.isEmpty) return null;

    final Distance distance = const Distance();
    LatLng? best;
    double bestScore = double.infinity;

    for (var point in points) {
      double distToCurrent = distance.distance(current, point);
      double distToEnd = distance.distance(point, end);
      
      if (distToCurrent + distToEnd > remainingDistance) continue;

      // 评分函数：距离当前点的距离 * 0.4 + 距离终点的距离 * 0.6
      // 这样可以在选择下一个点时既考虑就近原则，又考虑不要偏离终点太远
      double score = distToCurrent * 0.4 + distToEnd * 0.6;
      
      if (score < bestScore) {
        bestScore = score;
        best = point;
      }
    }

    return best;
  }

  // 判断点是否在路径附近
  bool _isPointNearPath(LatLng point, LatLng start, LatLng end, double maxDistance) {
    final Distance calculator = const Distance();
    
    // 计算点到起点和终点的距离
    final distanceToStart = calculator.distance(point, start);
    final distanceToEnd = calculator.distance(point, end);
    
    // 计算起点到终点的距离
    final pathDistance = calculator.distance(start, end);
    
    // 如果点到起点或终点的距离大于路径长度的一定比例，则认为点不在路径附近
    if (distanceToStart > pathDistance || distanceToEnd > pathDistance) {
      return false;
    }
    
    return true;
  }

  // 从大量点中选择具有代表性的点
  List<LatLng> _selectRepresentativePoints(List<LatLng> points, int maxPoints) {
    if (points.length <= maxPoints) return points;
    
    final Distance calculator = const Distance();
    List<LatLng> selected = [];
    final int step = points.length ~/ maxPoints;
    
    for (int i = 0; i < points.length; i += step) {
      if (selected.length < maxPoints) {
        selected.add(points[i]);
      }
    }
    
    return selected;
  }
} 