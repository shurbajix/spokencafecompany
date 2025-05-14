import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

List<String> addnewFutures = ['Teacher', 'Lessons', 'Student'];
List<String> earnandtakeandpay = [
  'Earns: \$4.0',
  'Lesson Take: 100',
  'Lesson Pay: 30',
];

class HomeContent extends StatelessWidget {
  final bool isMobile;

  const HomeContent({super.key, this.isMobile = true});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: isMobile
          ? Padding(
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
                                child: index == 0 // Teacher section
                                    ? StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('users')
                                            .where('role', isEqualTo: 'teacher')
                                            .snapshots(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Center(
                                              child: CircularProgressIndicator(),
                                            );
                                          }
                                          if (snapshot.hasError) {
                                            return Center(
                                              child: Text('Error: ${snapshot.error}'),
                                            );
                                          }
                                          if (!snapshot.hasData ||
                                              snapshot.data!.docs.isEmpty) {
                                            return const Center(
                                              child: Text(
                                                'No teacher found',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                            );
                                          }

                                          final validTeachers = snapshot.data!.docs
                                              .where((doc) =>
                                                  doc.data() != null &&
                                                  doc['role'] == 'teacher')
                                              .toList();

                                          if (validTeachers.isEmpty) {
                                            return const Center(
                                              child: Text(
                                                'No teacher found',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                            );
                                          }

                                          return Container(
                                            height: 300,
                                            child: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: validTeachers
                                                    .asMap()
                                                    .entries
                                                    .map((entry) {
                                                  int docIndex = entry.key;
                                                  var teacher = entry.value;
                                                  String email = teacher['email']
                                                          ?.toString() ??
                                                      'No email';
                                                  String name = teacher['name']
                                                          ?.toString() ??
                                                      'No name';
                                                  String earnText =
                                                      earnandtakeandpay[docIndex %
                                                          earnandtakeandpay.length];

                                                  return ListTile(
                                                    leading: Image.asset(
                                                      'assets/images/spken_cafe.png',
                                                      width: isMobile ? 30 : 40,
                                                      height: isMobile ? 30 : 40,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          const Icon(Icons.error),
                                                    ),
                                                    title: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Text(email),
                                                        Text(name),
                                                      ],
                                                    ),
                                                    trailing: Text(
                                                      earnText,
                                                      style: TextStyle(
                                                          fontSize:
                                                              isMobile ? 16 : 20),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : index == 2 // Student section
                                        ? StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('users')
                                                .where('role', isEqualTo: 'student')
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return const Center(
                                                  child: CircularProgressIndicator(),
                                                );
                                              }
                                              if (snapshot.hasError) {
                                                return Center(
                                                  child: Text('Error: ${snapshot.error}'),
                                                );
                                              }
                                              if (!snapshot.hasData ||
                                                  snapshot.data!.docs.isEmpty) {
                                                return const Center(
                                                  child: Text(
                                                    'No students found',
                                                    style: TextStyle(fontSize: 16),
                                                  ),
                                                );
                                              }

                                              final students = snapshot.data!.docs
                                                  .where((doc) =>
                                                      doc.data() != null &&
                                                      doc['role'] == 'student')
                                                  .toList();

                                              if (students.isEmpty) {
                                                return const Center(
                                                  child: Text(
                                                    'No students found',
                                                    style: TextStyle(fontSize: 16),
                                                  ),
                                                );
                                              }

                                              return Container(
                                                height: 300,
                                                child: SingleChildScrollView(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.stretch,
                                                    children: students
                                                        .asMap()
                                                        .entries
                                                        .map((entry) {
                                                      int docIndex = entry.key;
                                                      var student = entry.value;
                                                      String email = student['email']
                                                              ?.toString() ??
                                                          'No email';
                                                      String name = student['name']
                                                              ?.toString() ??
                                                          'No name';
                                                      String earnText =
                                                          earnandtakeandpay[docIndex %
                                                              earnandtakeandpay.length];

                                                      return ListTile(
                                                        leading: Image.asset(
                                                          'assets/images/spken_cafe.png',
                                                          width: isMobile ? 30 : 40,
                                                          height: isMobile ? 30 : 40,
                                                          errorBuilder: (context,
                                                                  error,
                                                                  stackTrace) =>
                                                              const Icon(Icons.error),
                                                        ),
                                                        title: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment.start,
                                                          children: [
                                                            Text(email),
                                                            Text(name),
                                                          ],
                                                        ),
                                                        trailing: Text(
                                                          earnText,
                                                          style: TextStyle(
                                                              fontSize:
                                                                  isMobile ? 16 : 20),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: List.generate(
                                              earnandtakeandpay.length,
                                              (earnIndex) {
                                                return ListTile(
                                                  leading: Image.asset(
                                                    'assets/images/spken_cafe.png',
                                                    width: isMobile ? 30 : 40,
                                                    height: isMobile ? 30 : 40,
                                                    errorBuilder:
                                                        (context, error, stackTrace) =>
                                                            const Icon(Icons.error),
                                                  ),
                                                  title: const Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text('Placeholder Email'),
                                                      Text('Placeholder Name'),
                                                    ],
                                                  ),
                                                  trailing: Text(
                                                    earnandtakeandpay[earnIndex],
                                                    style: TextStyle(
                                                        fontSize: isMobile ? 16 : 20),
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
                                  decoration:
                                      const BoxDecoration(color: Colors.grey),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Chart',
                                        style: TextStyle(
                                            fontSize: isMobile ? 16 : 20),
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
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              child: index == 0
                                  ? StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('users')
                                          .where('role', isEqualTo: 'teacher')
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        }
                                        if (snapshot.hasError) {
                                          return Center(
                                            child: Text('Error: ${snapshot.error}'),
                                          );
                                        }
                                        if (!snapshot.hasData ||
                                            snapshot.data!.docs.isEmpty) {
                                          return const Center(
                                            child: Text(
                                              'No teacher found',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                          );
                                        }

                                        final validTeachers = snapshot.data!.docs
                                            .where((doc) =>
                                                doc.data() != null &&
                                                doc['role'] == 'teacher')
                                            .toList();

                                        if (validTeachers.isEmpty) {
                                          return const Center(
                                            child: Text(
                                              'No teacher found',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                          );
                                        }

                                        return Container(
                                          height: 300,
                                          child: SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: validTeachers
                                                  .asMap()
                                                  .entries
                                                  .map((entry) {
                                                int docIndex = entry.key;
                                                var teacher = entry.value;
                                                String email = teacher['email']
                                                        ?.toString() ??
                                                    'No email';
                                                String name = teacher['name']
                                                        ?.toString() ??
                                                    'No name';
                                                String earnText =
                                                    earnandtakeandpay[docIndex %
                                                        earnandtakeandpay.length];

                                                return ListTile(
                                                  leading: Image.asset(
                                                    'assets/images/spken_cafe.png',
                                                    width: isMobile ? 30 : 40,
                                                    height: isMobile ? 30 : 40,
                                                    errorBuilder: (context, error,
                                                            stackTrace) =>
                                                        const Icon(Icons.error),
                                                  ),
                                                  title: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(email),
                                                      Text(name),
                                                    ],
                                                  ),
                                                  trailing: Text(
                                                    earnText,
                                                    style: TextStyle(
                                                        fontSize:
                                                            isMobile ? 16 : 20),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : index == 2
                                      ? StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('users')
                                              .where('role', isEqualTo: 'student')
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return const Center(
                                                child: CircularProgressIndicator(),
                                              );
                                            }
                                            if (snapshot.hasError) {
                                              return Center(
                                                child: Text('Error: ${snapshot.error}'),
                                              );
                                            }
                                            if (!snapshot.hasData ||
                                                snapshot.data!.docs.isEmpty) {
                                              return const Center(
                                                child: Text(
                                                  'No students found',
                                                  style: TextStyle(fontSize: 16),
                                                ),
                                              );
                                            }

                                            final students = snapshot.data!.docs
                                                .where((doc) =>
                                                    doc.data() != null &&
                                                    doc['role'] == 'student')
                                                .toList();

                                            if (students.isEmpty) {
                                              return const Center(
                                                child: Text(
                                                  'No students found',
                                                  style: TextStyle(fontSize: 16),
                                                ),
                                              );
                                            }

                                            return Container(
                                              height: 300,
                                              child: SingleChildScrollView(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.stretch,
                                                  children: students
                                                      .asMap()
                                                      .entries
                                                      .map((entry) {
                                                    int docIndex = entry.key;
                                                    var student = entry.value;
                                                    String email = student['email']
                                                            ?.toString() ??
                                                        'No email';
                                                    String name = student['name']
                                                            ?.toString() ??
                                                        'No name';
                                                    String earnText =
                                                        earnandtakeandpay[docIndex %
                                                            earnandtakeandpay.length];

                                                    return ListTile(
                                                      leading: Image.asset(
                                                        'assets/images/spken_cafe.png',
                                                        width: isMobile ? 30 : 40,
                                                        height: isMobile ? 30 : 40,
                                                        errorBuilder: (context, error,
                                                                stackTrace) =>
                                                            const Icon(Icons.error),
                                                      ),
                                                      title: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment.start,
                                                        children: [
                                                          Text(email),
                                                          Text(name),
                                                        ],
                                                      ),
                                                      trailing: Text(
                                                        earnText,
                                                        style: TextStyle(
                                                            fontSize:
                                                                isMobile ? 16 : 20),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: List.generate(
                                            earnandtakeandpay.length,
                                            (earnIndex) {
                                              return ListTile(
                                                leading: Image.asset(
                                                  'assets/images/spken_cafe.png',
                                                  width: isMobile ? 30 : 40,
                                                  height: isMobile ? 30 : 40,
                                                  errorBuilder:
                                                      (context, error, stackTrace) =>
                                                          const Icon(Icons.error),
                                                ),
                                                title: const Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Placeholder Email'),
                                                    Text('Placeholder Name'),
                                                  ],
                                                ),
                                                trailing: Text(
                                                  earnandtakeandpay[earnIndex],
                                                  style: TextStyle(
                                                      fontSize: isMobile ? 16 : 20),
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
                                decoration:
                                    const BoxDecoration(color: Colors.grey),
                                child: Column(
                                  children: [
                                    Text(
                                      'Chart',
                                      style: TextStyle(
                                          fontSize: isMobile ? 16 : 20),
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
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// List<String> addnewFutures = ['Teacher', 'Lessons', 'Student'];
// List<String> earnandtakeandpay = [
//   'Earns: \$4.0',
//   'Lesson Take: 100',
//   'Lesson Pay: 30',
// ];

// class HomeContent extends StatelessWidget {
//   final bool isMobile;

//   const HomeContent({super.key, this.isMobile = true});

//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       child: isMobile
//           ? Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 children: [
//                   Row(
//                     children: List.generate(addnewFutures.length, (index) {
//                       return Expanded(
//                         child: SingleChildScrollView(
//                           child: Column(
//                             children: [
//                               Text(
//                                 addnewFutures[index],
//                                 style: TextStyle(fontSize: isMobile ? 20 : 25),
//                               ),
//                               Card(
//                                 margin: const EdgeInsets.all(10),
//                                 color: Colors.white,
//                                 child: index == 0 // Only for "Teacher" section
//                                     ? StreamBuilder<QuerySnapshot>(
//                                         stream: FirebaseFirestore.instance
//                                             .collection('users')
//                                             .where('role', isEqualTo: 'teacher')
//                                             .snapshots(),
//                                         builder: (context, snapshot) {
//                                           if (snapshot.connectionState ==
//                                               ConnectionState.waiting) {
//                                             return const Center(
//                                               child: CircularProgressIndicator(),
//                                             );
//                                           }
//                                           if (snapshot.hasError) {
//                                             return Center(
//                                               child: Text('Error: ${snapshot.error}'),
//                                             );
//                                           }
//                                           if (!snapshot.hasData ||
//                                               snapshot.data!.docs.isEmpty) {
//                                             return const Center(
//                                               child: Text(
//                                                 'No teacher found',
//                                                 style: TextStyle(fontSize: 16),
//                                               ),
//                                             );
//                                           }

//                                           // Filter out invalid documents
//                                           final validTeachers = snapshot.data!.docs
//                                               .where((doc) =>
//                                                   doc.data() != null &&
//                                                   doc['role'] == 'teacher')
//                                               .toList();

//                                           if (validTeachers.isEmpty) {
//                                             return const Center(
//                                               child: Text(
//                                                 'No teacher found',
//                                                 style: TextStyle(fontSize: 16),
//                                               ),
//                                             );
//                                           }

//                                           return Container(
//                                             height: 300, // Fixed height for the teacher list
//                                             child: SingleChildScrollView(
//                                               child: Column(
//                                                 crossAxisAlignment:
//                                                     CrossAxisAlignment.stretch,
//                                                 children: validTeachers
//                                                     .asMap()
//                                                     .entries
//                                                     .map((entry) {
//                                                   int docIndex = entry.key;
//                                                   var teacher = entry.value;
//                                                   String email = teacher['email']
//                                                           ?.toString() ??
//                                                       'No email';
//                                                   String name = teacher['name']
//                                                           ?.toString() ??
//                                                       'No name';
//                                                   String earnText =
//                                                       earnandtakeandpay[docIndex %
//                                                           earnandtakeandpay.length];

//                                                   return ListTile(
//                                                     leading: Image.asset(
//                                                       'assets/images/spken_cafe.png',
//                                                       width: isMobile ? 30 : 40,
//                                                       height: isMobile ? 30 : 40,
//                                                       errorBuilder: (context,
//                                                               error,
//                                                               stackTrace) =>
//                                                           const Icon(Icons.error),
//                                                     ),
//                                                     title: Column(
//                                                       crossAxisAlignment:
//                                                           CrossAxisAlignment.start,
//                                                       children: [
//                                                         Text(email),
//                                                         Text(name),
//                                                       ],
//                                                     ),
//                                                     trailing: Text(
//                                                       earnText,
//                                                       style: TextStyle(
//                                                           fontSize:
//                                                               isMobile ? 16 : 20),
//                                                     ),
//                                                   );
//                                                 }).toList(),
//                                               ),
//                                             ),
//                                           );
//                                         },
//                                       )
//                                     : Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment.stretch,
//                                         children: List.generate(
//                                           earnandtakeandpay.length,
//                                           (earnIndex) {
//                                             return ListTile(
//                                               leading: Image.asset(
//                                                 'assets/images/spken_cafe.png',
//                                                 width: isMobile ? 30 : 40,
//                                                 height: isMobile ? 30 : 40,
//                                                 errorBuilder:
//                                                     (context, error, stackTrace) =>
//                                                         const Icon(Icons.error),
//                                               ),
//                                               title: const Column(
//                                                 crossAxisAlignment:
//                                                     CrossAxisAlignment.start,
//                                                 children: [
//                                                   Text('Placeholder Email'),
//                                                   Text('Placeholder Name'),
//                                                 ],
//                                               ),
//                                               trailing: Text(
//                                                 earnandtakeandpay[earnIndex],
//                                                 style: TextStyle(
//                                                     fontSize: isMobile ? 16 : 20),
//                                               ),
//                                             );
//                                           },
//                                         ),
//                                       ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     }),
//                   ),
//                   // Earnings Section
//                   Card(
//                     margin: const EdgeInsets.all(10),
//                     child: Padding(
//                       padding: const EdgeInsets.all(10),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.stretch,
//                         children: [
//                           Text(
//                             'Our Earns',
//                             style: TextStyle(fontSize: isMobile ? 24 : 30),
//                           ),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceAround,
//                             children: List.generate(3, (index) {
//                               return Expanded(
//                                 child: Container(
//                                   margin: const EdgeInsets.all(10),
//                                   padding: const EdgeInsets.all(10),
//                                   decoration:
//                                       const BoxDecoration(color: Colors.grey),
//                                   child: Column(
//                                     children: [
//                                       Text(
//                                         'Chart',
//                                         style: TextStyle(
//                                             fontSize: isMobile ? 16 : 20),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               );
//                             }),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           : Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 Row(
//                   children: List.generate(addnewFutures.length, (index) {
//                     return Expanded(
//                       child: SingleChildScrollView(
//                         child: Column(
//                           children: [
//                             Text(
//                               addnewFutures[index],
//                               style: TextStyle(fontSize: isMobile ? 20 : 25),
//                             ),
//                             Card(
//                               margin: const EdgeInsets.all(10),
//                               color: Colors.white,
//                               child: index == 0 // Only for "Teacher" section
//                                   ? StreamBuilder<QuerySnapshot>(
//                                       stream: FirebaseFirestore.instance
//                                           .collection('users')
//                                           .where('role', isEqualTo: 'teacher')
//                                           .snapshots(),
//                                       builder: (context, snapshot) {
//                                         if (snapshot.connectionState ==
//                                             ConnectionState.waiting) {
//                                           return const Center(
//                                             child: CircularProgressIndicator(),
//                                           );
//                                         }
//                                         if (snapshot.hasError) {
//                                           return Center(
//                                             child: Text('Error: ${snapshot.error}'),
//                                           );
//                                         }
//                                         if (!snapshot.hasData ||
//                                             snapshot.data!.docs.isEmpty) {
//                                           return const Center(
//                                             child: Text(
//                                               'No teacher found',
//                                               style: TextStyle(fontSize: 16),
//                                             ),
//                                           );
//                                         }

//                                         // Filter out invalid documents
//                                         final validTeachers = snapshot.data!.docs
//                                             .where((doc) =>
//                                                 doc.data() != null &&
//                                                 doc['role'] == 'teacher')
//                                             .toList();

//                                         if (validTeachers.isEmpty) {
//                                           return const Center(
//                                             child: Text(
//                                               'No teacher found',
//                                               style: TextStyle(fontSize: 16),
//                                             ),
//                                           );
//                                         }

//                                         return Container(
//                                           height: 300, // Fixed height for the teacher list
//                                           child: SingleChildScrollView(
//                                             child: Column(
//                                               crossAxisAlignment:
//                                                   CrossAxisAlignment.stretch,
//                                               children: validTeachers
//                                                   .asMap()
//                                                   .entries
//                                                   .map((entry) {
//                                                 int docIndex = entry.key;
//                                                 var teacher = entry.value;
//                                                 String email = teacher['email']
//                                                         ?.toString() ??
//                                                     'No email';
//                                                 String name = teacher['name']
//                                                         ?.toString() ??
//                                                     'No name';
//                                                 String earnText =
//                                                     earnandtakeandpay[docIndex %
//                                                         earnandtakeandpay.length];

//                                                 return ListTile(
//                                                   leading: Image.asset(
//                                                     'assets/images/spken_cafe.png',
//                                                     width: isMobile ? 30 : 40,
//                                                     height: isMobile ? 30 : 40,
//                                                     errorBuilder: (context, error,
//                                                             stackTrace) =>
//                                                         const Icon(Icons.error),
//                                                   ),
//                                                   title: Column(
//                                                     crossAxisAlignment:
//                                                         CrossAxisAlignment.start,
//                                                     children: [
//                                                       Text(email),
//                                                       Text(name),
//                                                     ],
//                                                   ),
//                                                   trailing: Text(
//                                                     earnText,
//                                                     style: TextStyle(
//                                                         fontSize:
//                                                             isMobile ? 16 : 20),
//                                                   ),
//                                                 );
//                                               }).toList(),
//                                             ),
//                                           ),
//                                         );
//                                       },
//                                     )
//                                   : Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.stretch,
//                                       children: List.generate(
//                                         earnandtakeandpay.length,
//                                         (earnIndex) {
//                                           return ListTile(
//                                             leading: Image.asset(
//                                               'assets/images/spken_cafe.png',
//                                               width: isMobile ? 30 : 40,
//                                               height: isMobile ? 30 : 40,
//                                               errorBuilder:
//                                                   (context, error, stackTrace) =>
//                                                       const Icon(Icons.error),
//                                             ),
//                                             title: const Column(
//                                               crossAxisAlignment:
//                                                   CrossAxisAlignment.start,
//                                               children: [
//                                                 Text('Placeholder Email'),
//                                                 Text('Placeholder Name'),
//                                               ],
//                                             ),
//                                             trailing: Text(
//                                               earnandtakeandpay[earnIndex],
//                                               style: TextStyle(
//                                                   fontSize: isMobile ? 16 : 20),
//                                             ),
//                                           );
//                                         },
//                                       ),
//                                     ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   }),
//                 ),
//                 Card(
//                   margin: const EdgeInsets.all(10),
//                   child: Padding(
//                     padding: const EdgeInsets.all(10),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.stretch,
//                       children: [
//                         Text(
//                           'Our Earns',
//                           style: TextStyle(fontSize: isMobile ? 24 : 30),
//                         ),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceAround,
//                           children: List.generate(3, (index) {
//                             return Expanded(
//                               child: Container(
//                                 margin: const EdgeInsets.all(10),
//                                 padding: const EdgeInsets.all(10),
//                                 decoration:
//                                     const BoxDecoration(color: Colors.grey),
//                                 child: Column(
//                                   children: [
//                                     Text(
//                                       'Chart',
//                                       style: TextStyle(
//                                           fontSize: isMobile ? 16 : 20),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             );
//                           }),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }
// }