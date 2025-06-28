import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TeacherandStudent extends StatefulWidget {
  const TeacherandStudent({super.key});

  @override
  State<TeacherandStudent> createState() => _TeacherandStudentState();
}

class _TeacherandStudentState extends State<TeacherandStudent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Get today's date range for filtering
  Map<String, DateTime> getTodayRange() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return {
      'start': startOfDay,
      'end': endOfDay,
    };
  }

  // Get last 24 hours range for filtering
  Map<String, DateTime> getLast24HoursRange() {
    final now = DateTime.now();
    final twentyFourHoursAgo = now.subtract(Duration(hours: 24));
    return {
      'start': twentyFourHoursAgo,
      'end': now,
    };
  }

  // Get teacher's student count for today
  Future<Map<String, int>> getTeacherStudentCount(String teacherId) async {
    final todayRange = getTodayRange();
    int normalLessons = 0;
    int activityLessons = 0;

    try {
      // Query takenLessons for today with this teacher
      final takenLessonsQuery = await _firestore
          .collection('takenLessons')
          .where('teacherId', isEqualTo: teacherId)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayRange['start']!))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(todayRange['end']!))
          .get();

      for (var doc in takenLessonsQuery.docs) {
        final data = doc.data();
        final lessonType = data['lessonType'] ?? 'normal'; // Default to normal if not specified
        
        if (lessonType == 'activity') {
          activityLessons++;
        } else {
          normalLessons++;
        }
      }
    } catch (e) {
      print('Error getting teacher student count: $e');
    }

    return {
      'normal': normalLessons,
      'activity': activityLessons,
    };
  }

  // Check if teacher has lessons in the last 24 hours
  Future<bool> teacherHasRecentLessons(String teacherId) async {
    final last24Hours = getLast24HoursRange();
    
    try {
      final recentLessonsQuery = await _firestore
          .collection('takenLessons')
          .where('teacherId', isEqualTo: teacherId)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(last24Hours['start']!))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(last24Hours['end']!))
          .limit(1) // We only need to know if there's at least one
          .get();

      return recentLessonsQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking recent lessons: $e');
      return false;
    }
  }

  // Get filtered teachers (only those with lessons in last 24 hours)
  Future<List<QueryDocumentSnapshot>> getActiveTeachers(List<QueryDocumentSnapshot> allTeachers) async {
    List<QueryDocumentSnapshot> activeTeachers = [];
    
    for (var teacher in allTeachers) {
      final teacherId = teacher.id;
      final hasRecentLessons = await teacherHasRecentLessons(teacherId);
      
      if (hasRecentLessons) {
        activeTeachers.add(teacher);
      }
    }
    
    return activeTeachers;
  }

  Widget _buildTeacherDashboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .where('isApproved', isEqualTo: true) // Only approved teachers
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xff1B1212),
              backgroundColor: Colors.white,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final allTeachers = snapshot.data?.docs ?? [];

        if (allTeachers.isEmpty) {
          return const Center(
            child: Text(
              'No approved teachers found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          );
        }

        // Filter teachers to only show those with lessons in last 24 hours
        return FutureBuilder<List<QueryDocumentSnapshot>>(
          future: getActiveTeachers(allTeachers),
          builder: (context, activeTeachersSnapshot) {
            if (activeTeachersSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xff1B1212),
                  backgroundColor: Colors.white,
                ),
              );
            }

            final activeTeachers = activeTeachersSnapshot.data ?? [];

            if (activeTeachers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Active Teachers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Teachers will appear here when students take lessons with them',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Auto-refresh every 24 hours',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Header with today's date and active count
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xff1B1212),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Today\'s Lessons - ${DateFormat('yyyy/MM/dd').format(DateTime.now())}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.people, color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Active Teachers: ${activeTeachers.length} (Last 24h)',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Legend
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Normal Lessons (Max: 8)'),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Activity Lessons (Max: 20)'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Teachers list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: activeTeachers.length,
                    itemBuilder: (context, index) {
                      final teacher = activeTeachers[index];
                      final teacherData = teacher.data() as Map<String, dynamic>;
                      final teacherId = teacher.id;
                      final teacherName = teacherData['name'] ?? 'Unknown Teacher';
                      final profileImageUrl = teacherData['profileImageUrl'] ?? '';

                      return FutureBuilder<Map<String, int>>(
                        future: getTeacherStudentCount(teacherId),
                        builder: (context, countSnapshot) {
                          if (countSnapshot.connectionState == ConnectionState.waiting) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey[300],
                                  child: const CircularProgressIndicator(strokeWidth: 2),
                                ),
                                title: Text(teacherName),
                                subtitle: const Text('Loading...'),
                              ),
                            );
                          }

                          final counts = countSnapshot.data ?? {'normal': 0, 'activity': 0};
                          final normalCount = counts['normal'] ?? 0;
                          final activityCount = counts['activity'] ?? 0;
                          final totalCount = normalCount + activityCount;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Teacher Avatar
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Colors.grey[300],
                                    backgroundImage: profileImageUrl.isNotEmpty
                                        ? NetworkImage(profileImageUrl)
                                        : null,
                                    child: profileImageUrl.isEmpty
                                        ? const Icon(Icons.person, color: Colors.white)
                                        : null,
                                  ),
                                  
                                  const SizedBox(width: 16),
                                  
                                  // Teacher Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          teacherName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xff1B1212),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Total Students Today: $totalCount',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Lesson Counts
                                  Column(
                                    children: [
                                      // Normal Lessons
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.blue),
                                        ),
                                        child: Text(
                                          'Normal: $normalCount/8',
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 8),
                                      
                                      // Activity Lessons
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.green),
                                        ),
                                        child: Text(
                                          'Activity: $activityCount/20',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAnalytics() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('takenLessons')
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(getTodayRange()['start']!))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(getTodayRange()['end']!))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final lessons = snapshot.data?.docs ?? [];
        int totalStudents = lessons.length;
        int normalLessons = 0;
        int activityLessons = 0;

        for (var lesson in lessons) {
          final data = lesson.data() as Map<String, dynamic>;
          final lessonType = data['lessonType'] ?? 'normal';
          
          if (lessonType == 'activity') {
            activityLessons++;
          } else {
            normalLessons++;
          }
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Today\'s Analytics',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1B1212),
                ),
              ),
              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Total Students',
                      totalStudents.toString(),
                      Colors.purple,
                      Icons.people,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Normal Lessons',
                      normalLessons.toString(),
                      Colors.blue,
                      Icons.school,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Activity Lessons',
                      activityLessons.toString(),
                      Colors.green,
                      Icons.sports,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReports() {
    return const Center(
      child: Text(
        'Reports Coming Soon',
        style: TextStyle(
          fontSize: 18,
          color: Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // TabBar at the top
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Color(0xff1B1212),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xff1B1212),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.dashboard),
                  text: 'Teacher Dashboard',
                ),
                Tab(
                  icon: Icon(Icons.analytics),
                  text: 'Analytics',
                ),
                Tab(
                  icon: Icon(Icons.assignment),
                  text: 'Reports',
                ),
              ],
            ),
          ),
          // TabBarView content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTeacherDashboard(),
                _buildAnalytics(),
                _buildReports(),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 