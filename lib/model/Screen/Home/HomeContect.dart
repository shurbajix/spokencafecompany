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
                                              .where((doc) {
                                                final data =
                                                    doc.data() as Map<String, dynamic>;
                                                return data['role'] == 'teacher';
                                              })
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
                                                  final data = teacher.data()
                                                      as Map<String, dynamic>;

                                                  String email =
                                                      data['email']?.toString() ??
                                                          'No email';
                                                  String name =
                                                      data['name']?.toString() ??
                                                          'No name';

                                                  String? photoUrl = data.containsKey('photoUrl')
                                                      ? data['photoUrl']?.toString()
                                                      : null;

                                                  String earnText =
                                                      earnandtakeandpay[docIndex %
                                                          earnandtakeandpay.length];

                                                  return ListTile(
                                                    leading: CircleAvatar(
                                                      radius: isMobile ? 15 : 20,
                                                      backgroundImage: photoUrl != null
                                                          ? NetworkImage(photoUrl)
                                                          : const AssetImage(
                                                                  'assets/images/spken_cafe.png')
                                                              as ImageProvider,
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
                                                  .where((doc) {
                                                    final data =
                                                        doc.data() as Map<String, dynamic>;
                                                    return data['role'] == 'student';
                                                  })
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
                                                      final data = student.data()
                                                          as Map<String, dynamic>;

                                                      String email =
                                                          data['email']?.toString() ??
                                                              'No email';
                                                      String name =
                                                          data['name']?.toString() ??
                                                              'No name';

                                                      String? photoUrl =
                                                          data.containsKey('photoUrl')
                                                              ? data['photoUrl']?.toString()
                                                              : null;

                                                      String earnText =
                                                          earnandtakeandpay[docIndex %
                                                              earnandtakeandpay.length];

                                                      return ListTile(
                                                        leading: CircleAvatar(
                                                          radius: isMobile ? 15 : 20,
                                                          backgroundImage: photoUrl != null
                                                              ? NetworkImage(photoUrl)
                                                              : const AssetImage(
                                                                      'assets/images/spken_cafe.png')
                                                                  as ImageProvider,
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
                                                  leading: CircleAvatar(
                                                    radius: isMobile ? 15 : 20,
                                                    backgroundImage:
                                                        const AssetImage(
                                                                'assets/images/spken_cafe.png')
                                                            as ImageProvider,
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
                    color: Colors.white,
                    shadowColor: Colors.white,
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
                    StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('cities')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                            child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData ||
                          snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No locations found',
                            style: TextStyle(fontSize: 16),
                          ),
                        );
                      }

                      // Count how many times each city appears
                      Map<String, int> cityCounts = {};
                      for (var doc in snapshot.data!.docs) {
                        final city =
                            doc['name']?.toString() ?? 'Unknown';
                        cityCounts[city] = (cityCounts[city] ?? 0) + 1;
                      }

                      // Sort cities by count descending
                      final sortedCities = cityCounts.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Teachers Locations',
                              style: TextStyle(
                                fontSize: isMobile ? 22 : 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: const [
                                Expanded(
                                  child: Text(
                                    'City',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Count',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Tag',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            ...sortedCities.asMap().entries.map((entry) {
                              int index = entry.key;
                              String city = entry.value.key;
                              int count = entry.value.value;

                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(city)),
                                      Expanded(child: Text(count.toString())),
                                      Expanded(
                                        child: index == 0
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.orangeAccent,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: const Text(
                                                  'Most Popular City',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            )
          :  Column(
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
                                            .where((doc) {
                                              final data =
                                                  doc.data() as Map<String, dynamic>;
                                              return data['role'] == 'teacher';
                                            })
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
                                                final data = teacher.data()
                                                    as Map<String, dynamic>;

                                                String email =
                                                    data['email']?.toString() ??
                                                        'No email';
                                                String name =
                                                    data['name']?.toString() ??
                                                        'No name';

                                                String? photoUrl = data.containsKey('photoUrl')
                                                    ? data['photoUrl']?.toString()
                                                    : null;

                                                String earnText =
                                                    earnandtakeandpay[docIndex %
                                                        earnandtakeandpay.length];

                                                return ListTile(
                                                  leading: CircleAvatar(
                                                    radius: isMobile ? 15 : 20,
                                                    backgroundImage: photoUrl != null
                                                        ? NetworkImage(photoUrl)
                                                        : const AssetImage(
                                                                'assets/images/spken_cafe.png')
                                                            as ImageProvider,
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
                                                .where((doc) {
                                                  final data =
                                                      doc.data() as Map<String, dynamic>;
                                                  return data['role'] == 'student';
                                                })
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
                                                    final data = student.data()
                                                        as Map<String, dynamic>;

                                                    String email =
                                                        data['email']?.toString() ??
                                                            'No email';
                                                    String name =
                                                        data['name']?.toString() ??
                                                            'No name';

                                                    String? photoUrl =
                                                        data.containsKey('photoUrl')
                                                            ? data['photoUrl']?.toString()
                                                            : null;

                                                    String earnText =
                                                        earnandtakeandpay[docIndex %
                                                            earnandtakeandpay.length];

                                                    return ListTile(
                                                      leading: CircleAvatar(
                                                        radius: isMobile ? 15 : 20,
                                                        backgroundImage: photoUrl != null
                                                            ? NetworkImage(photoUrl)
                                                            : const AssetImage(
                                                                    'assets/images/spken_cafe.png')
                                                                as ImageProvider,
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
                                                leading: CircleAvatar(
                                                  radius: isMobile ? 15 : 20,
                                                  backgroundImage:
                                                      const AssetImage(
                                                              'assets/images/spken_cafe.png')
                                                          as ImageProvider,
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

