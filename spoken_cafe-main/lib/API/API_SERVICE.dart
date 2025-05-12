import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // For token storage

import '../Data/Classes.dart'; // Import Teacher and Student classes

class ApiService {
  final String baseUrl;

  ApiService({
    required this.baseUrl,
  });

  // Register Teacher
  Future<http.Response> registerTeacher(Teacher teacher) async {
    final jsonBody = jsonEncode(teacher.toJson());
    print('Request Payload: $jsonBody'); // Log the payload

    final response = await http.post(
      Uri.parse('$baseUrl/teachers'),
      headers: {
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
      body: jsonBody,
    );

    print('Response status code: ${response.statusCode}');
    print('Response body: ${response.body}');

    return response; // Return the http.Response object
  }

  // Register Student
  Future<http.Response> registerStudent(Student student) async {
    final jsonBody = jsonEncode(student.toJson());
    print('Request Payload: $jsonBody'); // Log the payload

    final response = await http.post(
      Uri.parse('$baseUrl/students/register'), // Student registration endpoint
      headers: {
        'Content-Type': 'application/json',
        'accept': '*/*', // Match the curl headers
      },
      body: jsonBody,
    );

    print('Response status code: ${response.statusCode}');
    print('Response body: ${response.body}');

    return response;
  }

  // Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(response.body);
      final String token = data['token'];

      // Save token to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      return data;
    } else {
      throw Exception('Failed to login');
    }
  }

  // Google Sign-In for Students
  Future<Map<String, dynamic>> googleSignIn() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: [
        'email',
        'profile',
      ],
    );

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser != null) {
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final response = await http.post(
        Uri.parse('$baseUrl/students/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'idToken': googleAuth.idToken,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String token = data['token'];

        // Save token to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);

        return data;
      } else {
        throw Exception('Failed to login with Google');
      }
    } else {
      throw Exception('Google Sign-In was canceled');
    }
  }
}

// Notifier for Teacher Registration
class TeacherRegistrationNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiService apiService;

  TeacherRegistrationNotifier(this.apiService)
      : super(const AsyncValue.loading());

  Future<AsyncValue<void>> registerTeacher(Teacher teacher) async {
    state = const AsyncValue.loading();
    try {
      final response = await apiService.registerTeacher(teacher);

      // Check the response status code
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success
        final responseBody = jsonDecode(response.body);
        final token = responseBody['token']; // Extract token from response

        // Save token to local storage
        await SharedPreferences.getInstance().then((prefs) {
          prefs.setString('token', token);
        });

        state = const AsyncValue.data(null);
        return const AsyncValue.data(null);
      } else {
        // Handle other errors
        final responseBody = jsonDecode(response.body);
        final errorMessage = responseBody['message'] ??
            'Failed to register teacher: ${response.statusCode}';
        state = AsyncValue.error(errorMessage, StackTrace.current);
        return AsyncValue.error(errorMessage, StackTrace.current);
      }
    } catch (e, stackTrace) {
      // Handle unexpected errors
      state = AsyncValue.error(e, stackTrace);
      return AsyncValue.error(e, stackTrace);
    }
  }
}

// Notifier for Student Registration
class StudentRegistrationNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiService apiService;

  StudentRegistrationNotifier(this.apiService)
      : super(const AsyncValue.loading());

  Future<AsyncValue<void>> registerStudent(Student student) async {
    state = const AsyncValue.loading();
    try {
      final response = await apiService.registerStudent(student);

      // Check the response status code
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success
        final responseBody = jsonDecode(response.body);
        final token = responseBody['token']; // Extract token from response

        // Save token to local storage
        await SharedPreferences.getInstance().then((prefs) {
          prefs.setString('token', token);
        });

        state = const AsyncValue.data(null);
        return const AsyncValue.data(null);
      } else {
        // Handle other errors
        final responseBody = jsonDecode(response.body);
        final errorMessage = responseBody['message'] ??
            'Failed to register student: ${response.statusCode}';
        state = AsyncValue.error(errorMessage, StackTrace.current);
        return AsyncValue.error(errorMessage, StackTrace.current);
      }
    } catch (e, stackTrace) {
      // Handle unexpected errors
      state = AsyncValue.error(e, stackTrace);
      return AsyncValue.error(e, stackTrace);
    }
  }
}

// Notifier for Login
class LoginNotifier extends StateNotifier<AsyncValue<void>> {
  final ApiService apiService;

  LoginNotifier(this.apiService) : super(const AsyncValue.loading());

  Future<AsyncValue<void>> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final response = await apiService.login(email, password);

      // Success
      state = const AsyncValue.data(null);
      return const AsyncValue.data(null);
    } catch (e, stackTrace) {
      // Handle errors
      state = AsyncValue.error(e, stackTrace);
      return AsyncValue.error(e, stackTrace);
    }
  }

  // Google Sign-In for Students
  Future<AsyncValue<void>> googleSignIn() async {
    state = const AsyncValue.loading();
    try {
      final response = await apiService.googleSignIn();

      // Success
      state = const AsyncValue.data(null);
      return const AsyncValue.data(null);
    } catch (e, stackTrace) {
      // Handle errors
      state = AsyncValue.error(e, stackTrace);
      return AsyncValue.error(e, stackTrace);
    }
  }
}

// Providers
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(
    baseUrl:
        'http://ec2-13-48-138-221.eu-north-1.compute.amazonaws.com:8080/spoken-cafe/api',
  );
});

final teacherRegistrationProvider =
    StateNotifierProvider<TeacherRegistrationNotifier, AsyncValue<void>>((ref) {
  return TeacherRegistrationNotifier(
    ref.watch(apiServiceProvider),
  );
});

final studentRegistrationProvider =
    StateNotifierProvider<StudentRegistrationNotifier, AsyncValue<void>>((ref) {
  return StudentRegistrationNotifier(
    ref.watch(apiServiceProvider),
  );
});

final loginProvider =
    StateNotifierProvider<LoginNotifier, AsyncValue<void>>((ref) {
  return LoginNotifier(
    ref.watch(apiServiceProvider),
  );
});
// class ApiService {
//   final String baseUrl;
//
//   ApiService({
//     required this.baseUrl,
//   });
//
//
//
//   Future<String> registerTeacher(Teacher teacher) async {
//     final jsonBody = jsonEncode(teacher.toJson());
//     print('Request Payload: $jsonBody'); // Log the payload
//
//     final response = await http.post(
//       Uri.parse('http://ec2-13-48-138-221.eu-north-1.compute.amazonaws.com:8080/spoken-cafe/api/teachers'),
//       headers: {
//         'Content-Type': 'application/json',
//         'accept': '*/*',
//       },
//       body: jsonBody,
//     );
//
//     print('Response status code: ${response.statusCode}');
//     print('Response body: ${response.body}');
//
//     if (response.statusCode == 200) {
//       // Success: Return a success message
//       return 'Teacher registered successfully!';
//     } else if (response.statusCode == 409) {
//       // Conflict: Parse the error message from the response body
//       final responseBody = jsonDecode(response.body);
//       final errorMessage = responseBody['message'] ?? 'Conflict: A teacher with this phone number already exists.';
//       throw Exception(errorMessage);
//     } else {
//       // Other errors
//       throw Exception('Failed to register teacher: ${response.body}');
//     }
//   }
//   // Register Student
//   Future<http.Response> registerStudent(Student student) async {
//     final jsonBody = jsonEncode(student.toJson());
//     print('Request Payload: $jsonBody'); // Log the payload
//
//     final response = await http.post(
//       Uri.parse('$baseUrl/students/register'), // Student registration endpoint
//       headers: {
//         'Content-Type': 'application/json',
//         'accept': '*/*', // Match the curl headers
//       },
//       body: jsonBody,
//     );
//
//     print('Response status code: ${response.statusCode}');
//     print('Response body: ${response.body}');
//
//     return response;
//   }
//
//   // Login
//   Future<Map<String, dynamic>> login(String email, String password) async {
//     final response = await http.post(
//       Uri.parse('$baseUrl/login'),
//       headers: {'Content-Type': 'application/json'},
//       body: json.encode({'email': email, 'password': password}),
//     );
//
//     if (response.statusCode == 200) {
//       final Map<String, dynamic> data = json.decode(response.body);
//       final String token = data['token'];
//
//       // Save token to SharedPreferences
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('token', token);
//
//       return data;
//     } else {
//       throw Exception('Failed to login');
//     }
//   }
//
//   // Google Sign-In for Students
//   Future<Map<String, dynamic>> googleSignIn() async {
//     final GoogleSignIn googleSignIn = GoogleSignIn(
//       scopes: [
//         'email',
//         'profile',
//       ],
//     );
//
//     final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
//
//     if (googleUser != null) {
//       final GoogleSignInAuthentication googleAuth =
//           await googleUser.authentication;
//
//       final response = await http.post(
//         Uri.parse('$baseUrl/students/google-login'),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           'idToken': googleAuth.idToken,
//         }),
//       );
//
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//         final String token = data['token'];
//
//         // Save token to SharedPreferences
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setString('token', token);
//
//         return data;
//       } else {
//         throw Exception('Failed to login with Google');
//       }
//     } else {
//       throw Exception('Google Sign-In was canceled');
//     }
//   }
// }
//
// // Notifier for Teacher Registration
// class TeacherRegistrationNotifier extends StateNotifier<AsyncValue<void>> {
//   final ApiService apiService;
//
//   TeacherRegistrationNotifier(this.apiService)
//       : super(const AsyncValue.loading());
//
//   Future<AsyncValue<void>> registerTeacher(Teacher teacher) async {
//     state = const AsyncValue.loading();
//     try {
//       final response = await apiService.registerTeacher(teacher);
//
//       // Check the response status code
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         // Success
//         final responseBody = jsonDecode(response.body);
//         final token = responseBody['token']; // Extract token from response
//
//         // Save token to local storage
//         await SharedPreferences.getInstance().then((prefs) {
//           prefs.setString('token', token);
//         });
//
//         state = const AsyncValue.data(null);
//         return const AsyncValue.data(null);
//       } else {
//         // Handle other errors
//         final responseBody = jsonDecode(response.body);
//         final errorMessage = responseBody['message'] ??
//             'Failed to register teacher: ${response.statusCode}';
//         state = AsyncValue.error(errorMessage, StackTrace.current);
//         return AsyncValue.error(errorMessage, StackTrace.current);
//       }
//     } catch (e, stackTrace) {
//       // Handle unexpected errors
//       state = AsyncValue.error(e, stackTrace);
//       return AsyncValue.error(e, stackTrace);
//     }
//   }
// }
//
// // Notifier for Student Registration
// class StudentRegistrationNotifier extends StateNotifier<AsyncValue<void>> {
//   final ApiService apiService;
//
//   StudentRegistrationNotifier(this.apiService)
//       : super(const AsyncValue.loading());
//
//   Future<AsyncValue<void>> registerStudent(Student student) async {
//     state = const AsyncValue.loading();
//     try {
//       final response = await apiService.registerStudent(student);
//
//       // Check the response status code
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         // Success
//         final responseBody = jsonDecode(response.body);
//         final token = responseBody['token']; // Extract token from response
//
//         // Save token to local storage
//         await SharedPreferences.getInstance().then((prefs) {
//           prefs.setString('token', token);
//         });
//
//         state = const AsyncValue.data(null);
//         return const AsyncValue.data(null);
//       } else {
//         // Handle other errors
//         final responseBody = jsonDecode(response.body);
//         final errorMessage = responseBody['message'] ??
//             'Failed to register student: ${response.statusCode}';
//         state = AsyncValue.error(errorMessage, StackTrace.current);
//         return AsyncValue.error(errorMessage, StackTrace.current);
//       }
//     } catch (e, stackTrace) {
//       // Handle unexpected errors
//       state = AsyncValue.error(e, stackTrace);
//       return AsyncValue.error(e, stackTrace);
//     }
//   }
// }
//
// // Notifier for Login
// class LoginNotifier extends StateNotifier<AsyncValue<void>> {
//   final ApiService apiService;
//
//   LoginNotifier(this.apiService) : super(const AsyncValue.loading());
//
//   Future<AsyncValue<void>> login(String email, String password) async {
//     state = const AsyncValue.loading();
//     try {
//       final response = await apiService.login(email, password);
//
//       // Success
//       state = const AsyncValue.data(null);
//       return const AsyncValue.data(null);
//     } catch (e, stackTrace) {
//       // Handle errors
//       state = AsyncValue.error(e, stackTrace);
//       return AsyncValue.error(e, stackTrace);
//     }
//   }
//
//   // Google Sign-In for Students
//   Future<AsyncValue<void>> googleSignIn() async {
//     state = const AsyncValue.loading();
//     try {
//       final response = await apiService.googleSignIn();
//
//       // Success
//       state = const AsyncValue.data(null);
//       return const AsyncValue.data(null);
//     } catch (e, stackTrace) {
//       // Handle errors
//       state = AsyncValue.error(e, stackTrace);
//       return AsyncValue.error(e, stackTrace);
//     }
//   }
//
// }
//
// // Providers
// final apiServiceProvider = Provider<ApiService>((ref) {
//   return ApiService(
//     baseUrl:
//         'http://ec2-13-48-138-221.eu-north-1.compute.amazonaws.com:8080/spoken-cafe/api',
//   );
// });
//
// final teacherRegistrationProvider =
//     StateNotifierProvider<TeacherRegistrationNotifier, AsyncValue<void>>((ref) {
//   return TeacherRegistrationNotifier(
//     ref.watch(apiServiceProvider),
//   );
// });
//
// final studentRegistrationProvider =
//     StateNotifierProvider<StudentRegistrationNotifier, AsyncValue<void>>((ref) {
//   return StudentRegistrationNotifier(
//     ref.watch(apiServiceProvider),
//   );
// });
//
// final loginProvider =
//     StateNotifierProvider<LoginNotifier, AsyncValue<void>>((ref) {
//   return LoginNotifier(
//     ref.watch(apiServiceProvider),
//   );
// });

// this will add lessons


// for test this email
//worldworld30@gmail.com
// for test this password
// world22