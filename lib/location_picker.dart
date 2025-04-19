import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_webservice/places.dart';

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
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;
  String _selectedAddress = '';
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final GoogleMapsPlaces _placesService = GoogleMapsPlaces(apiKey: 'AIzaSyAMw8_JlFSx1EzaEJvpAdc0hd2lVc9CX3c');
  List<Prediction> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    if (widget.initialPosition != null) {
      setState(() {
        _selectedPosition = widget.initialPosition;
        _isLoading = false;
      });
      _getAddressFromPosition(widget.initialPosition!);
    } else {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _selectedPosition = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        _getAddressFromPosition(_selectedPosition!);
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getAddressFromPosition(LatLng position) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final address = [
          if (place.name != null && place.name!.isNotEmpty) place.name,
          if (place.locality != null && place.locality!.isNotEmpty) place.locality,
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) place.administrativeArea,
          if (place.country != null && place.country!.isNotEmpty) place.country,
        ].where((element) => element != null).join(', ');
        
        setState(() {
          _selectedAddress = address;
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = 'Unknown Location';
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

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await _placesService.autocomplete(
        query,
        location: _selectedPosition != null
            ? Location(
                lat: _selectedPosition!.latitude,
                lng: _selectedPosition!.longitude,
              )
            : null,
        radius: 50000,
      );

      setState(() {
        _searchResults = response.predictions;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _selectPlace(Prediction prediction) async {
    final placeId = prediction.placeId;
    if (placeId == null) return;
    
    try {
      final response = await _placesService.getDetailsByPlaceId(placeId);
      final result = response.result;
      if (result?.geometry?.location != null) {
        final location = result!.geometry!.location;
        final position = LatLng(location.lat, location.lng);
        
        setState(() {
          _selectedPosition = position;
          _selectedAddress = result.formattedAddress ?? prediction.description ?? 'Unknown Location';
          _searchResults = [];
          _searchController.text = prediction.description ?? '';
        });

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: position,
              zoom: 15,
            ),
          ),
        );
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_selectedPosition != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context, {
                  'position': _selectedPosition,
                  'address': _selectedAddress,
                });
              },
              child: const Text(
                'Select',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedPosition!,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  onTap: (position) {
                    setState(() {
                      _selectedPosition = position;
                    });
                    _getAddressFromPosition(position);
                  },
                  markers: _selectedPosition != null
                      ? {
                          Marker(
                            markerId: const MarkerId('selectedLocation'),
                            position: _selectedPosition!,
                            draggable: true,
                            onDragEnd: (position) {
                              setState(() {
                                _selectedPosition = position;
                              });
                              _getAddressFromPosition(position);
                            },
                          ),
                        }
                      : {},
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 77),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search location...',
                            border: InputBorder.none,
                            icon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _searchPlaces('');
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: _searchPlaces,
                        ),
                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        if (_searchResults.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final prediction = _searchResults[index];
                                return ListTile(
                                  leading: const Icon(Icons.location_on),
                                  title: Text(
                                    prediction.description!,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  onTap: () => _selectPlace(prediction),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 48,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 77),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Selected Location:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedAddress.isEmpty ? 'Tap on map to select location' : _selectedAddress,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _selectedPosition != null
                                ? () {
                                    Navigator.pop(context, {
                                      'position': _selectedPosition,
                                      'address': _selectedAddress,
                                    });
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Confirm Selection',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 