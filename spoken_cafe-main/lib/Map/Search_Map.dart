// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// // Replace with your actual Google API key
// const String googleApiKey = 'YOUR_GOOGLE_API_KEY_HERE';

// /// Utility to perform HTTP GET requests
// class NetworkUtil {
//   static Future<String?> fetchUrl(Uri uri) async {
//     try {
//       final response = await http.get(uri);
//       if (response.statusCode == 200) {
//         return response.body;
//       } else {
//         debugPrint('Failed with status code: ${response.statusCode}');
//       }
//     } catch (e) {
//       debugPrint('Error fetching URL: $e');
//     }
//     return null;
//   }
// }

// /// Model for an individual place prediction
// class PredictionModel {
//   final String? placeId;
//   final String? mainText;
//   final String? secondaryText;

//   PredictionModel({
//     this.placeId,
//     this.mainText,
//     this.secondaryText,
//   });

//   factory PredictionModel.fromJson(Map<String, dynamic> json) {
//     final formatting = json['structured_formatting'] ?? {};
//     return PredictionModel(
//       placeId: json['place_id'] as String?,
//       mainText: formatting['main_text'] as String?,
//       secondaryText: formatting['secondary_text'] as String?,
//     );
//   }
// }

// /// Fetch predictions from Google Places Autocomplete API
// Future<List<PredictionModel>> fetchPlacePredictions(String input) async {
//   if (input.length <= 1) return [];

//   final uri = Uri.https(
//     'maps.googleapis.com',
//     '/maps/api/place/autocomplete/json',
//     {
//       'input': input,
//       'key': googleApiKey,
//       'components': 'country:TR', // Optional: restrict to Turkey
//     },
//   );

//   final response = await NetworkUtil.fetchUrl(uri);
//   if (response == null) return [];

//   final jsonData = json.decode(response);
//   final predictions = jsonData['predictions'] as List<dynamic>;

//   return predictions
//       .map((json) => PredictionModel.fromJson(json as Map<String, dynamic>))
//       .toList();
// }
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Replace with your actual Google API key
const String googleApiKey = 'YOUR_GOOGLE_API_KEY_HERE';

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

/// Model for an individual place prediction
class PredictionModel {
  final String? placeId;
  final String? mainText;
  final String? secondaryText;

  PredictionModel({
    this.placeId,
    this.mainText,
    this.secondaryText,
  });

  factory PredictionModel.fromJson(Map<String, dynamic> json) {
    final formatting = json['structured_formatting'] ?? {};
    return PredictionModel(
      placeId: json['place_id'] as String?,
      mainText: formatting['main_text'] as String?,
      secondaryText: formatting['secondary_text'] as String?,
    );
  }
}

/// Fetch predictions from Google Places Autocomplete API
Future<List<PredictionModel>> fetchPlacePredictions(String input) async {
  if (input.length <= 1) return [];

  final uri = Uri.https(
    'maps.googleapis.com',
    '/maps/api/place/autocomplete/json',
    {
      'input': input,
      'key': googleApiKey,
      'components': 'country:TR', // Optional: restrict to Turkey
    },
  );

  final response = await NetworkUtil.fetchUrl(uri);
  if (response == null) return [];

  final jsonData = json.decode(response);
  final predictions = jsonData['predictions'] as List<dynamic>;

  return predictions
      .map((json) => PredictionModel.fromJson(json as Map<String, dynamic>))
      .toList();
}
