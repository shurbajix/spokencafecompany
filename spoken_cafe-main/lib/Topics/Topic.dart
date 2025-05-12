import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:spokencafe/Topics/Days/Friday/Friday.dart';
import 'package:spokencafe/Topics/Days/Monday/Monday.dart';
import 'package:spokencafe/Topics/Days/Thursday/Thursday.dart';
import 'package:spokencafe/Topics/Days/Tuesday/Tuesday.dart';
import 'package:spokencafe/Topics/Days/Wednesday/Wednesday.dart';

import 'Days/Weekend/Weekend.dart';

class Topics extends ConsumerStatefulWidget {
  const Topics({
    super.key,
  });

  @override
  ConsumerState<Topics> createState() => _TopicsState();
}

class _TopicsState extends ConsumerState<Topics> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text(
          'Topics',
          style: TextStyle(
            color: Color(0xff1B1212),
            fontWeight: FontWeight.bold,
            fontSize: 30,
          ),
        ),
        //backgroundColor: const Color(0xff251e3e),
        automaticallyImplyLeading: false,
      ),
      //backgroundColor: const Color(0xff251e3e),
      body: MasonryGridView.builder(
        itemCount: topices.length,
        gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(10.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        _pages[index],
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0); // Start from right
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;

                      var tween = Tween(begin: begin, end: end)
                          .chain(CurveTween(curve: curve));

                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                  ),
                );
              },
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xff1B1212),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xff2e2d88),
                      offset: Offset(0.0, 1.0), //(x,y)
                      blurRadius: 10.0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      topices[index],
                      style: const TextStyle(
                        fontSize: 30,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

List<String> topices = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Weekend',
];

List<Widget> _pages = const [
  Monday(),
  Tuesday(),
  Wednesday(),
  Thursday(),
  Friday(),
  Weekend(),
  // const Sunday(),
];
