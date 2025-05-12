import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:geolocator/geolocator.dart'; // Standard location library
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:spokencafe/Map/Search_Map.dart';
import 'package:spokencafe/Notifiction/Notifiction.dart';
import 'package:spokencafe/Notifiction/notification_class.dart';
import 'package:spokencafe/util/Color.dart';



/// Utility to perform HTTP GET requests
class NetworkUtil {
  static Future<String?> fetchUrl(Uri uri) async {
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return response.body;
      } else {
        debugPrint('Failed with status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching URL: $e');
    }
    return null;
  }
}


class MyBottomSheet extends StatefulWidget {
  final Function(String, DateTime, String, String) onSave;

  const MyBottomSheet({
    super.key,
    required this.onSave,
  });

  @override
  _MyBottomSheetState createState() => _MyBottomSheetState();
}

class _MyBottomSheetState extends State<MyBottomSheet> {
    GoogleMapController? _googleMapController;
    LatLng? _currentLocation;
  int? selectedIndex;
  DateTime dateTime = DateTime.now();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  String locationMessage = 'Current Location of the User';
  StreamSubscription<Position>? positionStream;
  Timer? countdownTimer;
  String countdownText = '';
  List<PredictionModel> _filteredPredictions = [];
  bool _showPredictions = false;
  String selectedLocation = '';
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();
  bool allowMapTap = false;
  
  late Position _position;
  List<Marker> myMarker = [];
  List<Polyline> _polylines = [];
  String _selectedLocationName = '';
  List<LatLng> polylineCoordinates = [];
  bool isLoading = false;


  List<String> speakleveltext = [
    'I Can\'t Speak',
    'I Can Speak',
    'I Can Speak Fluently',
    'I Can Speak Super',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
     _searchController.removeListener(_onSearchChanged);
    positionStream?.cancel();
    descriptionController.dispose();
    searchController.dispose();
    _searchController.dispose();
    countdownTimer?.cancel();
    super.dispose();
  }


  // here come to here 
   void _onSearchChanged() {
    // Debounce the search input to avoid unnecessary API calls
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchLocation(_searchController.text);
    });
  }

Future<void> _saveToFirestore() async {
  if (selectedIndex == null || descriptionController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        content: Text('Please select a speak level and enter a description.'),
        duration: Duration(seconds: 3),
    ),
    );
    return;
  }

  try {
    final int index = selectedIndex!;
    final String speakLevel = speakleveltext[index];
    final double latitude = _currentLocation!.latitude;
    final double longitude = _currentLocation!.longitude;
    final String locationName = _selectedLocationName;
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          content: Text('Teacher not logged in.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Create document reference and get ID first
    final docRef = FirebaseFirestore.instance.collection('lessons').doc();
    final String lessonId = docRef.id;
    final String teacherId = user.uid;

    await docRef.set({
      'lessonId': lessonId,  // Explicit lesson ID
      'teacherId': teacherId,  // Current teacher's UID
      'speakLevel': speakLevel,
      'dateTime': dateTime.toIso8601String(),  // Store as ISO string
      'description': descriptionController.text,
      'location': GeoPoint(latitude, longitude),
      'locationName': locationName,
      'createdAt': FieldValue.serverTimestamp(),
      'students': [],
    });

    final notification = LocalNotificationModel(
      title: 'Lesson Created',
      body: 'Speak level: $speakLevel — ${descriptionController.text}',
      timestamp: DateTime.now(),
    );
    await NotificationStorage.addNotification(notification);

    startCountdown();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        content: Text('Lesson created successfully!'),
        duration: Duration(seconds: 3),
      ),
    );

    NotificationService().showNotification(
      title: 'Lesson Created',
      body: 'Your lesson has been submitted successfully.',
    );

    Navigator.pop(context);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
        content: Text('Failed to create lesson: ${e.toString()}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}


  void startCountdown() {
    if (dateTime.isBefore(DateTime.now())) {
      setState(() {
        countdownText = 'Lesson started!';
      });
      return;
    }

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final remaining = dateTime.difference(now);

      if (remaining.isNegative) {
        timer.cancel();
        if (mounted) {
          setState(() {
            countdownText = 'Lesson started!';
          });
        }
      } else {
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes.remainder(60);
        final seconds = remaining.inSeconds.remainder(60);

        if (mounted) {
          setState(() {
            countdownText = 'Lesson starts in: '
                '${hours.toString().padLeft(2, '0')}:'
                '${minutes.toString().padLeft(2, '0')}:'
                '${seconds.toString().padLeft(2, '0')}';
          });
        }
      }
    });
  }
  
  Future<void> _searchLocation(String query) async {
  if (query.isEmpty) {
    setState(() {
      _filteredPredictions = [];
      _showPredictions = false;
    });
    return;
  }

  setState(() {
    isLoading = true;  // Set loading to true when search starts
  });

  final apiKey = 'AIzaSyC5o3TwRWy4qzIFK5H3mhEYbKB0q_0-HbE';
  final url =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey&components=country:tr';

  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);

      final List<PredictionModel> predictions = (data['predictions'] as List)
          .map((item) => PredictionModel.fromAutocomplete(item))
          .toList();

      setState(() {
        _filteredPredictions = predictions;
        _showPredictions = true;
      });
    } else {
      setState(() {
        _filteredPredictions = [];
        _showPredictions = false;
      });
    }
  } catch (e) {
    setState(() {
      _filteredPredictions = [];
      _showPredictions = false;
    });
  } finally {
    setState(() {
      isLoading = false;  // Set loading to false when search is complete
    });
  }
}
void _selectLocation(PredictionModel prediction) async {
  final placeDetails = await getPlaceDetails(prediction.placeId);
  
  if (placeDetails != null && placeDetails.latitude != null && placeDetails.longitude != null) {
    setState(() {
      _currentLocation = LatLng(placeDetails.latitude!, placeDetails.longitude!);
      _selectedLocationName = placeDetails.displayName;
      searchController.text = placeDetails.displayName;
      _showPredictions = false;
    });

    _googleMapController?.animateCamera(
      CameraUpdate.newLatLng(_currentLocation!),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not get location details.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}


  Future<void> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
    }

    final position = await Geolocator.getCurrentPosition();
    final newLatLng = LatLng(position.latitude, position.longitude );

    setState(() {
      _currentLocation = newLatLng;
    });

    _googleMapController?.animateCamera(CameraUpdate.newLatLng(newLatLng));
  }

  // for those to did these
Future<PredictionModel?> getPlaceDetails(String placeId) async {
    final apiKey = 'AIzaSyC5o3TwRWy4qzIFK5H3mhEYbKB0q_0-HbE';
    
   // AIzaSyCzFsq09BpliJlSB4b61qVJZtQfnaENyEs
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PredictionModel.fromDetails(data);
      }
    } catch (e) {
      print('Error getting place details: $e');
    }
    return null;
  }

// her will get all address full address funcation


  @override
  Widget build(BuildContext context) {
    final formattedTime = DateFormat.jm().format(dateTime);
    final formattedDate = DateFormat('yyyy/MM/dd').format(dateTime);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight,),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 10),
            const Text(
              'Create Lesson',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            MasonryGridView.builder(
              shrinkWrap: true,
              itemCount: speakleveltext.length,
              gridDelegate:
                  const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(left: 5, right: 5),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      backgroundColor: selectedIndex == index
                          ? ChooseColors.acceptColor
                          : Colors.transparent,
                      shadowColor: selectedIndex == index
                          ? ChooseColors.acceptColor
                          : Colors.transparent,
                      side: BorderSide(
                        color: selectedIndex == index
                            ? ChooseColors.acceptColor
                            : ChooseColors.acceptColor,
                        width: 1,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        selectedIndex = index;
                      });
                    },
                    child: Text(
                      speakleveltext[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: selectedIndex == index
                              ? Colors.white
                              : Color(0xff1B1212),),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  Text(
                 _selectedLocationName.isNotEmpty ? _selectedLocationName : 'No location selected',textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xff1B1212),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(padding: EdgeInsets.symmetric(
                  horizontal: 20,
                ),child: 
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff1B1212),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                isScrollControlled: true,
                backgroundColor: Colors.white,
                context: context,
                builder: (context) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Container(
                      height: 520,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        color: Colors.white,
                      ),
                      child: StatefulBuilder(
                        builder: (context, setModalState) {
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(10.0),
                                  child: TextFormField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Search for a location',
                                      prefixIcon: Icon(Icons.search),
                                      suffixIcon: isLoading
                                          ? Padding(
                                              padding: const EdgeInsets.all(12.0),
                                              child: SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(strokeWidth: 2, color:  Color(0xff1B1212),
                               backgroundColor: Colors.white,),
                                              ),
                                            )
                                          : null,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onChanged: (value) async {
                                      setModalState(() {
                                        isLoading = true;
                                      });
                                      await _searchLocation(value);
                                      setModalState(() {
                                        isLoading = false;
                                      });
                                    },
                                  ),
                                ),
                              if (_showPredictions && _filteredPredictions.isNotEmpty)
                                Container(
                                  margin: EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.3),
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _filteredPredictions.length,
                                    itemBuilder: (context, index) {
                                      // Safely check if the list is not empty
                                      if (_filteredPredictions.isEmpty) {
                                        return Container(); // Return an empty container or an appropriate widget
                                      }
                                      final prediction = _filteredPredictions[index];
                                      return ListTile(
                                        title: Text(prediction.displayName),
                                        onTap: () async {
                                                      try {
                                                        final fullDetails = await getPlaceDetails(prediction.placeId);

                                                        if (fullDetails != null && fullDetails.latitude != null && fullDetails.longitude != null) {
                                                          final selectedLatLng = LatLng(fullDetails.latitude!, fullDetails.longitude!);

                                                          setState(() {
                                                            // Update the current location
                                                            _currentLocation = selectedLatLng;

                                                            // Update the selected location name (full location text)
                                                            _selectedLocationName = fullDetails.displayName;

                                                            // Clear the search field
                                                            _searchController.clear();

                                                            // Hide the predictions list
                                                            _showPredictions = false;

                                                            // Update the marker
                                                            myMarker = [
                                                              Marker(
                                                                markerId: MarkerId('selected'),
                                                                position: selectedLatLng,
                                                              ),
                                                            ];
                                                          });

                                                          // Move map camera
                                                          _googleMapController?.animateCamera(
                                                            CameraUpdate.newLatLng(selectedLatLng),
                                                          );

                                                          // Dismiss keyboard
                                                          FocusScope.of(context).unfocus();
                                                        } else {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                              behavior: SnackBarBehavior.floating,
                                                              content: Text('Could not retrieve location details.'),
                                                              backgroundColor: Colors.red,
                                                              duration: Duration(seconds: 2),
                                                            ),
                                                          );
                                                        }
                                                      } catch (e) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            behavior: SnackBarBehavior.floating,
                                                            content: Text('Error: $e'),
                                                            backgroundColor: Colors.red,
                                                            duration: Duration(seconds: 2),
                                                          ),
                                                        );
                                                      }
                                                    },
                                      );
                                    },
                                  ),
                                ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    child: Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey, width: 3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: _currentLocation!,
                                  zoom: 19,
                                ),
                                onMapCreated: (GoogleMapController controller) {
                                  setState(() {
                                    _googleMapController = controller;
                                    myMarker = [
                                      Marker(
                                        markerId: MarkerId('selected'),
                                        position: _currentLocation!,
                                      ),
                                    ];
                                  });
                                },
                                markers: Set<Marker>.from(myMarker),
                                onTap: (LatLng position) {
                                  if (allowMapTap) {
                                    setState(() {
                                      _currentLocation = position;
                                      myMarker = [
                                        Marker(
                                          markerId: MarkerId('selected'),
                                          position: position,
                                        ),
                                      ];
                                    });
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        content: Text('Please select a location from the search first.'),
                                        backgroundColor: Colors.orange,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                myLocationEnabled: true,
                                zoomControlsEnabled: false,
                              ),
                   
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff1B1212),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          // Save selected location
                          print('Selected location: $_selectedLocationName at $_currentLocation');
                        });
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Save Location',
                        style: TextStyle(fontSize: 17, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  },
);
          }, child:  Text(
                    'Add Location',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
            ),),],
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(left: 20),
              child: Text(
                'Choose date and Time',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1B1212),
                ),
              ),
            ),
            const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
              //mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff1B1212),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: pickDateTime,
                      child: Text(
                        '$formattedDate $formattedTime', // Display formatted date and time
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.all(10.0),
              child: Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold,color: Color(0xff1B1212),),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20),
              child: TextFormField(
                onChanged: (value) {},
                controller: descriptionController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),),
                  hintText: 'Enter Description',
                  hintStyle: TextStyle(
                    color: Color(0xff1B1212),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  backgroundColor: Color(0xff1B1212),
                ),
                onPressed: _saveToFirestore,
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future pickDateTime() async {
    DateTime? date = await pickDate();
    if (date == null) return;
    TimeOfDay? time = await pickTime();
    if (time == null) return;
    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => this.dateTime = dateTime);
  }

  Future<DateTime?> pickDate() => showDatePicker(
  //  barrierColor:Colors.transparent,
  
        context: context,
        initialDate: dateTime,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
               primary: Color(0xff1B1212), 
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
              textTheme: Theme.of(context).textTheme.copyWith(
          headlineSmall: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xff1B1212),  // Header text color
        )),
            textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Color(0xff1B1212),  // Buttons text color
        ),),
              elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xff1B1212),  // Today button background
            foregroundColor: Colors.white,       // Today button text
          ),
        ),
              dialogTheme: DialogThemeData(backgroundColor: Colors.white),
            ),
            child: child!,
          );
        },
      );
 
  Future<TimeOfDay?> pickTime() => showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: dateTime.hour, minute: dateTime.minute),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: Theme.of(context).copyWith(
              
              colorScheme: ColorScheme.light(
                
                primary: ChooseColors.acceptColor,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );
}

class PredictionModel {
  final String displayName;
  final String placeId;
  final double? latitude;
  final double? longitude;

  PredictionModel({
    required this.displayName,
    required this.placeId,
    this.latitude,
    this.longitude,
  });

  // Factory method from Autocomplete API response
  factory PredictionModel.fromAutocomplete(Map<String, dynamic> json) {
    return PredictionModel(
      displayName: json['description'] ?? 'Unknown Location',
      placeId: json['place_id'] ?? '',
    );
  }

  // Factory method from Place Details API response
  factory PredictionModel.fromDetails(Map<String, dynamic> json) {
    final location = json['result']['geometry']['location'];
    return PredictionModel(
      displayName: json['result']['name'] ?? 'Unnamed',
      placeId: json['result']['place_id'] ?? '',
      latitude: location['lat']?.toDouble() ?? 0.0,
      longitude: location['lng']?.toDouble() ?? 0.0,
    );
  }
}