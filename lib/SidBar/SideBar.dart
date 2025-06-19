
import 'package:flutter/material.dart';
import 'package:spoken_cafe_controller/model/Screen/Chat/Chat.dart';
import 'package:spoken_cafe_controller/model/Screen/Home/Home.dart';
import 'package:spoken_cafe_controller/model/Screen/Home/HomeContect.dart';
import 'package:spoken_cafe_controller/model/Screen/Settings/Settings.dart';
import 'package:spoken_cafe_controller/model/Screen/Students/Students.dart';
import 'package:spoken_cafe_controller/model/Screen/Teachers/Teachers.dart';


class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String selectedMenu = 'Home'; // Default selected menu item

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
                        setState(() {
                          selectedMenu = listhomedashboard[index];
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
        return const HomeContent(isMobile: false);
      case 'Student':
        return const Students();
      case 'Teacher':
        return const Teachers();
      case 'Chat':
        return const Chat();
      case 'Setting':
        return const Settings();
      default:
        return const HomeContent(isMobile: false);
    }
  }
}
// class Sidebar extends StatefulWidget {
//   const Sidebar({super.key});

//   @override
//   State<Sidebar> createState() => _SidebarState();
// }

// class _SidebarState extends State<Sidebar> {
//   String selectedMenu = 'Home'; // Default selected menu item

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: PreferredSize(
//         preferredSize: const Size.fromHeight(100),
//         child: Padding(
//           padding: const EdgeInsets.only(top: 30, left: 20),
//           child: AppBar(
//             backgroundColor: Colors.transparent,
//             leading: Image.asset('assets/images/spken_cafe.png'),
//             title: const Text(
//               'Spoken Cafe Control',
//               style: TextStyle(fontSize: 30),
//             ),
//             centerTitle: true,
//           ),
//         ),
//       ),
//       body: Row(
//         children: [
//           /// Left Side - Navigation Menu
//           Expanded(
//             flex: 1,
//             child: Container(
//               padding: const EdgeInsets.all(10),
//               margin: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: Colors.grey[200],
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Column(
//                 children: List.generate(listhomedashboard.length, (index) {
//                   return Container(
//                     margin: const EdgeInsets.all(10),
//                     decoration: BoxDecoration(
//                       color: selectedMenu == listhomedashboard[index]
//                           ? Colors.grey
//                           : Colors.transparent,
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: ListTile(
//                       leading: Icon(
//                         _getIconForItem(listhomedashboard[index]),
//                         color: selectedMenu == listhomedashboard[index]
//                             ? Colors.white
//                             : Colors.black,
//                       ),
//                       title: Text(
//                         listhomedashboard[index],
//                         style: TextStyle(
//                           fontSize: 10,
//                           color: selectedMenu == listhomedashboard[index]
//                               ? Colors.white
//                               : Colors.black,
//                         ),
//                       ),
//                       selected: selectedMenu == listhomedashboard[index],
//                       selectedTileColor: Colors.orangeAccent,
//                       onTap: () {
//                         setState(() {
//                           selectedMenu = listhomedashboard[index];
//                         });
//                       },
//                     ),
//                   );
//                 }),
//               ),
//             ),
//           ),
//           /// Right Side - Dynamic Content
//           Expanded(flex: 6, child: getSelectedPage(selectedMenu)),
//         ],
//       ),
//     );
//   }

//   // Map navigation items to icons
//   IconData _getIconForItem(String item) {
//     switch (item) {
//       case 'Home':
//         return Icons.home;
//       case 'Student':
//         return Icons.people;
//       case 'Teacher':
//         return Icons.school;
//       case 'Chat':
//         return Icons.chat;
//       case 'Setting':
//         return Icons.settings;
//       default:
//         return Icons.circle;
//     }
//   }

//   // Function to return different pages based on selected menu
//   Widget getSelectedPage(String menu) {
//     switch (menu) {
//       case 'Home':
//         return const HomeContent(isMobile: false);
//       case 'Student':
//         return const Students();
//       case 'Teacher':
//         return const Teachers();
//       case 'Chat':
//         return const Chat();
//       case 'Setting':
//         return const Settings();
//       default:
//         return const HomeContent(isMobile: false);
//     }
//   }
// }
// // Define listhomedashboard globally
List<String> listhomedashboard = [
  'Home',
  'Student',
  'Teacher',
  'Chat',
  'Setting',
];