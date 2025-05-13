
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:spoken_cafe_controller/firebase_options.dart';
import 'package:window_manager/window_manager.dart';

// Assuming Login widget exists in your project
import 'package:spoken_cafe_controller/model/Screen/Log/Login.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // Check if the platform is desktop
  bool get isDesktop => Platform.isMacOS || Platform.isWindows;

  // Track selected index for BottomNavigationBar (mobile only)
  int _selectedIndex = 0;

  // Handle BottomNavigationBar tap
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Add navigation logic here (e.g., switch pages based on index)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Spoken Cafe Control'),
              centerTitle: true,
            ),
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              items: listhomedahsboard
                  .map((item) => BottomNavigationBarItem(
                        icon: Icon(_getIconForItem(item)),
                        label: item,
                      ))
                  .toList(),
              currentIndex: _selectedIndex,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
              onTap: _onItemTapped,
            ),
      body: isDesktop ? _buildDesktopBody() : _buildMobileBody(),
    );
  }

  // Map navigation items to icons for BottomNavigationBar
  IconData _getIconForItem(String item) {
    switch (item) {
      case 'Home':
        return Icons.home;
      case 'Students':
        return Icons.people;
      case 'Teachers':
        return Icons.school;
      case 'Chat':
        return Icons.chat;
      case 'Settings':
        return Icons.settings;
      default:
        return Icons.circle;
    }
  }

  // Desktop UI for macOS and Windows (no sidebar)
  Widget _buildDesktopBody() {
    return _buildMainContent();
  }

  // Mobile UI for Android and iOS (no sidebar)
  Widget _buildMobileBody() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildMainContent(isMobile: true),
      ),
    );
  }

  // Shared main content for both platforms
  Widget _buildMainContent({bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Features Section
        Row(
          children: List.generate(addnewFutures.length, (index) {
            return Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      addnewFutures[index],
                      style: TextStyle(fontSize: isMobile ? 20 : 25),
                    ),
                    Container(
                      margin: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(
                          earnandtakeandpay.length,
                          (index) {
                            return ListTile(
                              leading: Image.asset(
                                'assets/images/spken_cafe.png',
                                width: isMobile ? 30 : 40,
                                height: isMobile ? 30 : 40,
                              ),
                              title: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Andrewahmad2@gmail.com'),
                                  Text('Andrew Teacher'),
                                ],
                              ),
                              trailing: Text(
                                earnandtakeandpay[index],
                                style: TextStyle(fontSize: isMobile ? 16 : 20),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        // Earnings Section
        Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Our Earns',
                style: TextStyle(fontSize: isMobile ? 24 : 30),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Colors.grey),
                      child: Column(
                        children: [
                          Text(
                            'Chart',
                            style: TextStyle(fontSize: isMobile ? 16 : 20),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Shared data
List<String> addnewFutures = ['Teacher', 'Lessons', 'Student'];
List<String> earnandtakeandpay = [
  'Earns: \$4.0',
  'Lesson Take: 100',
  'Lesson Pay: 30',
];
List<String> listhomedahsboard = [
  'Home',
  'Students',
  'Teachers',
  'Chat',
  'Settings',
];