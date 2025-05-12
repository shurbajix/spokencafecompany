import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spokencafe/Topics/Days/Wednesday/Wednesday_Webview.dart';

class Wednesday extends ConsumerStatefulWidget {
  const Wednesday({
    super.key,
  });

  @override
  ConsumerState<Wednesday> createState() => _WednesdayState();
}

class _WednesdayState extends ConsumerState<Wednesday> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_ios_new,color:Color(0xff1B1212),),
        ),
        title: const Text(
          'Wednesday',
          style: TextStyle(
            color: Color(0xff1B1212),
            fontWeight: FontWeight.bold,
            fontSize: 30,
          ),
        ),
        //backgroundColor
        //: const Color(0xff251e3e),
      ),
      //backgroundColor: const Color(0xff251e3e),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff1B1212),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            WednesdayWebview(
                          index: index,
                          indexlevel: index,
                        ),
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
                  child: Text(
                    englishlevel[index],
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

List<String> englishlevel = [
  'I Can\'t Speak',
  'I Can Speak',
  'I Can Speak Fluent',
];
