import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'full_screen_map.dart';
import 'location_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'config.dart';
import 'dart:async';
import 'services/directions_service.dart';
import 'models/navigation_step.dart';
import 'theme/app_theme.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'services/route_storage_service.dart';
import 'models/saved_route.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    PlanPage(),
    MinePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Plan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Mine',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late MapController _mapController;
  LatLng? _currentPosition;
  String? _currentAddress;
  bool _isLoading = true;
  StreamController<LocationMarkerPosition>? _positionStreamController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _positionStreamController = StreamController<LocationMarkerPosition>();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _positionStreamController?.close();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
            setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
              _isLoading = false;
            });
      _positionStreamController?.add(
        LocationMarkerPosition(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        ),
      );
      _getAddressFromPosition(_currentPosition!);
      _mapController.move(_currentPosition!, 15);
      } catch (e) {
      debugPrint('Error getting location: $e');
          setState(() {
            _isLoading = false;
          });
        }
      }

  Future<void> _getAddressFromPosition(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _currentAddress = '${place.street}, ${place.locality}, ${place.country}';
        });
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }

  void _openFullScreenMap() {
    if (_currentPosition != null && mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return FullScreenMap(
              initialPosition: _currentPosition!,
                heroTag: 'map_preview',
                previewController: _mapController,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F2FD),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              Padding(
                      padding: const EdgeInsets.only(left: 32, right: 16, top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'StepScape',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                              color: Color(0xFF1976D2),
                        shadows: [
                          Shadow(
                                  color: Color(0xFFBBDEFB),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final mainPageState = context.findAncestorStateOfType<_MainPageState>();
                        if (mainPageState != null) {
                                mainPageState._onItemTapped(2);
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                                    Color(0xFFBBDEFB),
                                    Color(0xFF90CAF9),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                                    color: Color(0xFFBBDEFB),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                  color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                              color: Colors.blue[100]!,
                      blurRadius: 8,
                              offset: const Offset(0, 4),
                    ),
                  ],
                ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                    children: [
                              GestureDetector(
                                onTap: _openFullScreenMap,
                                child: FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: _currentPosition ?? const LatLng(51.5, -0.09),
                                    initialZoom: 15,
                                  ),
                        children: [
                                    TileLayer(
                                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.example.app',
                                    ),
                                    CurrentLocationLayer(
                                      positionStream: _positionStreamController?.stream,
                                      headingStream: null, // 禁用指南针
                                      style: LocationMarkerStyle(
                                        marker: DefaultLocationMarker(
                                          color: const Color(0xFF1976D2),
                                        ),
                                        markerSize: const Size(20, 20),
                                        accuracyCircleColor: const Color(0xFF1976D2).withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                              ),
                              Positioned(
                                right: 16,
                                bottom: 16,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFBBDEFB),
                                        Color(0xFF90CAF9),
                                      ],
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0xFFBBDEFB),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.my_location),
                                    color: Colors.white,
                                    onPressed: _getCurrentLocation,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ),
                  ),
                Container(
                      margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                        color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue[100]!,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.location_on,
                                    color: Colors.blue[700],
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Current Location',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                    ),
                                  ],
                                ),
                            const SizedBox(height: 16),
                                    Text(
                              _currentAddress ?? 'Getting location...',
                                      style: TextStyle(
                                fontSize: 16,
                                color: _currentAddress != null ? Colors.black87 : Colors.grey[400],
                                      ),
                                    ),
                            if (_currentAddress != null) ...[
                              const SizedBox(height: 12),
                                  ],
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  String _selectedRouteType = 'One-way';
  String _selectedTheme = 'Short Trip';
  final Set<String> _selectedMoods = {};
  
  // 修改起止点状态变量
  String _startPoint = '';
  String _endPoint = '';
  LatLng? _startPosition;
  LatLng? _endPosition;
  
  final List<String> _routeTypes = const ['One-way', 'Round Trip'];
  final List<String> _themes = const ['Short Trip', 'Walking', 'Jogging', 'Cycling', 'Hiking'];
  final List<String> _moods = const [
    'Quiet', 'Bustling', 'Fresh Air', 'Scenic', 'Cultural',
    'Relaxing', 'Adventurous', 'Natural', 'Urban'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE3F2FD),
                  Colors.white,
                ],
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top + 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 32, right: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Route Planning',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                            shadows: [
                              Shadow(
                                color: Color(0xFFBBDEFB),
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            final mainPageState = context.findAncestorStateOfType<_MainPageState>();
                            if (mainPageState != null) {
                              mainPageState._onItemTapped(2);
                            }
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFBBDEFB),
                                  Color(0xFF90CAF9),
                                ],
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xFFBBDEFB),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Route Type Selection
                  _buildSelectionCard(
                    title: 'Route Type',
                    icon: Icons.route,
                    children: [
                      ..._routeTypes.map((type) => _buildChip(
                        label: type,
                        isSelected: type == _selectedRouteType,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedRouteType = type;
                            });
                          }
                        },
                      )).toList(),
                      if (_selectedRouteType == 'One-way') ...[
                        const SizedBox(height: 16),
                        // 起点选择
                        GestureDetector(
                          onTap: () => _selectLocation(true),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.flag, color: Color(0xFF42A5F5), size: 20),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _startPoint.isEmpty ? 'Select start point' : _startPoint,
                                    style: TextStyle(
                                      color: _startPoint.isEmpty ? Colors.grey[400] : Colors.black87,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 终点选择
                        GestureDetector(
                          onTap: () => _selectLocation(false),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.flag, color: Color(0xFF42A5F5), size: 20),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _endPoint.isEmpty ? 'Select end point' : _endPoint,
                                    style: TextStyle(
                                      color: _endPoint.isEmpty ? Colors.grey[400] : Colors.black87,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Theme Selection
                  _buildSelectionCard(
                    title: 'Activity Theme',
                    icon: Icons.category,
                    children: _themes.map((theme) => _buildChip(
                      label: theme,
                      isSelected: theme == _selectedTheme,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedTheme = theme;
                          });
                        }
                      },
                    )).toList(),
                  ),
                  // Mood Selection
                  _buildSelectionCard(
                    title: 'Mood',
                    icon: Icons.mood,
                    children: _moods.map((mood) => _buildFilterChip(
                      label: mood,
                      isSelected: _selectedMoods.contains(mood),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedMoods.add(mood);
                          } else {
                            _selectedMoods.remove(mood);
                          }
                        });
                      },
                    )).toList(),
                  ),
                  const SizedBox(height: 32),
                  // Next Button
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF42A5F5),
                          Color(0xFF1976D2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue[200]!,
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _startNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.directions_walk,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                        'Start Navigation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                        ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.blue[100]!,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.blue[700], size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: children,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.blue[100],
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue[700] : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.blue[100],
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue[700] : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      showCheckmark: false,
    );
  }

  void _startNavigation() {
    if (_startPosition == null || _endPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end points')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoadingPage(
          startPosition: _startPosition!,
          endPosition: _endPosition!,
          startName: _startPoint,
          endName: _endPoint,
          selectedMoods: _selectedMoods,
          selectedTheme: _selectedTheme,
        ),
      ),
    );
  }

  Future<void> _selectLocation(bool isStartPoint) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPicker(
          title: isStartPoint ? 'Select Start Point' : 'Select End Point',
          initialPosition: isStartPoint ? _startPosition : _endPosition,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isStartPoint) {
          _startPosition = result['position'];
          _startPoint = result['address'];
        } else {
          _endPosition = result['position'];
          _endPoint = result['address'];
        }
      });
    }
  }
}

class NavigationPage extends StatefulWidget {
  final LatLng startPosition;
  final LatLng endPosition;
  final String startName;
  final String endName;
  final Set<String> selectedMoods;
  final List<LatLng> optimizedPoints;
  final List<NavigationStep> steps;
  final String selectedTheme;

  const NavigationPage({
    super.key,
    required this.startPosition,
    required this.endPosition,
    required this.startName,
    required this.endName,
    required this.selectedMoods,
    required this.optimizedPoints,
    required this.steps,
    required this.selectedTheme,
  });

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  final MapController _mapController = MapController();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isGeneratingRoute = false;
  String? _routeInstructions;
  int _currentStep = 0;
  final List<NavigationStep> _steps = [];
  String _totalDuration = "Calculating...";
  List<String>? _representativePlaces;
  bool _isMapReady = false;
  bool _isSaved = false;
  final RouteStorageService _routeStorage = RouteStorageService();

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _calculateRouteInfo();
    _checkIfSaved();
  }

  void _calculateRouteInfo() {
    if (widget.optimizedPoints.isEmpty) return;

    // Calculate total distance of the actual route
    double totalDistanceMeters = 0;
    final Distance calculator = const Distance();
    
    // Calculate actual distance using optimized route points
    for (int i = 0; i < widget.optimizedPoints.length - 1; i++) {
      totalDistanceMeters += calculator.distance(
        widget.optimizedPoints[i],
        widget.optimizedPoints[i + 1]
      );
    }

    // Assume average walking speed is 5 km/h, approximately 1.4 m/s
    const double walkingSpeedMps = 1.4;
    int totalSeconds = (totalDistanceMeters / walkingSpeedMps).round();

    // Format total time
    setState(() {
      if (totalSeconds < 60) {
        _totalDuration = "$totalSeconds seconds";
      } else if (totalSeconds < 3600) {
        final minutes = (totalSeconds / 60).round();
        _totalDuration = "$minutes minutes";
      } else {
        final hours = (totalSeconds / 3600).floor();
        final minutes = ((totalSeconds % 3600) / 60).round();
        _totalDuration = "$hours hours ${minutes > 0 ? '$minutes minutes' : ''}";
      }

      // Add distance information
      if (totalDistanceMeters < 1000) {
        _totalDuration += " (${totalDistanceMeters.round()}m)";
      } else {
        _totalDuration += " (${(totalDistanceMeters / 1000).toStringAsFixed(1)}km)";
      }
    });

    // Get representative places
    _identifyRepresentativePlaces();
  }

  void _identifyRepresentativePlaces() {
    // 根据选择的心情标签显示相应的地点类型
    Set<String> places = {};
    
    // 定义不同心情对应的地点描述
    final moodPlaces = {
      'Quiet': ['Parks', 'Gardens', 'Green Spaces'],
      'Bustling': ['Shopping Areas', 'Cafes', 'Restaurants'],
      'Fresh Air': ['Parks', 'Woods', 'Open Spaces'],
      'Scenic': ['Viewpoints', 'Waterfront', 'Scenic Areas'],
      'Cultural': ['Historic Sites', 'Museums', 'Theatres'],
      'Relaxing': ['Gardens', 'Parks', 'Peaceful Areas'],
      'Natural': ['Natural Areas', 'Parks', 'Rivers'],
      'Urban': ['City Attractions', 'Urban Areas', 'Shopping Districts'],
    };

    // 根据选择的心情添加相应的地点描述
    for (String mood in widget.selectedMoods) {
      if (moodPlaces.containsKey(mood)) {
        places.addAll(moodPlaces[mood]!);
      }
    }

    setState(() {
      _representativePlaces = places.toList()..sort();
    });
  }

  void _initializeMap() {
    setState(() {
      _isGeneratingRoute = true;
      _polylines.add(Polyline(
        points: widget.optimizedPoints,
        color: Colors.blue,
        strokeWidth: 5,
      ));
      
      // 添加起点标记
      _markers.add(
        Marker(
          point: widget.startPosition,
          width: 30,
          height: 30,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
            ),
            child: const Icon(
              Icons.trip_origin,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );

      // 添加终点标记
      _markers.add(
        Marker(
          point: widget.endPosition,
          width: 30,
          height: 30,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red,
            ),
            child: const Icon(
              Icons.place,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );

      // 只在关键途经点添加标记（每隔几个点添加一个标记）
      final int totalPoints = widget.optimizedPoints.length;
      if (totalPoints > 2) {
        // 计算标记间隔，确保途中最多显示 5 个标记
        final int interval = math.max((totalPoints - 2) ~/ 5, 1);
        
        for (int i = 1; i < totalPoints - 1; i += interval) {
          _markers.add(
            Marker(
              point: widget.optimizedPoints[i],
              width: 20,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.blue,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.circle,
                  color: Colors.blue,
                  size: 10,
                ),
          ),
        ),
      );
        }
      }

      if (widget.steps.isNotEmpty) {
        _routeInstructions = widget.steps[_currentStep].instruction;
        _steps.addAll(widget.steps);
      }
      _isGeneratingRoute = false;
    });

    // 等待地图加载完成后再移动视角
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerMapOnRoute();
    });
  }

  void _centerMapOnRoute() {
    if (widget.optimizedPoints.isEmpty) return;

    final points = widget.optimizedPoints;
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    // 计算边界
    for (var point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    // 添加边距
    final latPadding = (maxLat - minLat) * 0.1; // 10% 的边距
    final lngPadding = (maxLng - minLng) * 0.1;
    
    minLat -= latPadding;
    maxLat += latPadding;
    minLng -= lngPadding;
    maxLng += lngPadding;

    // 计算中心点
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    // 计算合适的缩放级别
    final latZoom = 360 / (maxLat - minLat);
    final lngZoom = 360 / (maxLng - minLng);
    var zoom = math.min(latZoom, lngZoom);

    // 将缩放级别转换为对数刻度
    zoom = math.log(zoom) / math.ln2;

    // 限制缩放级别在合理范围内
    zoom = zoom.clamp(12.0, 18.0);

            setState(() {
      _isMapReady = true;
    });

    // 移动地图到新的位置和缩放级别
    _mapController.move(
      LatLng(centerLat, centerLng),
      zoom,
    );
  }

  Future<void> _checkIfSaved() async {
    final routes = await _routeStorage.getSavedRoutes();
    setState(() {
      _isSaved = routes.any((route) => 
        route.startPosition == widget.startPosition &&
        route.endPosition == widget.endPosition
      );
    });
  }

  Future<void> _saveRoute() async {
    if (_isSaved) {
      await _routeStorage.deleteRoute(
        (await _routeStorage.getSavedRoutes())
            .firstWhere((route) => 
              route.startPosition == widget.startPosition &&
              route.endPosition == widget.endPosition
            ).id
      );
        setState(() {
        _isSaved = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route removed from favorites')),
      );
    } else {
      final route = SavedRoute(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '${widget.selectedTheme} Route',
        startPosition: widget.startPosition,
        endPosition: widget.endPosition,
        startName: widget.startName,
        endName: widget.endName,
        routePoints: widget.optimizedPoints,
        moods: widget.selectedMoods,
        theme: widget.selectedTheme,
        savedAt: DateTime.now(),
      );

      await _routeStorage.saveRoute(route);
      setState(() {
        _isSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route saved to favorites')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.startPosition,
              initialZoom: 15,
              onMapReady: () {
                setState(() {
                  _isMapReady = true;
                });
                _centerMapOnRoute();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.stepscape',
              ),
              PolylineLayer(
                polylines: _polylines.toList(),
              ),
              MarkerLayer(
                markers: _markers.toList(),
              ),
            ],
          ),
          
          // 返回按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          
          // 路线小结卡片
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 返回按钮
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Route Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.timer,
                        size: 20,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Estimated Time: ${_totalDuration ?? "Calculating..."}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          ),
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_representativePlaces != null && _representativePlaces!.isNotEmpty) ...[
                    const Text(
                      'Pathway Locations:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _representativePlaces!.map((place) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          place,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          if (_routeInstructions != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _routeInstructions!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _previousStep,
                          child: const Text('Previous'),
                        ),
                        Text(
                          '${_currentStep + 1}/${widget.steps.length}',
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        TextButton(
                          onPressed: _nextStep,
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          
          if (_isGeneratingRoute)
            const Center(
              child: CircularProgressIndicator(),
            ),

          // 收藏按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  _isSaved ? Icons.favorite : Icons.favorite_border,
                  color: _isSaved ? Colors.red : Colors.grey,
                ),
                onPressed: _saveRoute,
              ),
            ),
            ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() {
        _currentStep++;
        _routeInstructions = widget.steps[_currentStep].instruction;
        
        // 移动地图视角到当前步骤的起点
        _mapController.move(
            widget.steps[_currentStep].startLocation,
          15,
        );
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _routeInstructions = widget.steps[_currentStep].instruction;
      });
    }
  }

  void _logError(String message) {
    debugPrint(message);
  }
}

class MinePage extends StatefulWidget {
  const MinePage({super.key});

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> with SingleTickerProviderStateMixin {
  final RouteStorageService _routeStorage = RouteStorageService();
  List<SavedRoute> _savedRoutes = [];
  List<SavedRoute> _historyRoutes = [];
  final Map<String, Map<String, String>> _addressCache = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRoutes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    final savedRoutes = await _routeStorage.getSavedRoutes();
    final historyRoutes = await _routeStorage.getHistoryRoutes();
    setState(() {
      _savedRoutes = savedRoutes;
      _historyRoutes = historyRoutes;
    });
    // 为所有路线加载地址信息
    for (final route in [...savedRoutes, ...historyRoutes]) {
      _loadAddresses(route);
    }
  }

  Future<void> _loadAddresses(SavedRoute route) async {
    if (_addressCache.containsKey(route.id)) return;

    try {
      final startPlacemarks = await placemarkFromCoordinates(
        route.startPosition.latitude,
        route.startPosition.longitude,
      );
      final endPlacemarks = await placemarkFromCoordinates(
        route.endPosition.latitude,
        route.endPosition.longitude,
      );

      if (startPlacemarks.isNotEmpty && endPlacemarks.isNotEmpty) {
        final startPlace = startPlacemarks.first;
        final endPlace = endPlacemarks.first;

        setState(() {
          _addressCache[route.id] = {
            'start': '${startPlace.street}, ${startPlace.locality}',
            'end': '${endPlace.street}, ${endPlace.locality}',
          };
        });
      }
    } catch (e) {
      debugPrint('获取地址时出错: $e');
    }
  }

  Future<void> _deleteRoute(String routeId, bool isHistory) async {
    if (isHistory) {
      await _routeStorage.deleteHistoryRoute(routeId);
    } else {
      await _routeStorage.deleteRoute(routeId);
    }
    _addressCache.remove(routeId);
    await _loadRoutes();
  }

  Future<void> _openNavigationPage(SavedRoute route) async {
    try {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoadingPage(
              startPosition: route.startPosition,
              endPosition: route.endPosition,
              startName: route.startName,
              endName: route.endName,
              selectedMoods: route.moods,
              selectedTheme: route.theme,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载路线时出错: $e')),
        );
      }
    }
  }

  Widget _buildRouteList(List<SavedRoute> routes, bool isHistory) {
    if (routes.isEmpty) {
    return const Center(
        child: Text(
          'No routes',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: routes.length,
      itemBuilder: (context, index) {
        final route = routes[index];
        return Dismissible(
          key: Key(route.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          onDismissed: (direction) => _deleteRoute(route.id, isHistory),
          child: Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: InkWell(
              onTap: () => _openNavigationPage(route),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          route.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!isHistory)
                          IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.red),
                            onPressed: () => _deleteRoute(route.id, false),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.flag,
                            color: Colors.green,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Start: ${route.startName}',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.place,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'End: ${route.endName}',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Theme: ${route.theme}',
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Moods: ${route.moods.join(", ")}',
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isHistory ? "Generated" : "Saved"} at: ${route.savedAt.toString().split('.')[0]}',
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F2FD),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 32, right: 16, top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Routes',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                        shadows: [
                          Shadow(
                            color: Color(0xFFBBDEFB),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _loadRoutes,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFBBDEFB),
                              Color(0xFF90CAF9),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFFBBDEFB),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue[700],
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.blue[700],
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Favorites'),
                    Tab(text: 'History'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRouteList(_savedRoutes, false),
                    _buildRouteList(_historyRoutes, true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingPage extends StatefulWidget {
  final LatLng startPosition;
  final LatLng endPosition;
  final String startName;
  final String endName;
  final Set<String> selectedMoods;
  final String selectedTheme;

  const LoadingPage({
    Key? key,
    required this.startPosition,
    required this.endPosition,
    required this.startName,
    required this.endName,
    required this.selectedMoods,
    required this.selectedTheme,
  }) : super(key: key);

  @override
  _LoadingPageState createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isGeneratingRoute = false;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  List<LatLng> _optimizedPoints = [];
  List<NavigationStep> _steps = [];
  int _currentStepIndex = 0;
  List<String> _routeInstructions = [];

  // 动画控制器
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // 初始化动画
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 4 * 3.14159).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // 开始动画
    _controller.repeat();
    
    // 生成路线
      _generateRoute();
  }

  @override
  void dispose() {
    _controller.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _generateRoute() async {
    setState(() {
      _isGeneratingRoute = true;
    });

    try {
      final directions = await DirectionsService().getDirections(
        origin: widget.startPosition,
        destination: widget.endPosition,
        theme: widget.selectedTheme,
        moods: widget.selectedMoods,
      );

            setState(() {
        _optimizedPoints = directions.polyline;
        _steps = directions.steps;
        _currentStepIndex = 0;
        _isGeneratingRoute = false;
      });

      // 将路线添加到历史记录
      final route = SavedRoute(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '${widget.selectedTheme} Route',
        startPosition: widget.startPosition,
        endPosition: widget.endPosition,
        startName: widget.startName,
        endName: widget.endName,
        routePoints: _optimizedPoints,
        moods: widget.selectedMoods,
        theme: widget.selectedTheme,
        savedAt: DateTime.now(),
      );
      await RouteStorageService().addToHistory(route);

      // 延迟一下再跳转到导航页面，让用户看到加载动画
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
      Navigator.pushReplacement(
        context,
          MaterialPageRoute(
            builder: (context) => NavigationPage(
                startPosition: widget.startPosition,
                endPosition: widget.endPosition,
              startName: widget.startName,
              endName: widget.endName,
                selectedMoods: widget.selectedMoods,
              optimizedPoints: _optimizedPoints,
              steps: _steps,
              selectedTheme: widget.selectedTheme,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isGeneratingRoute = false;
      });
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('错误'),
            content: Text('生成路线时出错: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE3F2FD),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF42A5F5),
                                  Color(0xFF1976D2),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withAlpha(77),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.directions_walk,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFF42A5F5),
                              Color(0xFF1976D2),
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'StepScape',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: const Text(
                          'Generating your route...',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
} 