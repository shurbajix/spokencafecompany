import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      if (mounted) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      }

      print('🔄 Fetching students info with billing data...');

      // Get all users (not just students) to show billing info for everyone
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      print('📊 Found ${usersSnapshot.docs.length} total users');

      // Debug: Also check all users to see if billing data might be for non-students
      final allUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      print('👥 Found ${allUsersSnapshot.docs.length} total users');
      for (var doc in allUsersSnapshot.docs) {
        final data = doc.data();
        print('👥 User: ${doc.id} - role=${data['role']} - name=${data['name']}');
      }

      // Get all billing information from billing_info collection
      final billingInfoSnapshot = await FirebaseFirestore.instance
          .collection('billing_info')
          .get();

      print('💳 Found ${billingInfoSnapshot.docs.length} billing records');
      
      // Debug: Check if billing_info collection exists and has data
      if (billingInfoSnapshot.docs.isEmpty) {
        print('⚠️ WARNING: billing_info collection is EMPTY!');
        print('⚠️ This means no billing data has been saved yet.');
        print('⚠️ Check if PaymentFormView.dart is saving to the correct collection.');
      }

      // Debug: Show all billing data
      for (int i = 0; i < billingInfoSnapshot.docs.length; i++) {
        final billingData = billingInfoSnapshot.docs[i].data();
        print('💳 Billing $i: userId=${billingData['userId']}, billingName=${billingData['billingFullName']}, billingEmail=${billingData['billingEmail']}');
        print('💳 Full billing data: $billingData');
      }

      // Create a map of userId to user data (all users, not just students)
      final Map<String, Map<String, dynamic>> allUserData = {};
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        allUserData[doc.id] = {
          'userId': doc.id,
          'name': data['name'] ?? 'Unknown',
          'surname': data['surname'] ?? '',
          'email': data['email'] ?? 'No email',
          'phoneNumber': data['phoneNumber'] ?? 'No phone',
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'role': data['role'] ?? 'unknown',
          'createdAt': data['createdAt'],
        };
        print('👤 User: ${doc.id} - ${data['name']} ${data['surname']} (role: ${data['role']})');
      }

      // Debug: Show all user IDs
      print('👥 All user IDs: ${allUserData.keys.toList()}');

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
      
      for (var billingDoc in billingInfoSnapshot.docs) {
        final billingData = billingDoc.data();
        final userId = billingData['userId'];
        
        print('🔍 Processing billing for userId: $userId');
        print('🔍 Billing data: billingFullName=${billingData['billingFullName']}, billingEmail=${billingData['billingEmail']}, billingIdNumber=${billingData['billingIdNumber']}');
        print('🔍 Billing data keys: ${billingData.keys.toList()}');
        print('🔍 Full billing document: $billingData');
        
        // Debug: Check if this userId exists in our users list
        if (allUsers.containsKey(userId)) {
          final userData = allUsers[userId]!;
          print('✅ User found: ${userData['name']} ${userData['surname']} (${userData['email']})');
        } else {
          print('❌ User NOT found in users collection: $userId');
        }
        
        // Check if this billing record has billing information
        if (userId != null && 
            allUsers.containsKey(userId) &&
            (billingData['billingFullName'] != null || 
             billingData['billingEmail'] != null)) {
          
          print('✅ Found billing info for user: $userId');
          
          if (!studentBillingData.containsKey(userId)) {
            studentBillingData[userId] = [];
          }
          
          studentBillingData[userId]!.add({
            'billingId': billingDoc.id,
            'billingFullName': billingData['billingFullName'] ?? '',
            'billingEmail': billingData['billingEmail'] ?? '',
            'billingIdNumber': billingData['billingIdNumber'] ?? '', // Original ID number
            'billingIdNumberHash': billingData['billingIdNumberHash'] ?? '', // Keep hash for reference
            'orderId': billingData['orderId'] ?? '',
            'amount': billingData['amount'] ?? 0.0,
            'paymentDate': billingData['paymentDate'],
            'createdAt': billingData['createdAt'],
          });
        } else {
          print('❌ No billing info or user not found for userId: $userId');
          print('❌ userId != null: ${userId != null}');
          print('❌ allUsers.containsKey(userId): ${allUsers.containsKey(userId)}');
          print('❌ has billingFullName: ${billingData['billingFullName'] != null}');
          print('❌ has billingEmail: ${billingData['billingEmail'] != null}');
          print('❌ billingFullName value: "${billingData['billingFullName']}"');
          print('❌ billingEmail value: "${billingData['billingEmail']}"');
        }
      }

      print('💰 Users with billing data: ${studentBillingData.keys.length}');
      for (var userId in studentBillingData.keys) {
        print('💰 User $userId has ${studentBillingData[userId]!.length} billing entries');
      }

      // Add all users, but prioritize those with billing information
      for (var userId in allUserData.keys) {
        final userData = allUserData[userId]!;
        final billingInfo = studentBillingData[userId] ?? [];
        
        combinedData.add({
          ...userData,
          'billingInfo': billingInfo,
          'hasBillingInfo': billingInfo.isNotEmpty,
        });
        
        print('📋 Added user: ${userData['name']} (role: ${userData['role']}) - hasBillingInfo: ${billingInfo.isNotEmpty}');
      }

      // Sort: students with billing info first, then by name
      combinedData.sort((a, b) {
        if (a['hasBillingInfo'] && !b['hasBillingInfo']) return -1;
        if (!a['hasBillingInfo'] && b['hasBillingInfo']) return 1;
        
        final nameA = '${a['name']} ${a['surname']}'.trim();
        final nameB = '${b['name']} ${b['surname']}'.trim();
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          studentsInfo = combinedData;
          isLoading = false;
        });
      }

      print('✅ Successfully fetched ${studentsInfo.length} users');
      print('💰 Users with billing info: ${combinedData.where((s) => s['hasBillingInfo']).length}');

    } catch (e) {
      print('❌ Error fetching students info: $e');
      print('❌ Error details: ${e.toString()}');
      if (mounted) {
        setState(() {
          errorMessage = 'Error loading students information: $e';
          isLoading = false;
        });
      }
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
          '👥 USER INFO - BILLING RECORDS',
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
            onPressed: () {
              print('🔄 Manual refresh triggered');
              _fetchStudentsInfo();
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: () async {
              print('🔍 DEBUG: Comprehensive billing_info collection check...');
              try {
                final billingSnapshot = await FirebaseFirestore.instance
                    .collection('billing_info')
                    .get();
                
                print('🔍 DEBUG: Found ${billingSnapshot.docs.length} billing records');
                
                if (billingSnapshot.docs.isEmpty) {
                  print('🔍 DEBUG: No billing records found!');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No billing records found in Firebase'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                
                // Show detailed info for each billing record
                for (int i = 0; i < billingSnapshot.docs.length; i++) {
                  final data = billingSnapshot.docs[i].data();
                  print('🔍 DEBUG: Billing Record $i:');
                  print('  - Document ID: ${billingSnapshot.docs[i].id}');
                  print('  - userId: ${data['userId']}');
                  print('  - billingFullName: ${data['billingFullName']}');
                  print('  - billingEmail: ${data['billingEmail']}');
                  print('  - billingIdNumber: ${data['billingIdNumber']}');
                  print('  - billingIdNumberHash: ${data['billingIdNumberHash']}');
                  print('  - orderId: ${data['orderId']}');
                  print('  - amount: ${data['amount']}');
                  print('  - paymentDate: ${data['paymentDate']}');
                  print('  - createdAt: ${data['createdAt']}');
                  print('  - Full data: $data');
                  print('  ---');
                }
                
                // Also check if users exist for these billing records
                print('🔍 DEBUG: Checking if users exist for billing records...');
                for (var doc in billingSnapshot.docs) {
                  final data = doc.data();
                  final userId = data['userId'];
                  if (userId != null) {
                    try {
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .get();
                      
                      if (userDoc.exists) {
                        final userData = userDoc.data();
                        print('✅ User exists: ${userData?['name']} ${userData?['surname']} (${userData?['email']})');
                      } else {
                        print('❌ User NOT found: $userId');
                      }
                    } catch (e) {
                      print('❌ Error checking user $userId: $e');
                    }
                  }
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Found ${billingSnapshot.docs.length} billing records - check console for details'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              } catch (e) {
                print('🔍 DEBUG: Error checking billing_info: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            tooltip: 'Debug Billing Info',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              print('🧪 Adding test billing record with original ID number...');
              try {
                final testBillingData = {
                  'userId': 'test_user_${DateTime.now().millisecondsSinceEpoch}',
                  'billingFullName': 'Test User Full Name',
                  'billingEmail': 'test@example.com',
                  'billingIdNumber': '99087867868788', // Original ID number (this should display)
                  'billingIdNumberHash': 'ff07139c28704ee6812922e2ebc2dd055ab3907c21bf42181595d28e7c151f7d', // Hashed version
                  'orderId': 'test_order_${DateTime.now().millisecondsSinceEpoch}',
                  'amount': 190.00,
                  'paymentDate': FieldValue.serverTimestamp(),
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                
                final docRef = await FirebaseFirestore.instance
                    .collection('billing_info')
                    .add(testBillingData);
                
                print('✅ Test billing record added with ID: ${docRef.id}');
                print('✅ Original ID: 99087867868788');
                print('✅ Hashed ID: ff07139c28704ee6812922e2ebc2dd055ab3907c21bf42181595d28e7c151f7d');
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Test billing record added! Refresh to see it.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
                
                // Refresh the data
                _fetchStudentsInfo();
                
              } catch (e) {
                print('❌ Error adding test billing record: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            tooltip: 'Add Test Billing Record',
          ),
          IconButton(
            icon: const Icon(Icons.build, color: Colors.white),
            onPressed: () async {
              print('🔧 Fixing old billing records...');
              try {
                final billingSnapshot = await FirebaseFirestore.instance
                    .collection('billing_info')
                    .get();
                
                int fixedCount = 0;
                for (var doc in billingSnapshot.docs) {
                  final data = doc.data();
                  final currentIdNumber = data['billingIdNumber']?.toString() ?? '';
                  
                  // Check if this is an old record with hash in billingIdNumber
                  if (currentIdNumber.length > 20 && RegExp(r'^[a-f0-9]+$').hasMatch(currentIdNumber)) {
                    print('🔧 Fixing record ${doc.id}: $currentIdNumber');
                    
                    // For demo purposes, replace with a sample ID number
                    // In real app, you'd need to get the original ID from somewhere
                    await doc.reference.update({
                      'billingIdNumber': '99087867868788', // Replace with actual original ID
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    
                    fixedCount++;
                  }
                }
                
                print('✅ Fixed $fixedCount billing records');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Fixed $fixedCount billing records!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
                
                // Refresh the data
                _fetchStudentsInfo();
                
              } catch (e) {
                print('❌ Error fixing billing records: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            tooltip: 'Fix Old Billing Records',
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
                hintText: 'Search by user name, email, phone, or billing information...',
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
                  'Total Users', 
                  studentsInfo.length.toString(),
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatChip(
                  'With Billing Records', 
                  studentsInfo.where((s) => s['hasBillingInfo']).length.toString(),
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _buildStatChip(
                  'No Billing Records', 
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
                        Text('Loading users and billing information...'),
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
                                      ? 'No users found'
                                      : 'No users found matching your search',
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
                  child: student['profileImageUrl']?.isNotEmpty == true
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: student['profileImageUrl']!,
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
                      : const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 30,
                        ),
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
                        'Role: ${student['role'] ?? 'Unknown'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
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
                    hasBilling ? 'Has Billing Records' : 'No Billing Records',
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
              
              // Single billing information container
              _buildCombinedBillingInfoCard(billingInfo),
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
                        'This user has no billing records yet',
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

  Widget _buildCombinedBillingInfoCard(List<Map<String, dynamic>> billingInfo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with count
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${billingInfo.length} Record${billingInfo.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Show billing information from the most recent record
          if (billingInfo.isNotEmpty)
            Builder(
              builder: (context) {
                final latestBilling = billingInfo.first;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Billing details
                    if (latestBilling['billingFullName']?.isNotEmpty == true)
                      _buildBillingField(
                        'Full Name',
                        latestBilling['billingFullName'],
                        Icons.person_outline,
                      ),
                    
                    if (latestBilling['billingEmail']?.isNotEmpty == true)
                      _buildBillingField(
                        'Email',
                        latestBilling['billingEmail'],
                        Icons.email_outlined,
                      ),
                    
                    // Show ID Number (check if it's a hash or original number)
                    Builder(
                      builder: (context) {
                        // Convert to string and trim any whitespace
                        final idNumber = (latestBilling['billingIdNumber'] ?? '').toString().trim();
                        if (idNumber.isNotEmpty) {
                          // Check if it looks like a hash (long string with hex characters)
                          final isHash = idNumber.length > 20 && RegExp(r'^[a-f0-9]+$').hasMatch(idNumber);
                          
                          if (isHash) {
                            return _buildBillingField(
                              'ID Number (Hash Detected)',
                              'Old data format - need new payment',
                              Icons.warning,
                              isSecure: true,
                            );
                          } else {
                            return _buildBillingField(
                              'ID Number',
                              idNumber,
                              Icons.badge,
                              isSecure: false,
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    
                    // Show hashed version for comparison
                    if (latestBilling['billingIdNumberHash']?.isNotEmpty == true)
                      _buildBillingField(
                        'ID Number (Hashed)',
                        latestBilling['billingIdNumberHash'],
                        Icons.security,
                        isSecure: true,
                      ),
                    
                    // Debug: Show raw data info
                    Builder(
                      builder: (context) {
                        final rawIdNumber = latestBilling['billingIdNumber'];
                        final rawType = rawIdNumber.runtimeType.toString();
                        final rawValue = rawIdNumber.toString();
                        
                        return _buildBillingField(
                          'Debug - Raw Data',
                          'Type: $rawType, Value: "$rawValue"',
                          Icons.bug_report,
                          isSecure: true,
                        );
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    const Divider(color: Colors.green),
                    const SizedBox(height: 8),
                    
                    // Payment summary
                    Row(
                      children: [
                        const Icon(Icons.payment, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Payment Summary:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₺${latestBilling['amount']?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Order ID
                    if (latestBilling['orderId']?.isNotEmpty == true)
                      _buildBillingField(
                        'Order ID',
                        latestBilling['orderId'],
                        Icons.receipt_long,
                      ),
                    
                    // Payment date
                    if (latestBilling['paymentDate'] != null)
                      _buildBillingField(
                        'Payment Date',
                        _formatDate(latestBilling['paymentDate']),
                        Icons.calendar_today,
                      ),
                    
                    // If there are multiple records, show a note
                    if (billingInfo.length > 1) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This user has ${billingInfo.length} billing records. Showing the most recent one.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
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