import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spokencafe/model/Account/Log/Login.dart';

class Selecttype extends ConsumerStatefulWidget {
  const Selecttype({
    super.key,
  });

  @override
  ConsumerState<Selecttype> createState() => _SelecttypeState();
}

class _SelecttypeState extends ConsumerState<Selecttype> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      //backgroundColor: Color(0xff1F1F39),
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Choose Way',
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
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              2,
              (index) {
                return GestureDetector(
                  onTap: () {
                    if (index == 0) {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  Login(),
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
                    } else {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  Login(),
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
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xff1B1212),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Image.asset(
                            imagesd[index],
                            scale: 3.8,
                          ),
                        ),
                        Text(
                          titlesded[index],
                          style: const TextStyle(
                            fontSize: 25,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

List<String> titlesded = [
  'Teacher',
  'Student',
];
List imagesd = [
  'assets/images/teachers.png',
  'assets/images/student.png',
];
