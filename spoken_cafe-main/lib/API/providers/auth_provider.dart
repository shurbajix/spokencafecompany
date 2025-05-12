// import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:spokencafe/API/server/auth_server.dart';

// final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
//   return AuthNotifier();
// });

// class AuthNotifier extends StateNotifier<AuthState> {
//   AuthNotifier() : super(AuthState.initial());

//   Future<void> register(RegisterRequest request) async {
//     state = state.copyWith(isLoading: true);
//     final response = await AuthService.register(request);
//     state = state.copyWith(
//       isLoading: false,
//       token: response.token,
//       error: response.error,
//     );
//   }

//   Future<void> login(LoginRequest request) async {
//     state = state.copyWith(isLoading: true);
//     final response = await AuthService.login(request);
//     state = state.copyWith(
//       isLoading: false,
//       token: response.token,
//       error: response.error,
//     );
//   }

//   void logout() {
//     state = AuthState.initial();
//   }
// }

// class AuthState {
//   final bool isLoading;
//   final String? token;
//   final String? error;

//   AuthState({required this.isLoading, this.token, this.error});

//   factory AuthState.initial() => AuthState(isLoading: false);

//   AuthState copyWith({
//     bool? isLoading,
//     String? token,
//     String? error,
//   }) {
//     return AuthState(
//       isLoading: isLoading ?? this.isLoading,
//       token: token ?? this.token,
//       error: error ?? this.error,
//     );
//   }
// }
