import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Spoken Cafe',

      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Row(
                    spacing: 10,
                    children: [
                      SizedBox(width: 5),
                      Image.asset('assets/images/spoken_cafe.png', scale: 8.9),
                      Text(
                        'Spoken Cafe',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 30),
                    child: Row(
                      spacing: 40,
                      children: [
                        InkWell(
                          onTap: () {},
                          child: Text('Home', style: TextStyle(fontSize: 20)),
                        ),
                        InkWell(
                          onTap: () {},
                          child: Text('Home', style: TextStyle(fontSize: 20)),
                        ),
                        InkWell(
                          onTap: () {},
                          child: Text('Home', style: TextStyle(fontSize: 20)),
                        ),
                        InkWell(
                          onTap: () {},
                          child: Text('Home', style: TextStyle(fontSize: 20)),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {},
                              child: Image.asset(
                                'assets/images/googleplay.png',
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: Image.asset('assets/images/appstore.png'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(color: Color(0xffFBFBFD)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transforming education \ninto playful adventures',
                            style: TextStyle(fontSize: 90),
                          ),
                          Text(
                            'At EduPlay, we believe in turning “I have to learn” into “I get to\n play and learn”. a journey filled with games that teach and play that enlightens.',
                            style: TextStyle(fontSize: 20),
                          ),
                        ],
                      ),
                      Image.asset('assets/images/learn.png'),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(color: Colors.grey[200]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.all(20),
                    margin: EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(3, (index) {
                        return Column(
                          spacing: 20,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/images/learn.jpg',
                                scale: 2.9,
                              ),
                            ),
                            Text(
                              'Engaging Games',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Kids play engaging, interactive games\n that are geared toward different\n subjects, making learning fun and\n efficient',
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.all(30),
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        spacing: 20,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How it works:\nDownloading EduPlay',
                            style: TextStyle(
                              color: Color(0xff0D1216),
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Discover the magic of EduPlay in just a few simple steps!\nDownload the app and unlock a world where learning meets\nplay. All designed to captivate young minds and make\neducation an exciting journey.',
                            style: TextStyle(
                              fontSize: 20,
                              color: Color(0xff313C45),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 24,
                            children: List.generate(listtext.length, (index) {
                              return Row(
                                spacing: 16,
                                children: [
                                  Image.asset(imagesd[index]),
                                  Text(
                                    listtext[index],
                                    style: TextStyle(fontSize: 25),
                                  ),
                                ],
                              );
                            }),
                          ),
                          SizedBox(height: 20),
                          Row(
                            children: List.generate(2, (index) {
                              return TextButton(
                                onPressed: () {},
                                child: Image.asset(googleandapple[index]),
                              );
                            }),
                          ),
                        ],
                      ),
                      Container(
                        width: 700,
                        height: 1000,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            image: AssetImage('assets/images/phone.png'),
                            scale: 5.2,
                          ),
                        ),
                      ),

                      //   ClipRRect(

                      //     borderRadius: BorderRadius.circular(10),
                      //  child: Card(
                      //   color: Colors.black,
                      //   shadowColor: Colors.black,
                      //   shape: RoundedRectangleBorder(
                      //     borderRadius: BorderRadius.circular(10),
                      //   ),
                      //   elevation: 20,
                      //   child: Image.asset('assets/images/phone.png',scale: 5.2,),),
                      //  ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

List<String> listtext = [
  'Download our app',
  'Explore and Sign Up',
  'Customize preferences for a personalized learning',
  'Dive into Playful Learning',
  'Track Progress and Celebrate Achievements',
  'Stay Connected & Enjoy the Benefits of EduPlay',
];

List imagesd = [
  'assets/images/1.png',
  'assets/images/2.png',
  'assets/images/3.png',
  'assets/images/4.png',
  'assets/images/5.png',
  'assets/images/5.png',
];

List googleandapple = [
  'assets/images/googleplay.png',
  'assets/images/appstore.png',
];
