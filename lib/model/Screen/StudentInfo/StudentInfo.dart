import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentInfo extends StatefulWidget {
  const StudentInfo({super.key});

  @override
  State<StudentInfo> createState() => _StudentInfoState();
}

class _StudentInfoState extends State<StudentInfo> {
  List<Map<String, dynamic>> studentsInfo = [];
  bool isLoading = true;
  String? errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    print('🚀 StudentInfo: Page initialized - THIS IS STUDENT INFO PAGE!');
    print('🎯 StudentInfo: Loading students with billing information');
    _fetchStudentsInfo();
  }

  Future<void> _fetchStudentsInfo() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      print('🔄 Fetching students info with billing data...');

      // Get all users with student role
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      print('📊 Found ${usersSnapshot.docs.length} students');

      // Debug: Also check all users to see if billing data might be for non-students
      final allUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      print('👥 Found ${allUsersSnapshot.docs.length} total users');
      for (var doc in allUsersSnapshot.docs) {
        final data = doc.data();
        print('👥 User: ${doc.id} - role=${data['role']} - name=${data['name']}');
      }

      // Get all saved cards with billing information
      final savedCardsSnapshot = await FirebaseFirestore.instance
          .collection('saved_cards')
          .get();

      print('💳 Found ${savedCardsSnapshot.docs.length} saved cards with potential billing info');

      // Debug: Show all saved cards data
      for (int i = 0; i < savedCardsSnapshot.docs.length; i++) {
        final cardData = savedCardsSnapshot.docs[i].data();
        print('💳 Card $i: userId=${cardData['userId']}, billingName=${cardData['billingFullName']}, billingEmail=${cardData['billingEmail']}');
        print('💳 Full card data: $cardData');
      }

      // Create a map of userId to student data
      final Map<String, Map<String, dynamic>> studentUsers = {};
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        studentUsers[doc.id] = {
          'userId': doc.id,
          'name': data['name'] ?? 'Unknown',
          'surname': data['surname'] ?? '',
          'email': data['email'] ?? 'No email',
          'phoneNumber': data['phoneNumber'] ?? 'No phone',
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'createdAt': data['createdAt'],
        };
        print('👤 Student: ${doc.id} - ${data['name']} ${data['surname']}');
      }

      // Debug: Show all student IDs
      print('👥 All student IDs: ${studentUsers.keys.toList()}');

      // Create a map of ALL users for billing matching (including non-students)
      final Map<String, Map<String, dynamic>> allUsers = {};
      for (var doc in allUsersSnapshot.docs) {
        final data = doc.data();
        allUsers[doc.id] = {
          'userId': doc.id,
          'name': data['name'] ?? 'Unknown',
          'surname': data['surname'] ?? '',
          'email': data['email'] ?? 'No email',
          'phoneNumber': data['phoneNumber'] ?? 'No phone',
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'role': data['role'] ?? 'unknown',
          'createdAt': data['createdAt'],
        };
      }

      // Combine students with their billing information from saved cards
      final List<Map<String, dynamic>> combinedData = [];
      
      // Create a map to track which students have billing info
      final Map<String, List<Map<String, dynamic>>> studentBillingData = {};
      
      for (var cardDoc in savedCardsSnapshot.docs) {
        final cardData = cardDoc.data();
        final userId = cardData['userId'];
        
        print('🔍 Processing card for userId: $userId');
        print('🔍 Card data: billingFullName=${cardData['billingFullName']}, billingEmail=${cardData['billingEmail']}');
        
        // Check if this card has billing information
        if (userId != null && 
            allUsers.containsKey(userId) &&
            (cardData['billingFullName'] != null || 
             cardData['billingEmail'] != null)) {
          
          print('✅ Found billing info for user: $userId');
          
          if (!studentBillingData.containsKey(userId)) {
            studentBillingData[userId] = [];
          }
          
          studentBillingData[userId]!.add({
            'cardId': cardDoc.id,
            'billingFullName': cardData['billingFullName'] ?? '',
            'billingEmail': cardData['billingEmail'] ?? '',
            'billingIdNumberHash': cardData['billingIdNumberHash'] ?? '',
            'maskedNumber': cardData['maskedNumber'] ?? 'Card ****',
            'cardType': cardData['cardType'] ?? 'Unknown',
            'createdAt': cardData['createdAt'],
          });
        } else {
          print('❌ No billing info or user not found for userId: $userId');
          print('❌ userId != null: ${userId != null}');
          print('❌ allUsers.containsKey(userId): ${allUsers.containsKey(userId)}');
          print('❌ has billingFullName: ${cardData['billingFullName'] != null}');
          print('❌ has billingEmail: ${cardData['billingEmail'] != null}');
        }
      }

      print('💰 Students with billing data: ${studentBillingData.keys.length}');
      for (var userId in studentBillingData.keys) {
        print('💰 Student $userId has ${studentBillingData[userId]!.length} billing entries');
      }

      // Add all students, but prioritize those with billing information
      for (var userId in studentUsers.keys) {
        final studentData = studentUsers[userId]!;
        final billingInfo = studentBillingData[userId] ?? [];
        
        combinedData.add({
          ...studentData,
          'billingInfo': billingInfo,
          'hasBillingInfo': billingInfo.isNotEmpty,
        });
        
        print('📋 Added student: ${studentData['name']} - hasBillingInfo: ${billingInfo.isNotEmpty}');
      }

      // Also add non-students who have billing info (for debugging)
      for (var userId in allUsers.keys) {
        if (!studentUsers.containsKey(userId) && studentBillingData.containsKey(userId)) {
          final userData = allUsers[userId]!;
          final billingInfo = studentBillingData[userId]!;
          
          combinedData.add({
            ...userData,
            'billingInfo': billingInfo,
            'hasBillingInfo': true,
            'isNonStudent': true, // Flag to identify non-students
          });
          
          print('📋 Added non-student with billing: ${userData['name']} (role: ${userData['role']}) - hasBillingInfo: true');
        }
      }

      // Sort: students with billing info first, then by name
      combinedData.sort((a, b) {
        if (a['hasBillingInfo'] && !b['hasBillingInfo']) return -1;
        if (!a['hasBillingInfo'] && b['hasBillingInfo']) return 1;
        
        final nameA = '${a['name']} ${a['surname']}'.trim();
        final nameB = '${b['name']} ${b['surname']}'.trim();
        return nameA.compareTo(nameB);
      });

      setState(() {
        studentsInfo = combinedData;
        isLoading = false;
      });

      print('✅ Successfully fetched ${studentsInfo.length} students');
      print('💰 Students with billing info: ${combinedData.where((s) => s['hasBillingInfo']).length}');

    } catch (e) {
      print('❌ Error fetching students info: $e');
      print('❌ Error details: ${e.toString()}');
      setState(() {
        errorMessage = 'Error loading students information: $e';
        isLoading = false;
      });
    }
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

  // Filter students based on search query
  List<Map<String, dynamic>> _getFilteredStudents() {
    if (_searchQuery.isEmpty) {
      return studentsInfo;
    }
    
    return studentsInfo.where((student) {
      final name = '${student['name']} ${student['surname']}'.toLowerCase();
      final email = student['email']?.toString().toLowerCase() ?? '';
      final phone = student['phoneNumber']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      
      // Also search in billing information
      bool billingMatch = false;
      final billingInfo = student['billingInfo'] as List<Map<String, dynamic>>;
      for (var billing in billingInfo) {
        final billingName = billing['billingFullName']?.toString().toLowerCase() ?? '';
        final billingEmail = billing['billingEmail']?.toString().toLowerCase() ?? '';
        if (billingName.contains(query) || billingEmail.contains(query)) {
          billingMatch = true;
          break;
        }
      }
      
      return name.contains(query) ||
             email.contains(query) ||
             phone.contains(query) ||
             billingMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '👥 STUDENT INFO - BILLING INFORMATION',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xff1B1212),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchStudentsInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by student name, email, phone, or billing information...',
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
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Statistics Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                _buildStatChip(
                  'Total Students', 
                  studentsInfo.length.toString(),
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatChip(
                  'With Billing Info', 
                  studentsInfo.where((s) => s['hasBillingInfo']).length.toString(),
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _buildStatChip(
                  'Without Billing', 
                  studentsInfo.where((s) => !s['hasBillingInfo']).length.toString(),
                  Colors.orange,
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xff1B1212)),
                        SizedBox(height: 16),
                        Text('Loading students and billing information...'),
                      ],
                    ),
                  )
                : errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchStudentsInfo,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff1B1212),
                              ),
                              child: const Text('Retry', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : _getFilteredStudents().isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.info, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty 
                                      ? 'No students found'
                                      : 'No students found matching your search',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchStudentsInfo,
                            color: const Color(0xff1B1212),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _getFilteredStudents().length,
                              itemBuilder: (context, index) {
                                final student = _getFilteredStudents()[index];
                                return _buildStudentCard(student);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final billingInfo = student['billingInfo'] as List<Map<String, dynamic>>;
    final hasBilling = student['hasBillingInfo'] as bool;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with student info
            Row(
              children: [
                // Student profile picture
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xff1B1212),
                  backgroundImage: student['profileImageUrl']?.isNotEmpty == true
                      ? NetworkImage(student['profileImageUrl'])
                      : null,
                  child: student['profileImageUrl']?.isEmpty != false
                      ? const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 30,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${student['name']} ${student['surname']}'.trim(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        student['email'] ?? 'No email',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (student['phoneNumber']?.isNotEmpty == true)
                        Text(
                          student['phoneNumber'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasBilling ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasBilling ? 'Has Billing' : 'No Billing',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            // Billing information section
            if (hasBilling) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: Color(0xff1B1212), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Billing Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1B1212),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${billingInfo.length} Payment${billingInfo.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Show billing entries
              ...billingInfo.map((billing) => _buildBillingInfoCard(billing)).toList(),
            ] else ...[
              const SizedBox(height: 16),
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
                        'This student has not provided billing information yet',
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
  }

  Widget _buildBillingInfoCard(Map<String, dynamic> billing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card info header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  billing['cardType'] ?? 'Card',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                billing['maskedNumber'] ?? 'Card ****',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (billing['createdAt'] != null)
                Text(
                  _formatDate(billing['createdAt']),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Billing details
          if (billing['billingFullName']?.isNotEmpty == true)
            _buildBillingField(
              'Full Name',
              billing['billingFullName'],
              Icons.person_outline,
            ),
          
          if (billing['billingEmail']?.isNotEmpty == true)
            _buildBillingField(
              'Email',
              billing['billingEmail'],
              Icons.email_outlined,
            ),
          
          if (billing['billingIdNumberHash']?.isNotEmpty == true)
            _buildBillingField(
              'ID Number',
              '***-***-***-** (Encrypted)',
              Icons.security,
              isSecure: true,
            ),
        ],
      ),
    );
  }

  Widget _buildBillingField(String label, String value, IconData icon, {bool isSecure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
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
              onTap: isSecure ? null : () => _copyToClipboard(value, label),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSecure ? Colors.grey[600] : Colors.black87,
                      ),
                    ),
                  ),
                  if (!isSecure) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.copy,
                      size: 14,
                      color: Colors.green[600],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Unknown';
      }
      
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
} 