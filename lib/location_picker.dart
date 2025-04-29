import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

class LocationPicker extends StatefulWidget {
  final String title;
  final LatLng? initialPosition;

  const LocationPicker({
    super.key,
    required this.title,
    this.initialPosition,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late MapController _mapController;
  LatLng? _selectedPosition;
  String _address = '选择位置';
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  final Map<String, List<dynamic>> _searchCache = {};

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedPosition = widget.initialPosition;
    if (_selectedPosition != null) {
      _getAddressFromPosition(_selectedPosition!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_selectedPosition!, 15);
      });
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _getAddressFromPosition(LatLng position) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        setState(() {
          _address = '${placemark.street}, ${placemark.locality}, ${placemark.country}';
        });
      }
    } catch (e) {
      debugPrint('获取地址时出错: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // 取消之前的延迟
    _debounce?.cancel();

    // 检查缓存
    if (_searchCache.containsKey(query)) {
      setState(() {
        _searchResults = _searchCache[query]!;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // 设置新的延迟
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        // 使用 Nominatim API 进行地点搜索，添加更多参数优化搜索结果
        final response = await http.get(
          Uri.parse(
            'https://nominatim.openstreetmap.org/search?'
            'format=json&'
            'q=${Uri.encodeComponent(query)}&'
            'limit=5&'
            'addressdetails=1&'
            'namedetails=1&'
            'countrycodes=gb&'  // 限制在英国范围内搜索
            'featuretype=city,university,school,landmark&'  // 限制搜索类型
            'accept-language=zh-CN,en',  // 设置语言偏好
          ),
          headers: {
            'User-Agent': 'StepScape/1.0',
            'Accept-Language': 'zh-CN,en',
          },
        );

        if (response.statusCode == 200) {
          final results = json.decode(response.body);
          
          // 对结果进行排序，优先显示更相关的结果
          results.sort((a, b) {
            final importanceA = double.tryParse(a['importance']?.toString() ?? '0') ?? 0;
            final importanceB = double.tryParse(b['importance']?.toString() ?? '0') ?? 0;
            return importanceB.compareTo(importanceA);
          });

          // 缓存结果
          _searchCache[query] = results;

          if (mounted) {
            setState(() {
              _searchResults = results;
              _isSearching = false;
            });
          }
        } else {
          if (mounted) {
      setState(() {
              _searchResults = [];
        _isSearching = false;
      });
          }
          debugPrint('搜索请求失败: ${response.statusCode}');
        }
    } catch (e) {
        if (mounted) {
      setState(() {
        _isSearching = false;
      });
    }
        debugPrint('搜索地点时出错: $e');
      }
    });
  }

  Future<void> _selectPlace(dynamic place) async {
    try {
      final lat = double.parse(place['lat']);
      final lon = double.parse(place['lon']);
      final position = LatLng(lat, lon);
      
      String displayName = place['display_name'] ?? '未知地点';
      if (place['namedetails'] != null && place['namedetails']['name'] != null) {
        displayName = place['namedetails']['name'];
      }
        
        setState(() {
          _selectedPosition = position;
        _address = displayName;
          _searchResults = [];
        _searchController.text = displayName;
      });

      _mapController.move(position, 15);
    } catch (e) {
      debugPrint('选择地点时出错: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('选择地点时出错，请重试')),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final currentPosition = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _selectedPosition = currentPosition;
      });
      
      _getAddressFromPosition(currentPosition);
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(currentPosition, 15);
      });
    } catch (e) {
      debugPrint('获取当前位置时出错: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_selectedPosition != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6B8CEF),  // 与大头针相同的蓝色
                      Color(0xFF4B6CD0),  // 稍深一点的蓝色
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B8CEF).withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextButton(
              onPressed: () {
                Navigator.pop(context, {
                  'position': _selectedPosition,
                      'address': _address,
                });
              },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '确认',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0EAFC),
              Color(0xFFCFDEF3),
            ],
                          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                mainAxisSize: MainAxisSize.min,
                      children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                          controller: _searchController,
                        style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                          hintText: '搜索地点（如：UCL、大英博物馆等）',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[400],
                          ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey[400],
                                  ),
                                    onPressed: () {
                                      _searchController.clear();
                                    setState(() {
                                      _searchResults = [];
                                    });
                                    },
                                  )
                                : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          ),
                          onChanged: _searchPlaces,
                      ),
                    ),
                        ),
                        if (_isSearching)
                          const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B8CEF)),
                          ),
                        ),
                          ),
                    )
                  else if (_searchResults.isNotEmpty)
                          Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                            child: ListView.builder(
                              shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                          final place = _searchResults[index];
                          String displayName = place['display_name'] ?? '未知地点';
                          if (place['namedetails'] != null && place['namedetails']['name'] != null) {
                            displayName = place['namedetails']['name'];
                          }
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectPlace(place),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF2D3142),
                                      ),
                                    ),
                                    if (place['display_name'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          place['display_name'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _selectedPosition ?? const LatLng(51.5, -0.09),
                          initialZoom: 15,
                          onTap: (tapPosition, point) {
                            setState(() {
                              _selectedPosition = point;
                            });
                            _getAddressFromPosition(point);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.stepscape',
                          ),
                          if (_selectedPosition != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _selectedPosition!,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF6B8CEF),
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                        ],
                ),
                Positioned(
                  right: 16,
                        bottom: 16,
                  child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: _getCurrentLocation,
                            icon: Icon(
                              Icons.my_location,
                              color: const Color(0xFF6B8CEF),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                  if (_isLoading)
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B8CEF)),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: const Color(0xFF6B8CEF),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _address,
                            style: const TextStyle(
                                fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2D3142),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '点击地图选择位置',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
                  ),
                ),
              ],
        ),
            ),
    );
  }
} 