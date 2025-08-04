import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Reports/ReportsPage.dart';
import '../Reports/DetailReportPage.dart';

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
  bool _disposed = false; // Flag to track if widget is disposed
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadTeachersData();
  }

  @override
  void dispose() {
    _disposed = true; // Mark as disposed
    _tabController.dispose();
    super.dispose();
  }

  // Helper method to safely call setState
  void _safeSetState(VoidCallback fn) {
    if (mounted && !_disposed) {
      setState(fn);
    }
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
    if (!mounted || _disposed) return;
    
    _safeSetState(() {
      _isLoading = true;
    });
    
    try {
      final data = await getTeachersWithLessonData();
      _safeSetState(() {
        _allTeachersData = data;
        _isLoading = false;
      });
    } catch (e) {
      _safeSetState(() {
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
              _safeSetState(() {
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
                              child: profileImageUrl.isNotEmpty
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: profileImageUrl,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                        errorWidget: (context, url, error) => const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.person, color: Colors.white),
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

    Widget _buildPaymentRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('payment_requests')
          .where('status', isEqualTo: 'pending') // Only show pending requests
          .orderBy('requestedAt', descending: true)
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
            child: Text(
              'Error loading payment requests: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final paymentRequests = snapshot.data?.docs ?? [];

        if (paymentRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.payment,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Pending Payment Requests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'All payment requests have been processed',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: paymentRequests.length,
          itemBuilder: (context, index) {
            final request = paymentRequests[index].data() as Map<String, dynamic>;
            final requestId = paymentRequests[index].id;
            final teacherName = request['teacherName'] ?? 'Unknown Teacher';
            final teacherEmail = request['teacherEmail'] ?? '';
            final studentCount = request['studentCount'] ?? 0;
            final pricePerStudent = request['pricePerStudent'] ?? 150.0;
            final totalAmount = request['totalAmount'] ?? 0.0;
            final status = request['status'] ?? 'pending';
            final requestedAt = request['requestedAt'] as Timestamp?;
            final ibanInfo = request['ibanInfo'] as Map<String, dynamic>?;
            final notes = request['notes'] ?? '';

            // Get status color (for pending requests, always orange)
            Color statusColor = Colors.orange;
            String statusText = 'Pending';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with teacher info and status
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(0xff1B1212),
                          child: Text(
                            teacherName.isNotEmpty ? teacherName[0].toUpperCase() : 'T',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                teacherEmail,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Payment details
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Student Count:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xff1B1212),
                                ),
                              ),
                              Text(
                                '$studentCount',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff1B1212),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Price per Student:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xff1B1212),
                                ),
                              ),
                              Text(
                                '${pricePerStudent.toStringAsFixed(0)} TL',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff1B1212),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Amount:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff1B1212),
                                ),
                              ),
                              Text(
                                '${totalAmount.toStringAsFixed(0)} TL',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // IBAN Information
                    if (ibanInfo != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                                                         Row(
                               children: [
                                 Icon(Icons.account_balance, color: Color(0xff1B1212), size: 20),
                                 SizedBox(width: 8),
                                 Text(
                                   'IBAN Information',
                                   style: TextStyle(
                                     fontSize: 16,
                                     fontWeight: FontWeight.bold,
                                     color: Color(0xff1B1212),
                                   ),
                                 ),
                               ],
                             ),
                            const SizedBox(height: 12),
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
                      const SizedBox(height: 16),
                    ],
                    
                    // Request details
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Requested: ${requestedAt != null ? DateFormat('yyyy/MM/dd HH:mm').format(requestedAt.toDate()) : 'Unknown'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'ID: ${requestId.substring(0, 8)}...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    
                    // Action buttons for pending requests
                    if (status == 'pending') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.admin_panel_settings, color: Colors.blue[600], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Admin Actions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => _showApprovalDialog(requestId, teacherName, totalAmount),
                                    icon: const Icon(Icons.check_circle, size: 20),
                                    label: const Text(
                                      'Approve Payment',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => _showRejectionDialog(requestId, teacherName),
                                    icon: const Icon(Icons.cancel, size: 20),
                                    label: const Text(
                                      'Reject Request',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Click approve to process payment or reject if there are issues',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // Notes section
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.yellow[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.yellow[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.note, color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Admin Notes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              notes,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.orange,
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
        );
      },
    );
  }

  // Update payment request status with enhanced feedback
  Future<void> _updatePaymentRequestStatus(String requestId, String newStatus, {String? reason}) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Updating payment request...'),
              ],
            ),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Update the payment request
      final updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'processedBy': FirebaseAuth.instance.currentUser?.uid,
        'processedAt': FieldValue.serverTimestamp(),
      };
      
      // Add reason if provided
      if (reason != null && reason.isNotEmpty) {
        updateData['rejectionReason'] = reason;
      }
      
      await _firestore
          .collection('payment_requests')
          .doc(requestId)
          .update(updateData);

      // Show success message
      if (mounted) {
        String message;
        Color backgroundColor;
        IconData icon;

        switch (newStatus) {
          case 'approved':
            message = '✅ Payment request approved successfully!\nRequest removed from pending list.\nTeacher will be notified.';
            backgroundColor = Colors.green;
            icon = Icons.check_circle;
            break;
          case 'rejected':
            message = '❌ Payment request rejected.\nRequest removed from pending list.\nTeacher will be notified.';
            backgroundColor = Colors.red;
            icon = Icons.cancel;
            break;
          case 'paid':
            message = '💰 Payment marked as completed!\nRequest removed from pending list.\nMoney transferred to teacher.';
            backgroundColor = Colors.blue;
            icon = Icons.payment;
            break;
          default:
            message = 'Payment request updated successfully';
            backgroundColor = Colors.grey;
            icon = Icons.info;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: backgroundColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // Refresh the payment requests list
                setState(() {});
              },
            ),
          ),
        );
      }

      // Send notification to teacher (optional - you can implement push notifications here)
      _sendNotificationToTeacher(requestId, newStatus);
      
      // Reset teacher stats when payment is approved
      if (newStatus == 'approved') {
        await _resetTeacherStatsAfterApproval(requestId);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Error updating payment request: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Send notification to teacher (placeholder for push notifications)
  void _sendNotificationToTeacher(String requestId, String status) {
    // This is where you would implement push notifications
    // For now, we'll just log it
    print('Notification sent to teacher for request $requestId with status $status');
  }

  // Reset teacher stats after payment approval
  Future<void> _resetTeacherStatsAfterApproval(String requestId) async {
    try {
      // Get the payment request to find the teacher ID
      final requestDoc = await _firestore
          .collection('payment_requests')
          .doc(requestId)
          .get();
      
      if (!requestDoc.exists) {
        print('Payment request not found: $requestId');
        return;
      }
      
      final requestData = requestDoc.data()!;
      final teacherId = requestData['teacherId'] as String?;
      
      if (teacherId == null) {
        print('Teacher ID not found in payment request');
        return;
      }
      
      print('Resetting teacher stats for: $teacherId');
      
      // Reset user_settings
      await _firestore
          .collection('user_settings')
          .doc(teacherId)
          .update({
        'currentStudentCount': 0,
        'currentTotalAmount': 0.0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      // Reset teacher_stats
      await _firestore
          .collection('teacher_stats')
          .doc(teacherId)
          .update({
        'studentCount': 0,
        'totalAmount': 0.0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      print('✅ Teacher stats reset successfully after payment approval');
      
    } catch (e) {
      print('❌ Error resetting teacher stats: $e');
    }
  }

  // Show approval confirmation dialog
  void _showApprovalDialog(String requestId, String teacherName, double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 28),
            const SizedBox(width: 12),
            Text(
              'Approve Payment',
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to approve this payment request?',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teacher: $teacherName',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Amount: ${amount.toStringAsFixed(0)} TL',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will mark the payment as approved and notify the teacher.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _updatePaymentRequestStatus(requestId, 'approved');
            },
            child: const Text('Approve Payment'),
          ),
        ],
      ),
    );
  }

  // Show rejection confirmation dialog
  void _showRejectionDialog(String requestId, String teacherName) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red[600], size: 28),
            const SizedBox(width: 12),
            Text(
              'Reject Request',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject this payment request?',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                'Teacher: $teacherName',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reason for rejection (optional):',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for rejection...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red[400]!),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _updatePaymentRequestStatus(requestId, 'rejected', reason: reasonController.text.trim());
            },
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );
  }

  Widget _buildReports() {
    return ReportsPage();
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
                  icon: Icon(Icons.payment),
                  text: 'Payment Requests',
                ),
                Tab(
                  icon: Icon(Icons.assignment),
                  text: 'Reports',
                ),
                Tab(
                  icon: Icon(Icons.details),
                  text: 'Detail Report',
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
                _buildPaymentRequests(),
                _buildReports(),
                DetailReportPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 