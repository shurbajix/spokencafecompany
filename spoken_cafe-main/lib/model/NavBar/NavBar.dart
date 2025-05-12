import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spokencafe/Section/Student/Section_Student.dart';
import 'package:spokencafe/model/student/profile_student/profile_student.dart';
import 'package:spokencafe/search/Student/Search_student.dart';

import '../../Screen/Home/Home.dart';
import '../../Section/Teacher/Section.dart';
import '../../Topics/Topic.dart';
import '../../profile/Profile.dart';
import '../../search/Teacher/Search.dart';

var selectIndexProvider = StateProvider<int>((ref) => 0);
var showTextFieldProvider = StateProvider<bool>((ref) => false);
var userRoleProvider =
    StateProvider<String?>((ref) => null); // To store user role

class Navbar extends ConsumerStatefulWidget {
  const Navbar({super.key});

  @override
  _NavbarState createState() => _NavbarState();
}

class _NavbarState extends ConsumerState<Navbar> {
  Map<String, dynamic> userData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // First try to get from Firestore
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          userData = doc.data()!;
          final role = doc.data()?['role'] ?? 'student';
          
          // Save to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('role', role);
          
          // Update the provider
          ref.read(userRoleProvider.notifier).state = role;
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      // Fallback to SharedPreferences if Firestore fails
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role') ?? 'student';
      ref.read(userRoleProvider.notifier).state = role;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(
           color:  Color(0xff1B1212),
           backgroundColor: Colors.white,
        ),),
      );
    }

    final selectedIndex = ref.watch(selectIndexProvider);
    final showTextField = ref.watch(showTextFieldProvider);
    final userRole = ref.watch(userRoleProvider);

    // Define pages based on role
    final List<Widget> pages = userRole == 'teacher'
        ? [
            Home(),
            Topics(),
            Search(),
            Section(),
            Profile(
              user: userData,
              isTeacher: true,
            ),
          ]
        : [
            Home(),
            Topics(),
            SearchStudent(),
            SectionStudent(),
            ProfileStudent(userData),
          ];

    // Define navigation items based on role
    final List<BottomNavigationBarItem> items = userRole == 'teacher'
        ? [
            const BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
            const BottomNavigationBarItem(icon: Icon(Icons.topic), label: ''),
            const BottomNavigationBarItem(icon: Icon(Icons.add), label: ''),
            BottomNavigationBarItem(
              icon: Image.asset('assets/images/mysection.png',
                  width: 30,
                  color: selectedIndex == 3 ? Colors.white : Colors.white60),
              label: '',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
          ]
        : [
            const BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
            const BottomNavigationBarItem(icon: Icon(Icons.topic), label: ''),
            const BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
            BottomNavigationBarItem(
              icon: Image.asset('assets/images/mysection.png',
                  width: 30,
                  color: selectedIndex == 3 ? Colors.white : Colors.white60),
              label: '',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
          ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xff1B1212),
          iconSize: 25,
          currentIndex: selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: items,
          onTap: (value) {
            if (value == 2 && userRole == 'teacher') {
              ref.read(showTextFieldProvider.notifier).state = true;
              ref.read(selectIndexProvider.notifier).state = value;
            } else {
              if (value >= 0 && value < pages.length) {
                ref.read(selectIndexProvider.notifier).state = value;
              }
              ref.read(showTextFieldProvider.notifier).state = false;
            }
          },
        ),
      ),
    );
  }
}



