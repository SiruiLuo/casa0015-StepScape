import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'full_screen_map.dart';
import 'location_picker.dart';

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
                          const Text(
                            'Current Location',
                            style: TextStyle(
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
  
  final List<String> _routeTypes = ['One-way', 'Round Trip'];
  final List<String> _themes = ['Short Trip', 'Walking', 'Jogging', 'Cycling', 'Hiking'];
  final List<String> _durations = ['15 min', '30 min', '1 hour', '2 hours', '3 hours', '4 hours', '5 hours', 'Full day'];
  final List<String> _moods = [
    'Quiet', 'Bustling', 'Fresh Air', 'Scenic', 'Cultural',
    'Relaxing', 'Adventurous', 'Romantic', 'Family-friendly',
    'Pet-friendly', 'Historic', 'Modern', 'Natural', 'Urban'
  ];

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
                    // TODO: Implement next step functionality
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
                    'Next',
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