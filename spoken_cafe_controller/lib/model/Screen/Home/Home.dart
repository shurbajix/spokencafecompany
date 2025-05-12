import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('welcomes'),
        /// Left Side - "welcomes" Section

        /// Right Side - Remaining Content
        // Expanded(
        //   flex: 6,
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.stretch,
        //     children: [
        //       Row(
        //         children: List.generate(addnewFutures.length, (index) {
        //           return Expanded(
        //             child: SingleChildScrollView(
        //               child: Column(
        //                 children: [
        //                   Text(
        //                     addnewFutures[index],
        //                     style: const TextStyle(fontSize: 25),
        //                   ),
        //                   Container(
        //                     margin: const EdgeInsets.all(10),
        //                     decoration: const BoxDecoration(
        //                       color: Colors.white,
        //                     ),
        //                     child: Column(
        //                       crossAxisAlignment: CrossAxisAlignment.stretch,
        //                       children: List.generate(
        //                         earnandtakeandpay.length,
        //                         (index) {
        //                           return ListTile(
        //                             leading: Image.asset(
        //                               'assets/images/spken_cafe.png',
        //                             ),
        //                             title: Column(
        //                               crossAxisAlignment:
        //                                   CrossAxisAlignment.start,
        //                               children: const [
        //                                 Text('Andrewahmad2@gmail.com'),
        //                                 Text('Andrew Teacher'),
        //                               ],
        //                             ),
        //                             trailing: Text(
        //                               earnandtakeandpay[index],
        //                               style: const TextStyle(fontSize: 20),
        //                             ),
        //                           );
        //                         },
        //                       ),
        //                     ),
        //                   ),
        //                 ],
        //               ),
        //             ),
        //           );
        //         }),
        //       ),

        //       /// Earnings Section
        //       Container(
        //         margin: const EdgeInsets.all(10),
        //         padding: const EdgeInsets.all(10),
        //         decoration: BoxDecoration(
        //           color: Colors.white,
        //           borderRadius: BorderRadius.circular(10),
        //         ),
        //         child: Column(
        //           crossAxisAlignment: CrossAxisAlignment.stretch,
        //           children: [
        //             const Text('Our Earns', style: TextStyle(fontSize: 30)),

        //             Row(
        //               mainAxisAlignment: MainAxisAlignment.spaceAround,
        //               children: List.generate(3, (index) {
        //                 return Expanded(
        //                   child: Container(
        //                     margin: const EdgeInsets.all(10),
        //                     padding: const EdgeInsets.all(10),
        //                     decoration: const BoxDecoration(color: Colors.grey),
        //                     child: const Column(
        //                       children: [
        //                         Text('Chart', style: TextStyle(fontSize: 20)),
        //                       ],
        //                     ),
        //                   ),
        //                 );
        //               }),
        //             ),
        //           ],
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
      ],
    );
  }
}

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
