import 'package:flutter/material.dart';

List<String> addnewFutures = ['Teacher', 'Lessons', 'Student'];
List<String> earnandtakeandpay = [
  'Earns: \$4.0',
  'Lesson Take: 100',
  'Lesson Pay: 30',
];

// Home content widget to avoid recursion
class HomeContent extends StatelessWidget {
  final bool isMobile;

  const HomeContent({super.key, this.isMobile = true});

  @override
  Widget build(BuildContext context) {
    return  SingleChildScrollView(
      child: isMobile? Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
                        Card(
                          margin: const EdgeInsets.all(10),
                          color: Colors.white,
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
            Card(
              margin: const EdgeInsets.all(10),
              child: Padding(
                padding: const EdgeInsets.all(10),
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
            ),
          ],
        ),
      ) : Column(
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
                        Card(
                          margin: const EdgeInsets.all(10),
                          color: Colors.white,
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
            Card(
              margin: const EdgeInsets.all(10),
              child: Padding(
                padding: const EdgeInsets.all(10),
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
            ),
          ],
        ),
    );
  }
}