import 'package:flutter/material.dart';
import 'package:spoken_cafe_controller/model/Screen/Chat/Chat.dart';
import 'package:spoken_cafe_controller/model/Screen/Gallery/Gallery.dart';
import 'package:spoken_cafe_controller/model/Screen/Home/HomeContect.dart';
import 'package:spoken_cafe_controller/model/Screen/StudentInfo/StudentInfo.dart';
import 'package:spoken_cafe_controller/model/Screen/Students/Students.dart';
import 'package:spoken_cafe_controller/model/Screen/Teachers/Teachers.dart';
import 'package:spoken_cafe_controller/model/Screen/TeacherandStudent/TeacherandStudent.dart';


class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String selectedMenu = 'StudentInfo'; // Changed default to StudentInfo

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Padding(
          padding: const EdgeInsets.only(top: 30, left: 20),
          child: AppBar(
            backgroundColor: Colors.transparent,
            leading: Image.asset('assets/images/spken_cafe.png'),
            title: const Text(
              'Spoken Cafe Control',
              style: TextStyle(fontSize: 30),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: Row(
        children: [
          /// Left Side - Navigation Menu
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: List.generate(listhomedashboard.length, (index) {
                  return Container(
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selectedMenu == listhomedashboard[index]
                          ? Colors.grey
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: Icon(
                        _getIconForItem(listhomedashboard[index]),
                        color: selectedMenu == listhomedashboard[index]
                            ? Colors.white
                            : Colors.black,
                      ),
                      title: Text(
                        listhomedashboard[index],
                        style: TextStyle(
                          fontSize: 10,
                          color: selectedMenu == listhomedashboard[index]
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      selected: selectedMenu == listhomedashboard[index],
                      selectedTileColor: Colors.orangeAccent,
                      onTap: () {
                        print('👆 SideBar: Tapped on ${listhomedashboard[index]}');
                        setState(() {
                          selectedMenu = listhomedashboard[index];
                          print('✅ SideBar: selectedMenu updated to $selectedMenu');
                        });
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
          /// Right Side - Dynamic Content
          Expanded(flex: 6, child: getSelectedPage(selectedMenu)),
        ],
      ),
    );
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
      case 'TeacherandStudent':
        return Icons.group;
      case 'Chat':
        return Icons.chat;
      case 'StudentInfo':
        return Icons.account_circle;
      case 'Gallery':
        return Icons.browse_gallery;
      default:
        return Icons.circle;
    }
  }

  
  Widget getSelectedPage(String menu) {
    print('🔄 SideBar: getSelectedPage called with menu: $menu');
    switch (menu) {
      case 'Home':
        print('📍 SideBar: Returning Home page');
        return const HomeContent(isMobile: false);
      case 'Student':
        print('📍 SideBar: Returning Students page');
        return const Students();
      case 'Teacher':
        print('📍 SideBar: Returning Teachers page');
        return const Teachers();
      case 'TeacherandStudent':
        print('📍 SideBar: Returning TeacherandStudent page');
        return const TeacherandStudent();
      case 'Chat':
        print('📍 SideBar: Returning Chat page');
        return const Chat();
      case 'StudentInfo':
        print('📍 SideBar: Returning StudentInfo page');
        return const StudentInfo();
      case 'Gallery':
        print('📍 SideBar: Returning Gallery page');
        return const Gallery();
      default:
        print('📍 SideBar: Returning default Home page for menu: $menu');
        return const HomeContent(isMobile: false);
    }
  }
}

// Define listhomedashboard globally
List<String> listhomedashboard = [
  'Home',
  'Student',
  'Teacher',
  'TeacherandStudent',
  'Chat',
  'StudentInfo',
  'Gallery',
];