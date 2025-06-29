import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

List<String> addnewFutures = ['Teacher', 'Lessons', 'Student'];
List<String> earnandtakeandpay = [
  'Earns: \$4.0',
  'Lesson Take: 100',
  'Lesson Pay: 30',
];

class HomeContent extends StatefulWidget {
  final bool isMobile;

  const HomeContent({super.key, this.isMobile = true});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  // User name caching
  static final Map<String, String> _userNamesCache = {};
  static final Map<String, DateTime> _userNamesCacheTime = {};
  static const Duration _userNameCacheExpiry = Duration(minutes: 10);

  @override
  void dispose() {
    _clearExpiredCache();
    super.dispose();
  }

  void _clearExpiredCache() {
    final now = DateTime.now();
    _userNamesCacheTime.removeWhere((key, time) {
      if (now.difference(time) > _userNameCacheExpiry) {
        _userNamesCache.remove(key);
        return true;
      }
      return false;
    });
  }

  Future<String> _getCachedUserName(String userId) async {
    final now = DateTime.now();
    
    if (_userNamesCache.containsKey(userId) && 
        _userNamesCacheTime.containsKey(userId) &&
        now.difference(_userNamesCacheTime[userId]!) < _userNameCacheExpiry) {
      return _userNamesCache[userId]!;
    }
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));
      
      if (doc.exists) {
        final data = doc.data()!;
        final name = '${data['name'] ?? ''} ${data['surname'] ?? ''}'.trim();
        final displayName = name.isEmpty ? (data['email'] ?? 'Unknown User') : name;
        
        _userNamesCache[userId] = displayName;
        _userNamesCacheTime[userId] = now;
        
        return displayName;
      }
    } catch (e) {
      print('Error fetching user name for $userId: $e');
    }
    
    return 'Unknown User';
  }

  String _formatDateTime(dynamic dateTime) {
    try {
      DateTime dt;
      if (dateTime is Timestamp) {
        dt = dateTime.toDate();
      } else if (dateTime is String) {
        dt = DateTime.parse(dateTime);
      } else {
        return 'Invalid Date';
      }
      
      final now = DateTime.now();
      final difference = dt.difference(now);
      
      if (difference.isNegative) {
        if (difference.inDays < -1) {
          return '${dt.day}/${dt.month}/${dt.year}';
        } else {
          return 'Started ${difference.inHours.abs()}h ago';
        }
      } else {
        if (difference.inDays > 0) {
          return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } else if (difference.inHours > 0) {
          return 'Starts in ${difference.inHours}h ${difference.inMinutes.remainder(60)}m';
        } else {
          return 'Starts in ${difference.inMinutes}m';
        }
      }
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _getLessonStatus(dynamic dateTime) {
    try {
      DateTime dt;
      if (dateTime is Timestamp) {
        dt = dateTime.toDate();
      } else if (dateTime is String) {
        dt = DateTime.parse(dateTime);
      } else {
        return 'Unknown';
      }
      
      final now = DateTime.now();
      final lessonEnd = dt.add(const Duration(hours: 2));
      
      if (now.isBefore(dt)) {
        return 'Upcoming';
      } else if (now.isAfter(dt) && now.isBefore(lessonEnd)) {
        return 'Active';
      } else {
        return 'Completed';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Upcoming':
        return Colors.blue;
      case 'Completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLessonsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lessons')
          .orderBy('dateTime', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 300,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Loading lessons...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            height: 300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 50),
                  const SizedBox(height: 10),
                  Text('Error loading lessons: ${snapshot.error}'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            height: 300,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 50, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    'No lessons found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        final lessons = snapshot.data!.docs;

        return Container(
          height: 300,
          child: ListView.builder(
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              final data = lesson.data() as Map<String, dynamic>;

              final teacherId = data['teacherId']?.toString() ?? '';
              final speakLevel = data['speakLevel']?.toString() ?? 'Unknown';
              final description = data['description']?.toString() ?? 'No description';
              final locationName = data['locationName']?.toString() ?? 'Unknown location';
              final maxStudents = data['maxStudents'] ?? 8;
              final currentStudentCount = data['currentStudentCount'] ?? 0;
              final dateTime = data['dateTime'];
              
              final status = _getLessonStatus(dateTime);
              final formattedDateTime = _formatDateTime(dateTime);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              speakLevel,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      FutureBuilder<String>(
                        future: _getCachedUserName(teacherId),
                        builder: (context, teacherSnapshot) {
                          return Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  teacherSnapshot.data ?? 'Loading teacher...',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              formattedDateTime,
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              locationName,
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      
                      Row(
                        children: [
                          const Icon(Icons.group, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '$currentStudentCount/$maxStudents students',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                      
                      if (description.isNotEmpty && description != 'No description') ...[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: widget.isMobile
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
                                style: TextStyle(fontSize: widget.isMobile ? 20 : 25),
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
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return const Center(child: CircularProgressIndicator());
                                          }
                                          if (snapshot.hasError) {
                                            return Center(child: Text('Error: ${snapshot.error}'));
                                          }
                                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                            return const Center(
                                              child: Text('No teacher found', style: TextStyle(fontSize: 16)),
                                            );
                                          }
                                          
                                          final validTeachers = snapshot.data!.docs.where((doc) {
                                            final data = doc.data() as Map<String, dynamic>;
                                            return data['role'] == 'teacher';
                                          }).toList();

                                          if (validTeachers.isEmpty) {
                                            return const Center(
                                              child: Text('No teacher found', style: TextStyle(fontSize: 16)),
                                            );
                                          }

                                          return Container(
                                            height: 300,
                                            child: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: validTeachers.asMap().entries.map((entry) {
                                                  int docIndex = entry.key;
                                                  var teacher = entry.value;
                                                  final data = teacher.data() as Map<String, dynamic>;

                                                  String email = data['email']?.toString() ?? 'No email';
                                                  String name = data['name']?.toString() ?? 'No name';
                                                  String? photoUrl = data.containsKey('photoUrl') 
                                                      ? data['photoUrl']?.toString() : null;
                                                  String earnText = earnandtakeandpay[docIndex % earnandtakeandpay.length];

                                                  return ListTile(
                                                    leading: CircleAvatar(
                                                      radius: widget.isMobile ? 15 : 20,
                                                      backgroundImage: photoUrl != null
                                                          ? NetworkImage(photoUrl)
                                                          : const AssetImage('assets/images/spken_cafe.png') as ImageProvider,
                                                    ),
                                                    title: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [Text(email), Text(name)],
                                                    ),
                                                    trailing: Text(
                                                      earnText,
                                                      style: TextStyle(fontSize: widget.isMobile ? 16 : 20),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : index == 1
                                        ? _buildLessonsSection()
                                        : StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('users')
                                                .where('role', isEqualTo: 'student')
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return const Center(child: CircularProgressIndicator());
                                              }
                                              if (snapshot.hasError) {
                                                return Center(child: Text('Error: ${snapshot.error}'));
                                              }
                                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                                return const Center(
                                                  child: Text('No students found', style: TextStyle(fontSize: 16)),
                                                );
                                              }

                                              final students = snapshot.data!.docs.where((doc) {
                                                final data = doc.data() as Map<String, dynamic>;
                                                return data['role'] == 'student';
                                              }).toList();

                                              if (students.isEmpty) {
                                                return const Center(
                                                  child: Text('No students found', style: TextStyle(fontSize: 16)),
                                                );
                                              }

                                              return Container(
                                                height: 300,
                                                child: SingleChildScrollView(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                                    children: students.asMap().entries.map((entry) {
                                                      int docIndex = entry.key;
                                                      var student = entry.value;
                                                      final data = student.data() as Map<String, dynamic>;

                                                      String email = data['email']?.toString() ?? 'No email';
                                                      String name = data['name']?.toString() ?? 'No name';
                                                      String? photoUrl = data.containsKey('photoUrl')
                                                          ? data['photoUrl']?.toString() : null;
                                                      String earnText = earnandtakeandpay[docIndex % earnandtakeandpay.length];

                                                      return ListTile(
                                                        leading: CircleAvatar(
                                                          radius: widget.isMobile ? 15 : 20,
                                                          backgroundImage: photoUrl != null
                                                              ? NetworkImage(photoUrl)
                                                              : const AssetImage('assets/images/spken_cafe.png') as ImageProvider,
                                                        ),
                                                        title: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [Text(email), Text(name)],
                                                        ),
                                                        trailing: Text(
                                                          earnText,
                                                          style: TextStyle(fontSize: widget.isMobile ? 16 : 20),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                              );
                                            },
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
                            style: TextStyle(fontSize: widget.isMobile ? 24 : 30),
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
                                        style: TextStyle(fontSize: widget.isMobile ? 16 : 20),
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
                    stream: FirebaseFirestore.instance.collection('cities').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text('No locations found', style: TextStyle(fontSize: 16)),
                        );
                      }

                      // Count how many times each city appears
                      Map<String, int> cityCounts = {};
                      for (var doc in snapshot.data!.docs) {
                        final city = doc['name']?.toString() ?? 'Unknown';
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
                                fontSize: widget.isMobile ? 22 : 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: const [
                                Expanded(
                                  child: Text(
                                    'City',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Count',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Tag',
                                    style: TextStyle(fontWeight: FontWeight.bold),
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
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.orangeAccent,
                                                  borderRadius: BorderRadius.circular(20),
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
          : Padding(
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
                                style: TextStyle(fontSize: widget.isMobile ? 20 : 25),
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
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return const Center(child: CircularProgressIndicator());
                                          }
                                          if (snapshot.hasError) {
                                            return Center(child: Text('Error: ${snapshot.error}'));
                                          }
                                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                            return const Center(
                                              child: Text('No teacher found', style: TextStyle(fontSize: 16)),
                                            );
                                          }
                                          
                                          final validTeachers = snapshot.data!.docs.where((doc) {
                                            final data = doc.data() as Map<String, dynamic>;
                                            return data['role'] == 'teacher';
                                          }).toList();

                                          if (validTeachers.isEmpty) {
                                            return const Center(
                                              child: Text('No teacher found', style: TextStyle(fontSize: 16)),
                                            );
                                          }

                                          return Container(
                                            height: 300,
                                            child: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: validTeachers.asMap().entries.map((entry) {
                                                  int docIndex = entry.key;
                                                  var teacher = entry.value;
                                                  final data = teacher.data() as Map<String, dynamic>;

                                                  String email = data['email']?.toString() ?? 'No email';
                                                  String name = data['name']?.toString() ?? 'No name';
                                                  String? photoUrl = data.containsKey('photoUrl') 
                                                      ? data['photoUrl']?.toString() : null;
                                                  String earnText = earnandtakeandpay[docIndex % earnandtakeandpay.length];

                                                  return ListTile(
                                                    leading: CircleAvatar(
                                                      radius: widget.isMobile ? 15 : 20,
                                                      backgroundImage: photoUrl != null
                                                          ? NetworkImage(photoUrl)
                                                          : const AssetImage('assets/images/spken_cafe.png') as ImageProvider,
                                                    ),
                                                    title: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [Text(email), Text(name)],
                                                    ),
                                                    trailing: Text(
                                                      earnText,
                                                      style: TextStyle(fontSize: widget.isMobile ? 16 : 20),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : index == 1
                                        ? _buildLessonsSection()
                                        : StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('users')
                                                .where('role', isEqualTo: 'student')
                                                .snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return const Center(child: CircularProgressIndicator());
                                              }
                                              if (snapshot.hasError) {
                                                return Center(child: Text('Error: ${snapshot.error}'));
                                              }
                                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                                return const Center(
                                                  child: Text('No students found', style: TextStyle(fontSize: 16)),
                                                );
                                              }

                                              final students = snapshot.data!.docs.where((doc) {
                                                final data = doc.data() as Map<String, dynamic>;
                                                return data['role'] == 'student';
                                              }).toList();

                                              if (students.isEmpty) {
                                                return const Center(
                                                  child: Text('No students found', style: TextStyle(fontSize: 16)),
                                                );
                                              }

                                              return Container(
                                                height: 300,
                                                child: SingleChildScrollView(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                                    children: students.asMap().entries.map((entry) {
                                                      int docIndex = entry.key;
                                                      var student = entry.value;
                                                      final data = student.data() as Map<String, dynamic>;

                                                      String email = data['email']?.toString() ?? 'No email';
                                                      String name = data['name']?.toString() ?? 'No name';
                                                      String? photoUrl = data.containsKey('photoUrl')
                                                          ? data['photoUrl']?.toString() : null;
                                                      String earnText = earnandtakeandpay[docIndex % earnandtakeandpay.length];

                                                      return ListTile(
                                                        leading: CircleAvatar(
                                                          radius: widget.isMobile ? 15 : 20,
                                                          backgroundImage: photoUrl != null
                                                              ? NetworkImage(photoUrl)
                                                              : const AssetImage('assets/images/spken_cafe.png') as ImageProvider,
                                                        ),
                                                        title: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [Text(email), Text(name)],
                                                        ),
                                                        trailing: Text(
                                                          earnText,
                                                          style: TextStyle(fontSize: widget.isMobile ? 16 : 20),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
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
    );
  }
}

