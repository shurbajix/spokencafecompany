import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  final LatLng? savedLocation;
  const MapScreen({Key? key, required this.savedLocation, required String lessonTitle, required String teacherName}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Location _location = Location();
  late GoogleMapController _mapController;
  late Set<Marker> _markers;
  late Set<Polyline> _polylines;
  LatLng? _currentLocation;
  LatLng? _savedLocation;
  BitmapDescriptor? _arrowIcon;

  // Navigation
  List<LatLng> _routePoints = [];
  int _currentStepIndex = 0;
  List<Map<String, dynamic>> _steps = [];
  bool _isNavigating = false;
  LocationData? _previousPosition;
  StreamSubscription<LocationData>? _locationSubscription;
  bool _isLoading = false;
  double _currentBearing = 0;
  double _currentTilt = 45;

  static const String _directionsApiKey = 'AIzaSyBNtuDjMN2WtiCkHwJ2ZCzMODeXTqKUuM0';

  @override
  void initState() {
    super.initState();
    _markers = {};
    _polylines = {};
    _savedLocation = widget.savedLocation;
    _location.changeSettings(accuracy: LocationAccuracy.high, interval: 1000);
    _getCurrentLocation();
    _createArrowIcon();
  }

  Future<void> _createArrowIcon() async {
    final Uint8List? arrowBytes = await _getBytesFromAsset('assets/images/arrow.png', 80);
    if (arrowBytes != null) {
      _arrowIcon = BitmapDescriptor.fromBytes(arrowBytes);
    }
  }

  Future<Uint8List?> _getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoading = true);
      final currentLocation = await _location.getLocation();
      setState(() {
        _currentLocation = LatLng(currentLocation.latitude!, currentLocation.longitude!);
        _isLoading = false;
      });

      if (_mapController != null) {
        _mapController.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation!,
            zoom: 17,
            tilt: _currentTilt,
            bearing: _currentBearing,
          ),
        ));
      }

      _updateMarkers();
    } catch (e) {
      print("Error getting current location: $e");
      setState(() => _isLoading = false);
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();
      if (_currentLocation != null) {
        _markers.add(Marker(
          markerId: const MarkerId("currentLocation"),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ));
      }
      if (_savedLocation != null) {
        _markers.add(Marker(
          markerId: const MarkerId("destination"),
          position: _savedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ));
      }
    });
  }

  Future<void> _getDirections() async {
    if (_currentLocation == null || _savedLocation == null) return;

    setState(() => _isLoading = true);

    final origin = '${_currentLocation!.latitude},${_currentLocation!.longitude}';
    final destination = '${_savedLocation!.latitude},${_savedLocation!.longitude}';

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?'
      'origin=$origin&destination=$destination&key=$_directionsApiKey&mode=walking&language=tr'
    );

    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final route = data['routes'][0];
        _parseRoute(route);
        _startNavigation();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Error: ${data['status']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Directions error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Error getting directions'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _parseRoute(Map<String, dynamic> route) {
    final points = route['overview_polyline']['points'];
    _routePoints = _decodePoly(points);

    _steps = [];
    route['legs'][0]['steps'].forEach((step) {
      _steps.add({
        'instruction': step['html_instructions']
            .toString()
            .replaceAll(RegExp(r'<[^>]*>|'), ''),
        'distance': step['distance']['text'],
        'duration': step['duration']['text'],
        'end_location': LatLng(
          step['end_location']['lat'],
          step['end_location']['lng'],
        ),
      });
    });

    setState(() {
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId('nav_route'),
        points: _routePoints,
        color: Colors.blue,
        width: 5,
      ));
    });
  }

  List<LatLng> _decodePoly(String encoded) {
    final List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  void _startNavigation() {
    setState(() => _isNavigating = true);
    _locationSubscription = _location.onLocationChanged.listen((position) {
      _updatePosition(position);
    });
  }

  void _updatePosition(LocationData newPosition) async {
    if (!_isNavigating) return;

    final currentLatLng = LatLng(newPosition.latitude!, newPosition.longitude!);
    _currentBearing = newPosition.heading ?? _currentBearing;

    setState(() {
      _markers.removeWhere((m) => m.markerId == const MarkerId('currentLocation'));
      _markers.removeWhere((m) => m.markerId == const MarkerId('directionArrow'));

      _markers.add(Marker(
        markerId: const MarkerId('currentLocation'),
        position: currentLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));

      if (_arrowIcon != null) {
        _markers.add(Marker(
          markerId: const MarkerId('directionArrow'),
          position: currentLatLng,
          icon: _arrowIcon!,
          anchor: const Offset(0.5, 0.5),
          rotation: _currentBearing,
        ));
      }
    });

    if (_mapController != null) {
      _mapController.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentLatLng,
          zoom: 17,
          tilt: _currentTilt,
          bearing: _currentBearing,
        ),
      ));
    }

    if (_currentStepIndex < _steps.length) {
      final nextStepPoint = _steps[_currentStepIndex]['end_location'];
      final distance = _calculateDistance(currentLatLng, nextStepPoint);

      if (distance < 20) {
        setState(() => _currentStepIndex++);
        if (_currentStepIndex < _steps.length) {
          _showNextStepNotification();
        } else {
          _showArrivalNotification();
        }
      }
    }
  }

  void _showNextStepNotification() {
    if (_currentStepIndex < _steps.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_steps[_currentStepIndex]['instruction']),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _showArrivalNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('You have arrived at your destination!'),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.green,
      ),
    );
    _stopNavigation();
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const earthRadius = 6371000;
    final dLat = _toRadians(p2.latitude - p1.latitude);
    final dLon = _toRadians(p2.longitude - p1.longitude);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(p1.latitude)) *
            cos(_toRadians(p2.latitude)) *
            sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _currentStepIndex = 0;
      _steps.clear();
      _polylines.clear();
    });
    _locationSubscription?.cancel();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xff1B1212)),
        ),
        backgroundColor: Colors.white,
        title: const Text(
          "Location",
          style: TextStyle(
            color: Color(0xff1B1212),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(39.9334, 32.8597),
              zoom: 14,
              tilt: _currentTilt,
              bearing: _currentBearing,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentLocation != null) {
                _mapController.animateCamera(CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _currentLocation!,
                    zoom: 17,
                    tilt: _currentTilt,
                    bearing: _currentBearing,
                  ),
                ));
              }
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
            minMaxZoomPreference: const MinMaxZoomPreference(10, 18),
            tiltGesturesEnabled: true,
            compassEnabled: true,
            buildingsEnabled: false,
            mapType: MapType.normal,
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                 color:  Color(0xff1B1212),
                  backgroundColor: Colors.white,
              ),
            ),
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'compass',
                  mini: true,
                  onPressed: () {
                    _mapController.animateCamera(CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: _currentLocation ?? const LatLng(39.9334, 32.8597),
                        zoom: 17,
                        tilt: _currentTilt,
                        bearing: 0,
                      ),
                    ));
                    setState(() {
                      _currentBearing = 0;
                    });
                  },
                  child: const Icon(Icons.explore),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'tilt',
                  mini: true,
                  onPressed: () {
                    final newTilt = _currentTilt == 0 ? 45 : 0;
                    _mapController.animateCamera(CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: _currentLocation ?? const LatLng(39.9334, 32.8597),
                        zoom: 17,
                        tilt: newTilt.toDouble(),
                        bearing: _currentBearing,
                      ),
                    ));
                    setState(() {
                      _currentTilt = newTilt.toDouble();
                    });
                  },
                  child: Icon(_currentTilt == 0 ? Icons.arrow_forward_ios : Icons.arrow_back_ios),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildNavigationControls(),
      floatingActionButton: _isNavigating ? _buildNavigationInfo() : null,
    );
  }

  Widget _buildNavigationControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isNavigating)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _stopNavigation,
              child: const Text(
                'Stop Walking',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff1B1212),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isLoading ? null : _getDirections,
              child: Text(
                _isLoading ? 'Loading...' : 'Start Walking',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationInfo() {
    String directionIcon = '🚶';
    if (_currentStepIndex < _steps.length) {
      final instruction = _steps[_currentStepIndex]['instruction'].toLowerCase();
      if (instruction.contains('left')) directionIcon = '⬅️';
      else if (instruction.contains('right')) directionIcon = '➡️';
      else if (instruction.contains('straight')) directionIcon = '⬆️';
    }

    return FloatingActionButton.extended(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => _buildInstructionsSheet(),
        );
      },
      icon: Text(directionIcon, style: const TextStyle(fontSize: 24)),
      label: Text('Step ${_currentStepIndex + 1} of ${_steps.length}'),
      backgroundColor: Colors.blue,
    );
  }

  Widget _buildInstructionsSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Location',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          if (_currentStepIndex < _steps.length) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Step',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _steps[_currentStepIndex]['instruction'],
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_steps[_currentStepIndex]['distance']} • ${_steps[_currentStepIndex]['duration']}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Upcoming Steps',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                final isCurrentStep = index == _currentStepIndex;
                final isCompleted = index < _currentStepIndex;

                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCurrentStep
                          ? Colors.blue
                          : isCompleted
                              ? Colors.green
                              : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrentStep || isCompleted
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    _steps[index]['instruction'],
                    style: TextStyle(
                      fontWeight: isCurrentStep ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${_steps[index]['distance']} • ${_steps[index]['duration']}',
                    style: TextStyle(
                      color: isCompleted ? Colors.green : Colors.grey.shade600,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


// import 'dart:async';
// import 'dart:convert';
// import 'dart:math';
// import 'dart:ui' as ui;

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:location/location.dart';
// import 'package:http/http.dart' as http;

// class MapScreen extends StatefulWidget {
//   final LatLng? savedLocation;
//   const MapScreen({Key? key, required this.savedLocation, required lessonTitle, required teacherName}) : super(key: key);

//   @override
//   _MapScreenState createState() => _MapScreenState();
// }

// class _MapScreenState extends State<MapScreen> {
//   Location _location = Location();
//   late GoogleMapController _mapController;
//   late Set<Marker> _markers;
//   late Set<Polyline> _polylines;
//   LatLng? _currentLocation;
//   LatLng? _savedLocation;
//   BitmapDescriptor? _arrowIcon;

//   // Navigation
//   List<LatLng> _routePoints = [];
//   int _currentStepIndex = 0;
//   List<Map<String, dynamic>> _steps = [];
//   bool _isNavigating = false;
//   LocationData? _previousPosition;
//   StreamSubscription<LocationData>? _locationSubscription;
//   bool _isLoading = false;
//   double _currentBearing = 0;
//   double _currentTilt = 45;

//   static const String _directionsApiKey = 'AIzaSyBNtuDjMN2WtiCkHwJ2ZCzMODeXTqKUuM0';

//   @override
//   void initState() {
//     super.initState();
//     _markers = {};
//     _polylines = {};
//     _savedLocation = widget.savedLocation;
//     _location.changeSettings(accuracy: LocationAccuracy.high, interval: 1000);
//     _getCurrentLocation();
//     _createArrowIcon();
//   }

//   Future<void> _createArrowIcon() async {
//     final Uint8List? arrowBytes = await _getBytesFromAsset('assets/images/arrow.png', 80);
//     if (arrowBytes != null) {
//       _arrowIcon = BitmapDescriptor.fromBytes(arrowBytes);
//     }
//   }

//   Future<Uint8List?> _getBytesFromAsset(String path, int width) async {
//     ByteData data = await rootBundle.load(path);
//     ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
//     ui.FrameInfo fi = await codec.getNextFrame();
//     return (await fi.image.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();
//   }

//   Future<void> _getCurrentLocation() async {
//     try {
//       setState(() => _isLoading = true);
//       final currentLocation = await _location.getLocation();
//       setState(() {
//         _currentLocation = LatLng(currentLocation.latitude!, currentLocation.longitude!);
//         _isLoading = false;
//       });

//       if (_mapController != null) {
//         _mapController.animateCamera(CameraUpdate.newCameraPosition(
//           CameraPosition(
//             target: _currentLocation!,
//             zoom: 17,
//             tilt: _currentTilt,
//             bearing: _currentBearing,
//           ),
//         ));
//       }

//       _updateMarkers();
//     } catch (e) {
//       print("Error getting current location: $e");
//       setState(() => _isLoading = false);
//     }
//   }

//   void _updateMarkers() {
//     setState(() {
//       _markers.clear();
//       if (_currentLocation != null) {
//         _markers.add(Marker(
//           markerId: const MarkerId("currentLocation"),
//           position: _currentLocation!,
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//         ));
//       }
//       if (_savedLocation != null) {
//         _markers.add(Marker(
//           markerId: const MarkerId("destination"),
//           position: _savedLocation!,
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
//         ));
//       }
//     });
//   }

//   Future<void> _getDirections() async {
//     if (_currentLocation == null || _savedLocation == null) return;

//     setState(() => _isLoading = true);

//     final origin = '${_currentLocation!.latitude},${_currentLocation!.longitude}';
//     final destination = '${_savedLocation!.latitude},${_savedLocation!.longitude}';

//     final url = Uri.parse(
//       'https://maps.googleapis.com/maps/api/directions/json?'
//       'origin=$origin&destination=$destination&key=$_directionsApiKey&mode=walking&language=tr'
//     );

//     try {
//       final response = await http.get(url);
//       final data = json.decode(response.body);

//       if (data['status'] == 'OK') {
//         final route = data['routes'][0];
//         _parseRoute(route);
//         _startNavigation();
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error: ${data['status']}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } catch (e) {
//       print('Directions error: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Error getting directions'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   void _parseRoute(Map<String, dynamic> route) {
//     final points = route['overview_polyline']['points'];
//     _routePoints = _decodePoly(points);

//     _steps = [];
//     route['legs'][0]['steps'].forEach((step) {
//       _steps.add({
//         'instruction': step['html_instructions']
//             .toString()
//             .replaceAll(RegExp(r'<[^>]*>|'), ''),
//         'distance': step['distance']['text'],
//         'duration': step['duration']['text'],
//         'end_location': LatLng(
//           step['end_location']['lat'],
//           step['end_location']['lng'],
//         ),
//       });
//     });

//     setState(() {
//       _polylines.clear();
//       _polylines.add(Polyline(
//         polylineId: const PolylineId('nav_route'),
//         points: _routePoints,
//         color: Colors.blue,
//         width: 5,
//       ));
//     });
//   }

//   List<LatLng> _decodePoly(String encoded) {
//     final List<LatLng> points = [];
//     int index = 0, len = encoded.length;
//     int lat = 0, lng = 0;

//     while (index < len) {
//       int b, shift = 0, result = 0;
//       do {
//         b = encoded.codeUnitAt(index++) - 63;
//         result |= (b & 0x1f) << shift;
//         shift += 5;
//       } while (b >= 0x20);
//       int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
//       lat += dlat;

//       shift = 0;
//       result = 0;
//       do {
//         b = encoded.codeUnitAt(index++) - 63;
//         result |= (b & 0x1f) << shift;
//         shift += 5;
//       } while (b >= 0x20);
//       int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
//       lng += dlng;

//       points.add(LatLng(lat / 1e5, lng / 1e5));
//     }
//     return points;
//   }

//   void _startNavigation() {
//     setState(() => _isNavigating = true);
//     _locationSubscription = _location.onLocationChanged.listen((position) {
//       _updatePosition(position);
//     });
//   }

//   void _updatePosition(LocationData newPosition) async {
//     if (!_isNavigating) return;

//     final currentLatLng = LatLng(newPosition.latitude!, newPosition.longitude!);
//     _currentBearing = newPosition.heading ?? _currentBearing;

//     setState(() {
//       _markers.removeWhere((m) => m.markerId == const MarkerId('currentLocation'));
//       _markers.removeWhere((m) => m.markerId == const MarkerId('directionArrow'));

//       _markers.add(Marker(
//         markerId: const MarkerId('currentLocation'),
//         position: currentLatLng,
//         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//       ));

//       if (_arrowIcon != null) {
//         _markers.add(Marker(
//           markerId: const MarkerId('directionArrow'),
//           position: currentLatLng,
//           icon: _arrowIcon!,
//           anchor: const Offset(0.5, 0.5),
//           rotation: _currentBearing,
//         ));
//       }
//     });

//     if (_mapController != null) {
//       _mapController.animateCamera(CameraUpdate.newCameraPosition(
//         CameraPosition(
//           target: currentLatLng,
//           zoom: 17,
//           tilt: _currentTilt,
//           bearing: _currentBearing,
//         ),
//       ));
//     }

//     if (_currentStepIndex < _steps.length) {
//       final nextStepPoint = _steps[_currentStepIndex]['end_location'];
//       final distance = _calculateDistance(currentLatLng, nextStepPoint);

//       if (distance < 20) {
//         setState(() => _currentStepIndex++);
//         if (_currentStepIndex < _steps.length) {
//           _showNextStepNotification();
//         } else {
//           _showArrivalNotification();
//         }
//       }
//     }
//   }

//   void _showNextStepNotification() {
//     if (_currentStepIndex < _steps.length) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(_steps[_currentStepIndex]['instruction']),
//           duration: const Duration(seconds: 3),
//           backgroundColor: Colors.blue,
//         ),
//       );
//     }
//   }

//   void _showArrivalNotification() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text('You have arrived at your destination!'),
//         duration: const Duration(seconds: 3),
//         backgroundColor: Colors.green,
//       ),
//     );
//     _stopNavigation();
//   }

//   double _calculateDistance(LatLng p1, LatLng p2) {
//     const earthRadius = 6371000;
//     final dLat = _toRadians(p2.latitude - p1.latitude);
//     final dLon = _toRadians(p2.longitude - p1.longitude);

//     final a = sin(dLat / 2) * sin(dLat / 2) +
//         cos(_toRadians(p1.latitude)) *
//             cos(_toRadians(p2.latitude)) *
//             sin(dLon / 2) * sin(dLon / 2);

//     final c = 2 * atan2(sqrt(a), sqrt(1 - a));
//     return earthRadius * c;
//   }

//   double _toRadians(double degrees) => degrees * pi / 180;

//   void _stopNavigation() {
//     setState(() {
//       _isNavigating = false;
//       _currentStepIndex = 0;
//       _steps.clear();
//       _polylines.clear();
//     });
//     _locationSubscription?.cancel();
//   }

//   @override
//   void dispose() {
//     _locationSubscription?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         centerTitle: true,
//         leading: IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xff1B1212)),
//         ),
//         backgroundColor: Colors.white,
//         title: const Text(
//           "Location",
//           style: TextStyle(
//             color: Color(0xff1B1212),
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ),
//       body: Stack(
//         children: [
//           GoogleMap(
//             initialCameraPosition: CameraPosition(
//               target: _currentLocation ?? const LatLng(39.9334, 32.8597),
//               zoom: 14,
//               tilt: _currentTilt,
//               bearing: _currentBearing,
//             ),
//             onMapCreated: (controller) {
//               _mapController = controller;
//               if (_currentLocation != null) {
//                 _mapController.animateCamera(CameraUpdate.newCameraPosition(
//                   CameraPosition(
//                     target: _currentLocation!,
//                     zoom: 17,
//                     tilt: _currentTilt,
//                     bearing: _currentBearing,
//                   ),
//                 ));
//               }
//             },
//             markers: _markers,
//             polylines: _polylines,
//             myLocationEnabled: true,
//             myLocationButtonEnabled: true,
//             zoomControlsEnabled: true,
//             mapToolbarEnabled: true,
//             minMaxZoomPreference: const MinMaxZoomPreference(10, 18),
//             tiltGesturesEnabled: true,
//             compassEnabled: true,
//             buildingsEnabled: false, // Disabled buildings
//             mapType: MapType.normal, // Keep normal map type but without buildings
//           ),
//           if (_isLoading)
//             const Center(
//               child: CircularProgressIndicator(),
//             ),
//           Positioned(
//             right: 16,
//             bottom: 120,
//             child: Column(
//               children: [
//                 FloatingActionButton(
//                   heroTag: 'compass',
//                   mini: true,
//                   onPressed: () {
//                     _mapController.animateCamera(CameraUpdate.newCameraPosition(
//                       CameraPosition(
//                         target: _currentLocation ?? const LatLng(39.9334, 32.8597),
//                         zoom: 17,
//                         tilt: _currentTilt,
//                         bearing: 0,
//                       ),
//                     ));
//                     setState(() {
//                       _currentBearing = 0;
//                     });
//                   },
//                   child: const Icon(Icons.explore),
//                 ),
//                 const SizedBox(height: 8),
//                 FloatingActionButton(
//                   heroTag: 'tilt',
//                   mini: true,
//                   onPressed: () {
//                     final newTilt = _currentTilt == 0 ? 45 : 0;
//                     _mapController.animateCamera(CameraUpdate.newCameraPosition(
//                       CameraPosition(
//                         target: _currentLocation ?? const LatLng(39.9334, 32.8597),
//                         zoom: 17,
//                         tilt: newTilt as double,
//                         bearing: _currentBearing,
//                       ),
//                     ));
//                     setState(() {
//                       _currentTilt = newTilt as double;
//                     });
//                   },
//                   child: Icon(_currentTilt == 0 ? Icons.arrow_forward_ios : Icons.arrow_back_ios),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//       bottomNavigationBar: _buildNavigationControls(),
//       floatingActionButton: _isNavigating ? _buildNavigationInfo() : null,
//     );
//   }

//   Widget _buildNavigationControls() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 10,
//             offset: const Offset(0, -5),
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           if (_isNavigating)
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red,
//                 minimumSize: const Size(double.infinity, 50),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//               ),
//               onPressed: _stopNavigation,
//               child: const Text(
//                 'Stop Walking',
//                 style: TextStyle(color: Colors.white, fontSize: 18),
//               ),
//             )
//           else
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xff1B1212),
//                 minimumSize: const Size(double.infinity, 50),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//               ),
//               onPressed: _isLoading ? null : _getDirections,
//               child: Text(
//                 _isLoading ? 'Loading...' : 'Start Walking',
//                 style: const TextStyle(color: Colors.white, fontSize: 18),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildNavigationInfo() {
//     String directionIcon = '🚶';
//     if (_currentStepIndex < _steps.length) {
//       final instruction = _steps[_currentStepIndex]['instruction'].toLowerCase();
//       if (instruction.contains('left')) directionIcon = '⬅️';
//       else if (instruction.contains('right')) directionIcon = '➡️';
//       else if (instruction.contains('straight')) directionIcon = '⬆️';
//     }

//     return FloatingActionButton.extended(
//       onPressed: () {
//         showModalBottomSheet(
//           context: context,
//           isScrollControlled: true,
//           shape: const RoundedRectangleBorder(
//             borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//           ),
//           builder: (context) => _buildInstructionsSheet(),
//         );
//       },
//       icon: Text(directionIcon, style: const TextStyle(fontSize: 24)),
//       label: Text('Step ${_currentStepIndex + 1} of ${_steps.length}'),
//       backgroundColor: Colors.blue,
//     );
//   }

//   Widget _buildInstructionsSheet() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       height: MediaQuery.of(context).size.height * 0.6,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text(
//                 'Location',
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//               ),
//               IconButton(
//                 icon: const Icon(Icons.close),
//                 onPressed: () => Navigator.pop(context),
//               ),
//             ],
//           ),
//           const Divider(),
//           if (_currentStepIndex < _steps.length) ...[
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.blue.shade50,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Current Step',
//                     style: TextStyle(
//                       color: Colors.blue.shade700,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     _steps[_currentStepIndex]['instruction'],
//                     style: const TextStyle(fontSize: 18),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     '${_steps[_currentStepIndex]['distance']} • ${_steps[_currentStepIndex]['duration']}',
//                     style: TextStyle(
//                       color: Colors.grey.shade600,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//           const SizedBox(height: 16),
//           const Text(
//             'Upcoming Steps',
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Expanded(
//             child: ListView.builder(
//               itemCount: _steps.length,
//               itemBuilder: (context, index) {
//                 final isCurrentStep = index == _currentStepIndex;
//                 final isCompleted = index < _currentStepIndex;

//                 return ListTile(
//                   leading: Container(
//                     width: 32,
//                     height: 32,
//                     decoration: BoxDecoration(
//                       color: isCurrentStep
//                           ? Colors.blue
//                           : isCompleted
//                               ? Colors.green
//                               : Colors.grey.shade300,
//                       shape: BoxShape.circle,
//                     ),
//                     child: Center(
//                       child: Text(
//                         '${index + 1}',
//                         style: TextStyle(
//                           color: isCurrentStep || isCompleted
//                               ? Colors.white
//                               : Colors.black,
//                         ),
//                       ),
//                     ),
//                   ),
//                   title: Text(
//                     _steps[index]['instruction'],
//                     style: TextStyle(
//                       fontWeight: isCurrentStep ? FontWeight.bold : FontWeight.normal,
//                     ),
//                   ),
//                   subtitle: Text(
//                     '${_steps[index]['distance']} • ${_steps[index]['duration']}',
//                     style: TextStyle(
//                       color: isCompleted ? Colors.green : Colors.grey.shade600,
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }






// //'AIzaSyBNtuDjMN2WtiCkHwJ2ZCzMODeXTqKUuM0';

