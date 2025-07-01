import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class TeacherandStudent extends StatefulWidget {
  const TeacherandStudent({super.key});

  @override
  State<TeacherandStudent> createState() => _TeacherandStudentState();
}

class _TeacherandStudentState extends State<TeacherandStudent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  List<Map<String, dynamic>> _allTeachersData = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTeachersData();
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

  // Get teacher's student count for today - FIXED VERSION
  Future<Map<String, int>> getTeacherStudentCount(String teacherId) async {
    final todayRange = getTodayRange();
    int normalLessons = 0;
    int activityLessons = 0;

    try {
      print('DEBUG: Querying takenLessons for teacher: $teacherId');
      print('DEBUG: Date range: ${todayRange['start']} to ${todayRange['end']}');
      
      // Query takenLessons for today with this teacher
      final takenLessonsQuery = await _firestore
          .collection('takenLessons')
          .where('teacherId', isEqualTo: teacherId)
          .get(); // Remove date filter temporarily to debug

      print('DEBUG: Found ${takenLessonsQuery.docs.length} total takenLessons for teacher $teacherId');

      // Filter by date manually and get lesson details
      for (var doc in takenLessonsQuery.docs) {
        final data = doc.data();
        print('DEBUG: takenLesson doc data: $data');
        
        // Check if lesson is from today
        final lessonDateTime = data['dateTime'];
        DateTime lessonDate;
        
        if (lessonDateTime is Timestamp) {
          lessonDate = lessonDateTime.toDate();
        } else if (lessonDateTime is String) {
          lessonDate = DateTime.tryParse(lessonDateTime) ?? DateTime.now();
        } else {
          continue; // Skip if dateTime format is unknown
        }
        
        // Check if lesson is from today
        if (lessonDate.isBefore(todayRange['start']!) || lessonDate.isAfter(todayRange['end']!)) {
          continue; // Skip lessons not from today
        }
        
        // Get the speakLevel from the takenLesson data (copied from original lesson)
        final speakLevel = data['speakLevel'] ?? 'normal';
        print('DEBUG: Lesson speakLevel: $speakLevel');
        
        // Count based on speakLevel (Activity lessons vs Normal lessons)
        if (speakLevel.toLowerCase() == 'activity') {
          activityLessons++;
        } else {
          normalLessons++;
        }
      }
      
      print('DEBUG: Final counts - Normal: $normalLessons, Activity: $activityLessons');
    } catch (e) {
      print('Error getting teacher student count: $e');
    }

    return {
      'normal': normalLessons,
      'activity': activityLessons,
    };
  }

  // Check if teacher has lessons in the last 24 hours - FIXED VERSION
  Future<bool> teacherHasRecentLessons(String teacherId) async {
    final last24Hours = getLast24HoursRange();
    
    try {
      print('DEBUG: Checking recent lessons for teacher: $teacherId');
      
      // First, let's check all takenLessons for this teacher
      final allLessonsQuery = await _firestore
          .collection('takenLessons')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      print('DEBUG: Total takenLessons for teacher $teacherId: ${allLessonsQuery.docs.length}');
      
      // Check each lesson manually for date range
      for (var doc in allLessonsQuery.docs) {
        final data = doc.data();
        final lessonDateTime = data['dateTime'];
        DateTime lessonDate;
        
        if (lessonDateTime is Timestamp) {
          lessonDate = lessonDateTime.toDate();
        } else if (lessonDateTime is String) {
          lessonDate = DateTime.tryParse(lessonDateTime) ?? DateTime.now();
        } else {
          continue;
        }
        
        // Check if lesson is within last 24 hours
        if (lessonDate.isAfter(last24Hours['start']!) && lessonDate.isBefore(last24Hours['end']!)) {
          print('DEBUG: Teacher $teacherId has recent lesson at $lessonDate');
          return true;
        }
      }
      
      print('DEBUG: Teacher $teacherId has NO recent lessons');
      return false;
    } catch (e) {
      print('Error checking recent lessons: $e');
      return false;
    }
  }

  // Get teacher's IBAN information from user_settings
  Future<Map<String, dynamic>?> getTeacherIBANInfo(String teacherId) async {
    try {
      print('DEBUG: 🔍 Fetching IBAN info for teacher: $teacherId');
      print('DEBUG: 📂 Querying user_settings collection...');
      
      final doc = await _firestore
          .collection('user_settings')
          .doc(teacherId)
          .get();

      print('DEBUG: 📄 Document exists: ${doc.exists}');
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        print('DEBUG: 📋 Raw user_settings data: $data');
        
        final ibanInfo = {
          'iban': data['iban'] ?? '',
          'holderName': data['holderName'] ?? '',
          'phoneNumber': data['phoneNumber'] ?? '',
          'hasIBANInfo': true,
        };
        
        print('DEBUG: ✅ IBAN info found for teacher $teacherId:');
        print('DEBUG: - IBAN: ${ibanInfo['iban']}');
        print('DEBUG: - Holder Name: ${ibanInfo['holderName']}');
        print('DEBUG: - Phone: ${ibanInfo['phoneNumber']}');
        
        return ibanInfo;
      } else {
        print('DEBUG: ❌ No IBAN info found for teacher $teacherId');
        print('DEBUG: - Document exists: ${doc.exists}');
        print('DEBUG: - Document data: ${doc.data()}');
        return null;
      }
    } catch (e) {
      print('DEBUG: ❌ Error getting teacher IBAN info for $teacherId: $e');
      print('DEBUG: Error details: ${e.toString()}');
      return null;
    }
  }

  // Load teachers data once
  Future<void> _loadTeachersData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final data = await getTeachersWithLessonData();
      setState(() {
        _allTeachersData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading teachers data: $e');
    }
  }

  // Filter teachers based on search query
  List<Map<String, dynamic>> _filterTeachers(List<Map<String, dynamic>> teachers) {
    if (_searchQuery.isEmpty) {
      return teachers;
    }
    
    return teachers.where((teacher) {
      final teacherData = teacher['teacherData'] as Map<String, dynamic>;
      final teacherName = '${teacherData['name'] ?? ''} ${teacherData['surname'] ?? ''}'.toLowerCase();
      final teacherEmail = teacherData['email']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      
      return teacherName.contains(query) || teacherEmail.contains(query);
    }).toList();
  }

  // Get all teachers with their lesson data and IBAN information - ENHANCED VERSION
  Future<List<Map<String, dynamic>>> getTeachersWithLessonData() async {
    try {
      print('DEBUG: Starting to get teachers with lesson data and IBAN info...');
      
      // Get all approved teachers
      final teachersQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .where('isApproved', isEqualTo: true)
          .get();

      print('DEBUG: Found ${teachersQuery.docs.length} approved teachers');

      // Get all takenLessons from last 24 hours
      final last24Hours = getLast24HoursRange();
      final recentTakenLessons = await _firestore
          .collection('takenLessons')
          .get(); // Get all for now, filter manually

      print('DEBUG: Found ${recentTakenLessons.docs.length} total takenLessons');

      // Group lessons by teacher and filter by date
      Map<String, List<Map<String, dynamic>>> teacherLessons = {};
      
      for (var lessonDoc in recentTakenLessons.docs) {
        final lessonData = lessonDoc.data();
        final teacherId = lessonData['teacherId'];
        final lessonDateTime = lessonData['dateTime'];
        
        if (teacherId == null) continue;
        
        DateTime lessonDate;
        if (lessonDateTime is Timestamp) {
          lessonDate = lessonDateTime.toDate();
        } else if (lessonDateTime is String) {
          lessonDate = DateTime.tryParse(lessonDateTime) ?? DateTime.now();
        } else {
          continue;
        }
        
        // Check if lesson is within last 24 hours
        if (lessonDate.isAfter(last24Hours['start']!) && lessonDate.isBefore(last24Hours['end']!)) {
          if (!teacherLessons.containsKey(teacherId)) {
            teacherLessons[teacherId] = [];
          }
          teacherLessons[teacherId]!.add({
            ...lessonData,
            'lessonDate': lessonDate,
          });
        }
      }

      print('DEBUG: Teachers with recent lessons: ${teacherLessons.keys.length}');

      // Build result list with teacher data, lesson counts, and IBAN info
      List<Map<String, dynamic>> result = [];
      
      for (var teacherDoc in teachersQuery.docs) {
        final teacherId = teacherDoc.id;
        final teacherData = teacherDoc.data();
        
        // Get IBAN information for this teacher (regardless of lessons)
        print('DEBUG: 🔍 Getting IBAN info for teacher: $teacherId');
        final ibanInfo = await getTeacherIBANInfo(teacherId);
        print('DEBUG: 📊 IBAN info result for $teacherId: ${ibanInfo != null ? 'Found' : 'Not found'}');
        
        // Initialize lesson counts
        int normalCount = 0;
        int activityCount = 0;
        
        // Check if teacher has recent lessons
        if (teacherLessons.containsKey(teacherId)) {
          final lessons = teacherLessons[teacherId]!;
          
          // Count lessons by type for today
          final todayRange = getTodayRange();
          
          for (var lesson in lessons) {
            final lessonDate = lesson['lessonDate'] as DateTime;
            
            // Only count lessons from today
            if (lessonDate.isAfter(todayRange['start']!) && lessonDate.isBefore(todayRange['end']!)) {
              final speakLevel = lesson['speakLevel'] ?? 'normal';
              if (speakLevel.toLowerCase() == 'activity') {
                activityCount++;
              } else {
                normalCount++;
              }
            }
          }
          
          print('DEBUG: 📚 Teacher $teacherId has $normalCount normal and $activityCount activity lessons today');
        } else {
          print('DEBUG: 📚 Teacher $teacherId has no recent lessons');
        }
        
        // Add teacher to result (regardless of lesson count)
        result.add({
          'teacherId': teacherId,
          'teacherData': teacherData,
          'normalCount': normalCount,
          'activityCount': activityCount,
          'totalCount': normalCount + activityCount,
          'ibanInfo': ibanInfo,
          'hasRecentLessons': teacherLessons.containsKey(teacherId),
        });
      }
      
      print('DEBUG: Final result: ${result.length} active teachers');
      
      // Count teachers with IBAN info
      int teachersWithIBAN = 0;
      for (var teacher in result) {
        final ibanInfo = teacher['ibanInfo'] as Map<String, dynamic>?;
        if (ibanInfo != null && ibanInfo['hasIBANInfo'] == true) {
          teachersWithIBAN++;
        }
      }
      print('DEBUG: 📊 Summary - Teachers with IBAN info: $teachersWithIBAN out of ${result.length}');
      
      return result;
      
    } catch (e) {
      print('ERROR: Error getting teachers with lesson data: $e');
      return [];
    }
  }

  Widget _buildTeacherDashboard() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xff1B1212),
          backgroundColor: Colors.white,
        ),
      );
    }

    final teachersWithLessons = _filterTeachers(_allTeachersData);

    if (teachersWithLessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty ? Icons.schedule : Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No Active Teachers' : 'No Teachers Found',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty 
                  ? 'Teachers will appear here when students take lessons with them'
                  : 'No teachers match your search: "$_searchQuery"',
              style: const TextStyle(
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadTeachersData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff1B1212),
                foregroundColor: Colors.white,
              ),
              child: const Text('Refresh'),
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
                    _searchQuery.isEmpty 
                        ? 'All Approved Teachers: ${_allTeachersData.length}'
                        : 'Filtered Teachers: ${teachersWithLessons.length} of ${_allTeachersData.length}',
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
        
        // Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search teachers by name or email...',
              prefixIcon: const Icon(Icons.search, color: Color(0xff1B1212)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xff1B1212)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xff1B1212), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
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
          child: RefreshIndicator(
            onRefresh: _loadTeachersData,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: teachersWithLessons.length,
              itemBuilder: (context, index) {
                final teacherInfo = teachersWithLessons[index];
                final teacherData = teacherInfo['teacherData'] as Map<String, dynamic>;
                final teacherId = teacherInfo['teacherId'] as String;
                final teacherName = teacherData['name'] ?? 'Unknown Teacher';
                final profileImageUrl = teacherData['profileImageUrl'] ?? '';
                final normalCount = teacherInfo['normalCount'] as int;
                final activityCount = teacherInfo['activityCount'] as int;
                final totalCount = teacherInfo['totalCount'] as int;
                final ibanInfo = teacherInfo['ibanInfo'] as Map<String, dynamic>?;
                final hasRecentLessons = teacherInfo['hasRecentLessons'] as bool;

                // Debug logging for UI
                print('DEBUG: 🎨 Building UI for teacher: $teacherName');
                print('DEBUG: 🎨 IBAN info for UI: ${ibanInfo != null ? 'Available' : 'Not available'}');
                print('DEBUG: 🎨 Has recent lessons: $hasRecentLessons');
                if (ibanInfo != null) {
                  print('DEBUG: 🎨 IBAN details: ${ibanInfo['holderName']} - ${ibanInfo['iban']}');
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Teacher info row
                        Row(
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

                                  Text(
                                    hasRecentLessons 
                                        ? 'Total Students Today: $totalCount'
                                        : 'No Recent Lessons',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: hasRecentLessons ? Colors.grey[600] : Colors.orange[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Lesson Counts
                            Column(
                              children: [
                                if (hasRecentLessons) ...[
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
                                ] else ...[
                                  // No Recent Lessons Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange),
                                    ),
                                    child: const Text(
                                      'No Recent Lessons',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        
                        // IBAN Information Section
                        if (ibanInfo != null && ibanInfo['hasIBANInfo'] == true) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          
                          // IBAN Info Header
                          Row(
                            children: [
                              const Icon(Icons.account_balance, color: Color(0xff1B1212), size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'IBAN Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff1B1212),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Available',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // IBAN Details
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Column(
                              children: [
                                _buildIBANField(
                                  'Account Holder',
                                  ibanInfo['holderName'] ?? 'Not provided',
                                  Icons.person_outline,
                                ),
                                const SizedBox(height: 8),
                                _buildIBANField(
                                  'Phone Number',
                                  ibanInfo['phoneNumber'] ?? 'Not provided',
                                  Icons.phone_outlined,
                                ),
                                const SizedBox(height: 8),
                                _buildIBANField(
                                  'IBAN Number',
                                  ibanInfo['iban'] ?? 'Not provided',
                                  Icons.account_balance_outlined,
                                  isIBAN: true,
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          
                          // No IBAN Info
                          Row(
                            children: [
                              const Icon(Icons.account_balance, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'IBAN Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff1B1212),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Not Set',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange[600], size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Teacher has not provided IBAN information yet',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIBANField(String label, String value, IconData icon, {bool isIBAN = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.green[700]),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.green[800],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: () => _copyToClipboard(value, label),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isIBAN ? _formatIBAN(value) : value,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontFamily: isIBAN ? 'monospace' : null,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.copy,
                  size: 14,
                  color: Colors.green[600],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatIBAN(String iban) {
    if (iban.length != 24) return iban;
    
    // Format as TR XX XXXX XXXX XXXX XXXX XXXX XX
    return 'TR ${iban.substring(0, 2)} ${iban.substring(2, 6)} ${iban.substring(6, 10)} ${iban.substring(10, 14)} ${iban.substring(14, 18)} ${iban.substring(18, 22)} ${iban.substring(22, 24)}';
  }

  // Copy text to clipboard
  Future<void> _copyToClipboard(String text, String fieldName) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fieldName copied to clipboard'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildAnalytics() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final teachersWithLessons = _allTeachersData;
        
        // Calculate totals
        int totalStudents = 0;
        int normalLessons = 0;
        int activityLessons = 0;
        int teachersWithIBAN = 0;
        int activeTeachers = 0;
        for (var teacher in teachersWithLessons) {
          totalStudents += teacher['totalCount'] as int;
          normalLessons += teacher['normalCount'] as int;
          activityLessons += teacher['activityCount'] as int;
          
          final ibanInfo = teacher['ibanInfo'] as Map<String, dynamic>?;
          if (ibanInfo != null && ibanInfo['hasIBANInfo'] == true) {
            teachersWithIBAN++;
          }
          
          final hasRecentLessons = teacher['hasRecentLessons'] as bool;
          if (hasRecentLessons) {
            activeTeachers++;
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
                      'Total Teachers',
                      teachersWithLessons.length.toString(),
                      Colors.purple,
                      Icons.people,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Active Teachers',
                      activeTeachers.toString(),
                      Colors.blue,
                      Icons.person,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildAnalyticsCard(
                      'With IBAN Info',
                      teachersWithIBAN.toString(),
                      Colors.teal,
                      Icons.account_balance,
                    ),
                  ),
                ],
              ),
              

              
              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Total Students',
                      totalStudents.toString(),
                      Colors.indigo,
                      Icons.school,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Normal Lessons',
                      normalLessons.toString(),
                      Colors.green,
                      Icons.sports,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Activity Lessons',
                      activityLessons.toString(),
                      Colors.red,
                      Icons.warning,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Refresh button
              ElevatedButton(
                onPressed: _loadTeachersData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff1B1212),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Refresh Data'),
              ),
            ],
          ),
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