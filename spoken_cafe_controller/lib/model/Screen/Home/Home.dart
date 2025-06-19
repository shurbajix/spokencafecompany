import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:spoken_cafe_controller/SidBar/SideBar.dart'; // Import HomeContent and listhomedashboard
import 'package:spoken_cafe_controller/model/Screen/Chat/Chat.dart';
import 'package:spoken_cafe_controller/model/Screen/Home/HomeContect.dart';
import 'package:spoken_cafe_controller/model/Screen/Settings/Settings.dart';
import 'package:spoken_cafe_controller/model/Screen/Students/Students.dart';
import 'package:spoken_cafe_controller/model/Screen/Teachers/Teachers.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // Check if the platform is desktop
  bool get isDesktop => Platform.isMacOS || Platform.isWindows;

  // Track selected menu item
  String _selectedMenu = 'Home';

  // Handle menu selection
  void _onMenuSelected(String menu) {
    setState(() {
      _selectedMenu = menu;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      // Desktop: Use Sidebar
      return const Sidebar();
    } else {
      // Mobile: Use BottomNavigationBar
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          shadowColor: Colors.white,
          leading:  Padding(padding: EdgeInsets.all(10),child:  Image.asset('assets/images/spken_cafe_control.png',scale: 4.9,),),
          title: const Text('Spoken Cafe Control'),
          centerTitle: true,
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
          
          items: listhomedashboard
              .map((item) => BottomNavigationBarItem(
                    icon: Icon(_getIconForItem(item)),
                    label: item,
                  ))
              .toList(),
          currentIndex: listhomedashboard.indexOf(_selectedMenu),
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          onTap: (index) => _onMenuSelected(listhomedashboard[index]),
        ),
        body: getSelectedPage(_selectedMenu),
      );
    }
  }

  // Map navigation items to icons
  IconData _getIconForItem(String item) {
    switch (item) {
      case 'Home':
        return Icons.home;
      case 'Student':
        return Icons.people;
      case 'Teacher':
        return Icons.school;
      case 'Chat':
        return Icons.chat;
      case 'Setting':
        return Icons.settings;
      default:
        return Icons.circle;
    }
  }

  // Function to return different pages based on selected menu
  Widget getSelectedPage(String menu) {
    switch (menu) {
      case 'Home':
        return const HomeContent(isMobile: true);
      case 'Student':
        return const Students();
      case 'Teacher':
        return const Teachers();
      case 'Chat':
        return const Chat();
      case 'Setting':
        return const Settings();
      default:
        return const HomeContent(isMobile: true);
    }
  }
}