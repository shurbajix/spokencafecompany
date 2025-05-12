// import 'dart:convert';

// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:http/http.dart' as http;

// import '../../model/auth_response.dart';

// class AuthService {
//   static final String _baseUrl = dotenv.get('http://localhost:3000/api/v1/register');

//   // Register
//   static Future<AuthResponse> register(RegisterRequest request) async {
//     final response = await http.post(
//       Uri.parse('$_baseUrl/auth/register'),
//       headers: {'Content-Type': 'application/json'},
//       body: json.encode(request.toJson()),
//     );

//     if (response.statusCode == 201) {
//       return AuthResponse.fromJson(json.decode(response.body));
//     } else {
//       return AuthResponse(error: json.decode(response.body)['message']);
//     }
//   }

//   // Login
//   static Future<AuthResponse> login(LoginRequest request) async {
//     final response = await http.post(
//       Uri.parse('$_baseUrl/auth/login'),
//       headers: {'Content-Type': 'application/json'},
//       body: json.encode(request.toJson()),
//     );

//     if (response.statusCode == 200) {
//       return AuthResponse.fromJson(json.decode(response.body));
//     } else {
//       return AuthResponse(error: json.decode(response.body)['message']);
//     }
//   }
// }
