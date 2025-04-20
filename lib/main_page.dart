import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  GoogleMapController? _mapController;
  Position? _currentPosition;
  String _address = 'Loading...';
  String _locationName = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    // 请求位置权限
    final status = await Permission.location.request();
    if (status.isGranted) {
      try {
        // 获取当前位置
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        // 获取地址信息
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          final locationName = [
            if (place.name != null && place.name!.isNotEmpty) place.name,
            if (place.street != null && place.street!.isNotEmpty) place.street,
            if (place.subLocality != null && place.subLocality!.isNotEmpty) place.subLocality,
            if (place.locality != null && place.locality!.isNotEmpty) place.locality,
          ].where((element) => element != null).join(', ');
          
          if (mounted) {
            setState(() {
              _currentPosition = position;
              _address = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
              _locationName = locationName.isNotEmpty ? locationName : 'Unknown Location';
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _currentPosition = position;
              _address = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
              _locationName = 'Unknown Location';
              _isLoading = false;
            });
          }
        }

        // 移动地图到当前位置
        if (mounted && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(position.latitude, position.longitude),
                zoom: 15,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _address = 'Unable to get location';
            _locationName = 'Location unavailable';
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _address = 'Location permission denied';
          _locationName = 'Permission required';
        });
      }
    }
  }

  void _openFullScreenMap() {
    if (_currentPosition != null && _mapController != null && mounted) {
      _mapController!.getVisibleRegion().then((bounds) {
        if (!mounted) return;
        final center = LatLng(
          (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
          (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
        );
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return FullScreenMap(
                initialPosition: center,
                heroTag: 'map_preview',
                previewController: _mapController,
                initialCameraPosition: CameraPosition(
                  target: center,
                  zoom: 15,
                ),
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
      });
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
              Color(0xFFE3F2FD), // Colors.blue[50]
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
                      'StepScape',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2), // Colors.blue[700]
                        shadows: [
                          Shadow(
                            color: Color(0xFFBBDEFB), // Colors.blue[100]
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
                          mainPageState._onItemTapped(2); // 2 是 Mine Page 的索引
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFBBDEFB), // Colors.blue[100]
                              Color(0xFF90CAF9), // Colors.blue[200]
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFFBBDEFB), // Colors.blue[100]
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
              // Location Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFBBDEFB), // Colors.blue[100]
                      blurRadius: 8,
                      offset: Offset(0, 4),
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
                            decoration: const BoxDecoration(
                              color: Color(0xFFE3F2FD), // Colors.blue[50]
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            child: const Icon(Icons.location_on, color: Color(0xFF1976D2), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Current Location',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1976D2), // Colors.blue[700]
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFAFAFA),
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    border: Border.fromBorderSide(
                                      BorderSide(color: Color(0xFFEEEEEE)),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE3F2FD),
                                          borderRadius: BorderRadius.all(Radius.circular(8)),
                                        ),
                                        child: const Icon(Icons.apartment, color: Color(0xFF42A5F5), size: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _locationName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF212121),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFAFAFA),
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    border: Border.fromBorderSide(
                                      BorderSide(color: Color(0xFFEEEEEE)),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE3F2FD),
                                          borderRadius: BorderRadius.all(Radius.circular(8)),
                                        ),
                                        child: const Icon(Icons.my_location, color: Color(0xFF42A5F5), size: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _address,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF757575),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
              // Map Preview
              if (_currentPosition != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  height: 220,
                  decoration: BoxDecoration(
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
                    child: Hero(
                      tag: 'map_preview',
                      child: Container(
                        color: Colors.white,
                        child: Stack(
                          children: [
                            GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                ),
                                zoom: 15,
                              ),
                              onMapCreated: (controller) {
                                _mapController = controller;
                              },
                              myLocationEnabled: true,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                              onTap: (LatLng position) {
                                _openFullScreenMap();
                              },
                              markers: {
                                Marker(
                                  markerId: const MarkerId('currentLocation'),
                                  position: LatLng(
                                    _currentPosition!.latitude,
                                    _currentPosition!.longitude,
                                  ),
                                  infoWindow: const InfoWindow(
                                    title: 'You are here',
                                  ),
                                ),
                              },
                            ),
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue[100]!,
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.fullscreen, size: 16, color: Colors.black54),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tap to expand',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              // Floating Action Button
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue[200]!,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: _getCurrentLocation,
                  backgroundColor: Colors.blue[700],
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ),
              const SizedBox(height: 32),
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
  String _selectedDuration = '30 min';
  final Set<String> _selectedMoods = {};
  
  // 修改起止点状态变量
  String _startPoint = '';
  String _endPoint = '';
  LatLng? _startPosition;
  LatLng? _endPosition;
  
  final List<String> _routeTypes = const ['One-way', 'Round Trip'];
  final List<String> _themes = const ['Short Trip', 'Walking', 'Jogging', 'Cycling', 'Hiking'];
  final List<String> _durations = const ['15 min', '30 min', '1 hour', '2 hours', '3 hours', '4 hours', '5 hours', 'Full day'];
  final List<String> _moods = const [
    'Quiet', 'Bustling', 'Fresh Air', 'Scenic', 'Cultural',
    'Relaxing', 'Adventurous', 'Romantic', 'Family-friendly',
    'Pet-friendly', 'Historic', 'Modern', 'Natural', 'Urban'
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
                              mainPageState._onItemTapped(2); // 2 是 Mine Page 的索引
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
                  // Duration Selection
                  _buildSelectionCard(
                    title: 'Duration',
                    icon: Icons.timer,
                    children: _durations.map((duration) => _buildChip(
                      label: duration,
                      isSelected: duration == _selectedDuration,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedDuration = duration;
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
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue[200]!,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        if (_startPosition == null || _endPosition == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select start and end points')),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) {
                              return FadeTransition(
                                opacity: animation,
                                child: LoadingPage(
                                  startPosition: _startPosition!,
                                  endPosition: _endPosition!,
                                  selectedMoods: _selectedMoods,
                                ),
                              );
                            },
                            transitionDuration: const Duration(milliseconds: 500),
                            reverseTransitionDuration: const Duration(milliseconds: 300),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Start Navigation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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

class Step {
  final String instruction;
  final String distance;
  final String duration;
  final LatLng startLocation;
  final LatLng endLocation;

  Step({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
  });
}

class NavigationPage extends StatefulWidget {
  final LatLng startPosition;
  final LatLng endPosition;
  final Set<String> selectedMoods;
  final List<LatLng> optimizedPoints;
  final List<Step> steps;

  const NavigationPage({
    super.key,
    required this.startPosition,
    required this.endPosition,
    required this.selectedMoods,
    required this.optimizedPoints,
    required this.steps,
  });

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isGeneratingRoute = false;
  String? _routeInstructions;
  int _currentStep = 0;
  final List<Step> _steps = [];
  String? _totalDuration;
  List<String>? _representativePlaces;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _getRouteSummary();
  }

  void _initializeMap() {
    setState(() {
      _isGeneratingRoute = true;
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: widget.optimizedPoints,
        color: Colors.blue,
        width: 5,
      ));
      
      _markers.addAll({
        Marker(
          markerId: const MarkerId('start'),
          position: widget.startPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
        Marker(
          markerId: const MarkerId('end'),
          position: widget.endPosition,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      });

      if (widget.steps.isNotEmpty) {
        _routeInstructions = widget.steps[_currentStep].instruction;
        _steps.addAll(widget.steps);
      }
      _isGeneratingRoute = false;
    });

    // 移动地图以显示整个路线
    if (widget.optimizedPoints.isNotEmpty) {
      var bounds = widget.optimizedPoints.fold<LatLngBounds>(
        LatLngBounds(
          southwest: widget.optimizedPoints.first,
          northeast: widget.optimizedPoints.first,
        ),
        (bounds, point) => LatLngBounds(
          southwest: LatLng(
            math.min(bounds.southwest.latitude, point.latitude),
            math.min(bounds.southwest.longitude, point.longitude),
          ),
          northeast: LatLng(
            math.max(bounds.northeast.latitude, point.latitude),
            math.max(bounds.northeast.longitude, point.longitude),
          ),
        ),
      );

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  Future<void> _getRouteSummary() async {
    try {
      // 首先尝试使用步骤中的时间
      int totalSeconds = 0;
      for (var step in widget.steps) {
        final duration = step.duration;
        final match = RegExp(r'(\d+)\s+(\w+)').firstMatch(duration);
        if (match != null) {
          final value = int.parse(match.group(1)!);
          final unit = match.group(2)!;
          switch (unit) {
            case 'min':
              totalSeconds += value * 60;
              break;
            case 'hour':
              totalSeconds += value * 3600;
              break;
          }
        }
      }
      
      // 设置初始时间
      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;
      setState(() {
        _totalDuration = hours > 0 
          ? '$hours hours ${minutes} minutes' 
          : '$minutes minutes';
      });

      // 然后尝试从API获取更准确的时间
      final response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${widget.startPosition.latitude},${widget.startPosition.longitude}&'
        'destination=${widget.endPosition.latitude},${widget.endPosition.longitude}&'
        'mode=walking&'
        'key=${Config.googleMapsApiKey}'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'];
          
          // 计算所有路段的总时间
          int apiTotalSeconds = 0;
          for (var leg in legs) {
            apiTotalSeconds += leg['duration']['value'] as int;
          }
          
          // 更新时间为API返回的时间
          final apiHours = apiTotalSeconds ~/ 3600;
          final apiMinutes = (apiTotalSeconds % 3600) ~/ 60;
          if (mounted) {
            setState(() {
              _totalDuration = apiHours > 0 
                ? '$apiHours hours $apiMinutes minutes' 
                : '$apiMinutes minutes';
            });
          }
        }
      }

      // 获取代表性地点
      final places = <String>[];
      for (var point in widget.optimizedPoints) {
        final placeResponse = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
          'location=${point.latitude},${point.longitude}&'
          'radius=100&'
          'key=${Config.googleMapsApiKey}'
        ));

        if (placeResponse.statusCode == 200) {
          final placeData = json.decode(placeResponse.body);
          if (placeData['status'] == 'OK' && placeData['results'].isNotEmpty) {
            final place = placeData['results'][0];
            final name = place['name'] as String;
            if (!places.contains(name)) {
              places.add(name);
            }
          }
        }
      }

      // 选择最多5个代表性地点
      if (mounted) {
        setState(() {
          _representativePlaces = places.take(5).toList();
        });
      }
    } catch (e) {
      _logError('Error getting route summary: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.startPosition,
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.route,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
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
                      Text(
                        'Estimated Duration: ${_totalDuration ?? "Calculating..."}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
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
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() {
        _currentStep++;
        _routeInstructions = widget.steps[_currentStep].instruction;
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
    // 在实际应用中，这里应该使用适当的日志框架
    debugPrint(message);
  }
}

class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Mine Page'),
    );
  }
}

class LoadingPage extends StatefulWidget {
  final LatLng startPosition;
  final LatLng endPosition;
  final Set<String> selectedMoods;

  const LoadingPage({
    super.key,
    required this.startPosition,
    required this.endPosition,
    required this.selectedMoods,
  });

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  List<LatLng>? _optimizedPoints;
  List<Step>? _steps;
  bool _isRouteGenerated = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    // 主动画控制器（用于渐入渐出）
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // 旋转动画控制器（持续旋转）
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // 设置渐入动画
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    // 设置旋转动画（持续旋转）
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: Curves.linear,
      ),
    );

    // 先执行渐入动画
    _controller.forward().then((_) {
      // 渐入完成后开始生成路线
      _generateRoute();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _rotationController.dispose();
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateRoute() async {
    try {
      // 获取基础路线
      final response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${widget.startPosition.latitude},${widget.startPosition.longitude}&'
        'destination=${widget.endPosition.latitude},${widget.endPosition.longitude}&'
        'mode=walking&'
        'key=${Config.googleMapsApiKey}'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'][0];
          
          // 获取路线上的所有点
          final points = <LatLng>[];
          for (var step in legs['steps']) {
            points.add(LatLng(
              step['start_location']['lat'] as double,
              step['start_location']['lng'] as double,
            ));
            if (step['polyline'] != null) {
              final polylinePoints = _decodePolyline(step['polyline']['points'] as String);
              points.addAll(polylinePoints);
            }
          }
          points.add(LatLng(
            legs['end_location']['lat'] as double,
            legs['end_location']['lng'] as double,
          ));

          // 根据用户选择的情绪标签优化路线
          final optimizedPoints = await _optimizeRouteBasedOnMoods(points);

          // 获取步骤信息
          final steps = (legs['steps'] as List).map((step) => Step(
            instruction: _cleanHtmlInstructions(step['html_instructions'] as String),
            distance: step['distance']['text'] as String,
            duration: step['duration']['text'] as String,
            startLocation: LatLng(
              step['start_location']['lat'] as double,
              step['start_location']['lng'] as double,
            ),
            endLocation: LatLng(
              step['end_location']['lat'] as double,
              step['end_location']['lng'] as double,
            ),
          )).toList();

          if (mounted) {
            setState(() {
              _optimizedPoints = optimizedPoints;
              _steps = steps;
              _isRouteGenerated = true;
            });
            
            // 路线生成完成后，执行渐出动画
            _controller.reverse().then((_) {
              if (mounted) {
                _navigateToNavigationPage();
              }
            });
          }
        } else {
          _retryRouteGeneration();
        }
      } else {
        _retryRouteGeneration();
      }
    } catch (e) {
      _retryRouteGeneration();
    }
  }

  void _retryRouteGeneration() {
    // 每5秒重试一次
    _retryTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _generateRoute();
      }
    });
  }

  void _navigateToNavigationPage() {
    if (_optimizedPoints != null && _steps != null) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return FadeTransition(
              opacity: animation,
              child: NavigationPage(
                startPosition: widget.startPosition,
                endPosition: widget.endPosition,
                selectedMoods: widget.selectedMoods,
                optimizedPoints: _optimizedPoints!,
                steps: _steps!,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 300),
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Transform.rotate(
                      angle: _rotationAnimation.value * 2 * math.pi,
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
                          'Generating Your Experience',
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

  // 解码 Google Maps 的折线编码
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  // 清理 HTML 格式的导航指令
  String _cleanHtmlInstructions(String html) {
    // 移除 HTML 标签
    String clean = html.replaceAll(RegExp(r'<[^>]*>'), '');
    // 解码 HTML 实体
    clean = clean.replaceAll('&nbsp;', ' ');
    clean = clean.replaceAll('&amp;', '&');
    return clean;
  }

  Future<List<LatLng>> _optimizeRouteBasedOnMoods(List<LatLng> points) async {
    if (widget.selectedMoods.isEmpty) {
      return points; // 如果没有选择情绪标签，返回原始路线
    }

    // 每300米取一个关键点（减少间距以增加变化点）
    final keyPoints = <LatLng>[];
    double accumulatedDistance = 0;
    LatLng? lastPoint;
    
    for (final point in points) {
      if (lastPoint != null) {
        accumulatedDistance += _calculateDistance(lastPoint, point);
      }
      if (accumulatedDistance >= 300 || lastPoint == null) {
        keyPoints.add(point);
        accumulatedDistance = 0;
      }
      lastPoint = point;
    }
    if (points.last != keyPoints.last) {
      keyPoints.add(points.last);
    }

    // 根据情绪标签选择关键点作为途经点
    final preferences = {
      'quiet': widget.selectedMoods.contains('Quiet'),
      'bustling': widget.selectedMoods.contains('Bustling'),
      'freshAir': widget.selectedMoods.contains('Fresh Air'),
      'scenic': widget.selectedMoods.contains('Scenic'),
      'cultural': widget.selectedMoods.contains('Cultural'),
      'relaxing': widget.selectedMoods.contains('Relaxing'),
      'adventurous': widget.selectedMoods.contains('Adventurous'),
      'romantic': widget.selectedMoods.contains('Romantic'),
      'natural': widget.selectedMoods.contains('Natural'),
      'urban': widget.selectedMoods.contains('Urban'),
    };

    // 选择途经点
    final waypoints = <LatLng>[];
    
    // 计算总距离
    double totalDistance = 0;
    for (int i = 0; i < keyPoints.length - 1; i++) {
      totalDistance += _calculateDistance(keyPoints[i], keyPoints[i + 1]);
    }

    // 根据情绪标签选择途经点
    if (preferences['quiet']! || preferences['freshAir']! || preferences['relaxing']!) {
      // 选择距离主路较远的点，但保持路线方向
      for (int i = 1; i < keyPoints.length - 1; i++) {
        if (i % 2 == 1) { // 每两个点选一个，增加变化点
          final point = keyPoints[i];
          // 计算当前点到起点的距离比例
          double distanceRatio = 0;
          for (int j = 0; j < i; j++) {
            distanceRatio += _calculateDistance(keyPoints[j], keyPoints[j + 1]);
          }
          distanceRatio /= totalDistance;
          
          // 根据距离比例调整偏移方向，增加偏移量
          final direction = distanceRatio < 0.5 ? 1 : -1;
          final offsetLat = direction * 0.002; // 增加偏移量
          final offsetLng = direction * 0.002; // 增加偏移量
          
          waypoints.add(LatLng(
            point.latitude + offsetLat,
            point.longitude + offsetLng,
          ));
        }
      }
    } else if (preferences['bustling']! || preferences['urban']!) {
      // 选择距离主路较近的点，但增加一些变化
      for (int i = 0; i < keyPoints.length; i++) {
        if (i % 3 == 0) { // 每三个点选一个
          final point = keyPoints[i];
          // 添加较小的偏移，但保持城市特色
          final offsetLat = (math.Random().nextDouble() - 0.5) * 0.0015;
          final offsetLng = (math.Random().nextDouble() - 0.5) * 0.0015;
          waypoints.add(LatLng(
            point.latitude + offsetLat,
            point.longitude + offsetLng,
          ));
        }
      }
    } else if (preferences['scenic']! || preferences['romantic']!) {
      // 选择沿途的点，增加风景路线变化
      for (int i = 0; i < keyPoints.length; i++) {
        if (i % 2 == 0) { // 每两个点选一个，增加变化点
          final point = keyPoints[i];
          // 计算当前点到起点的距离比例
          double distanceRatio = 0;
          for (int j = 0; j < i; j++) {
            distanceRatio += _calculateDistance(keyPoints[j], keyPoints[j + 1]);
          }
          distanceRatio /= totalDistance;
          
          // 根据距离比例调整偏移方向，增加偏移量
          final direction = distanceRatio < 0.5 ? 1 : -1;
          final offsetLat = direction * 0.0015; // 增加偏移量
          final offsetLng = direction * 0.0015; // 增加偏移量
          
          waypoints.add(LatLng(
            point.latitude + offsetLat,
            point.longitude + offsetLng,
          ));
        }
      }
    } else {
      // 默认选择一些中间点，增加一些变化
      for (int i = 0; i < keyPoints.length; i++) {
        if (i % 3 == 0) { // 每三个点选一个
          final point = keyPoints[i];
          // 添加适中的偏移
          final offsetLat = (math.Random().nextDouble() - 0.5) * 0.001;
          final offsetLng = (math.Random().nextDouble() - 0.5) * 0.001;
          waypoints.add(LatLng(
            point.latitude + offsetLat,
            point.longitude + offsetLng,
          ));
        }
      }
    }

    // 限制途经点数量，最多使用4个（增加途经点数量）
    final limitedWaypoints = waypoints.length > 4 
      ? waypoints.sublist(0, 4) 
      : waypoints;

    // 确保途经点按顺序排列
    limitedWaypoints.sort((a, b) {
      final indexA = points.indexWhere((p) => 
        (p.latitude - a.latitude).abs() < 0.0001 && 
        (p.longitude - a.longitude).abs() < 0.0001
      );
      final indexB = points.indexWhere((p) => 
        (p.latitude - b.latitude).abs() < 0.0001 && 
        (p.longitude - b.longitude).abs() < 0.0001
      );
      return indexA.compareTo(indexB);
    });

    // 使用 Google Maps Directions API 获取实际道路的路线
    try {
      // 构建 waypoints 参数
      final waypointsParam = limitedWaypoints.map((point) => 
        'via:${point.latitude},${point.longitude}'
      ).join('|');

      // 获取新的路线
      final response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${widget.startPosition.latitude},${widget.startPosition.longitude}&'
        'destination=${widget.endPosition.latitude},${widget.endPosition.longitude}&'
        'waypoints=$waypointsParam&'
        'mode=walking&'
        'key=${Config.googleMapsApiKey}'
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'];
          
          // 获取路线上的所有点
          final optimizedPoints = <LatLng>[];
          for (var leg in legs) {
            for (var step in leg['steps']) {
              optimizedPoints.add(LatLng(
                step['start_location']['lat'] as double,
                step['start_location']['lng'] as double,
              ));
              if (step['polyline'] != null) {
                final polylinePoints = _decodePolyline(step['polyline']['points'] as String);
                optimizedPoints.addAll(polylinePoints);
              }
            }
          }
          optimizedPoints.add(LatLng(
            legs.last['end_location']['lat'] as double,
            legs.last['end_location']['lng'] as double,
          ));

          return optimizedPoints;
        }
      }
    } catch (e) {
      _logError('Error getting optimized route: $e');
    }

    // 如果获取优化路线失败，返回原始路线
    return points;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // 地球半径（米）
    final double lat1 = point1.latitude * math.pi / 180;
    final double lat2 = point2.latitude * math.pi / 180;
    final double deltaLat = (point2.latitude - point1.latitude) * math.pi / 180;
    final double deltaLng = (point2.longitude - point1.longitude) * math.pi / 180;

    final double a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  void _logError(String message) {
    // 在实际应用中，这里应该使用适当的日志框架
    debugPrint(message);
  }
} 