import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class FullScreenMap extends StatefulWidget {
  final LatLng initialPosition;
  final String heroTag;
  final GoogleMapController? previewController;
  final CameraPosition? initialCameraPosition;

  const FullScreenMap({
    super.key,
    required this.initialPosition,
    required this.heroTag,
    this.previewController,
    this.initialCameraPosition,
  });

  @override
  State<FullScreenMap> createState() => _FullScreenMapState();
}

class _FullScreenMapState extends State<FullScreenMap> {
  late GoogleMapController _mapController;
  Position? _currentPosition;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
      if (widget.previewController == null && widget.initialCameraPosition == null) {
        _mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15,
            ),
          ),
          duration: const Duration(milliseconds: 500),
        );
      }
    } catch (e) {
      // 处理错误
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Hero(
            tag: widget.heroTag,
            child: Container(
              color: Colors.white,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: widget.initialCameraPosition ?? CameraPosition(
                      target: widget.initialPosition,
                      zoom: 15,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (widget.previewController != null) {
                        widget.previewController!.getVisibleRegion().then((bounds) {
                          final center = LatLng(
                            (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
                            (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
                          );
                          controller.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: center,
                                zoom: 15,
                              ),
                            ),
                          );
                        });
                      }
                      setState(() {
                        _isMapReady = true;
                      });
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    markers: _currentPosition != null
                        ? {
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
                          }
                        : {},
                  ),
                  if (!_isMapReady)
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
} 