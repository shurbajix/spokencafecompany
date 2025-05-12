

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spokencafe/Screen/error/go_error_router.dart';
import 'package:spokencafe/Selecttype/Selecttype.dart';
import 'package:spokencafe/model/Account/Log/Login.dart';
import 'package:spokencafe/model/NavBar/NavBar.dart';
import 'package:spokencafe/router/name_router.dart';

final authProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final getRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/loading', // Temporary screen while checking auth state
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) =>
            const LoadingScreen(), // Placeholder screen
      ),
      GoRoute(
        path: '/selectType',
        name: root,
        builder: (context, state) => Selecttype(
          key: state.pageKey,
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Login(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Navbar(),
      ),
    ],
    redirect: (context, state) async {
      final user = authState.value;
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role');

      if (user == null || role == null) {
        return '/selectType'; // Redirect to login if not logged in
      }

      return '/home'; // Redirect to home if logged in
    },
    errorBuilder: (context, state) => Center(
      child: RouteErrorScreen(
        ErrorScreen: state.error.toString(),
        key: state.pageKey,
      ),
    ),
  );
});

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
           color:  Color(0xff1B1212),
             backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
