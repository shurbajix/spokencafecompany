import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherInfo extends StatefulWidget {
  const TeacherInfo({super.key});

  @override
  State<TeacherInfo> createState() => _TeacherInfoState();
}

class _TeacherInfoState extends State<TeacherInfo> {
  List<Map<String, dynamic>> teachersInfo = [];
  bool isLoading = true;
  String? errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    print('🚀 TeacherInfo: Page initialized - THIS IS TEACHER INFO PAGE!');
    print('🎯 TeacherInfo: If you see this, TeacherInfo is working correctly');
    _fetchTeachersInfo();
  }

  Future<void> _fetchTeachersInfo() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      print('🔄 Fetching teachers info from user_settings collection...');
      print('📡 Connected to Firebase project: spoken-cafe-456813-b3e6d');

      // Get all user settings
      final settingsSnapshot = await FirebaseFirestore.instance
          .collection('user_settings')
          .get();

      // Get all users with teacher role
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();

      // Create a map of userId to teacher data (focus on essential info only)
      final Map<String, Map<String, dynamic>> teacherUsers = {};
      for (var doc in usersSnapshot.docs) {
        teacherUsers[doc.id] = {
          'name': doc.data()['name'] ?? 'Unknown',
          'email': doc.data()['email'] ?? 'No email',
          'isApproved': doc.data()['isApproved'] ?? false,
        };
      }

      // Combine settings with teacher user data
      final List<Map<String, dynamic>> combinedData = [];
      
      for (var settingDoc in settingsSnapshot.docs) {
        final settingData = settingDoc.data();
        final userId = settingDoc.id;
        
        // Check if this user is a teacher
        if (teacherUsers.containsKey(userId)) {
          final teacherData = teacherUsers[userId]!;
          
          combinedData.add({
            'userId': userId,
            'teacherName': teacherData['name'],
            'teacherEmail': teacherData['email'],
            'isApproved': teacherData['isApproved'],
            'iban': settingData['iban'] ?? '',
            'holderName': settingData['holderName'] ?? '',
            'phoneNumber': settingData['phoneNumber'] ?? '',
            'createdAt': settingData['createdAt'],
            'updatedAt': settingData['updatedAt'],
          });
        }
      }

      setState(() {
        teachersInfo = combinedData;
        isLoading = false;
      });

      print('✅ Successfully fetched ${teachersInfo.length} teachers with settings info');

    } catch (e) {
      print('❌ Error fetching teachers info: $e');
      setState(() {
        errorMessage = 'Error loading teachers information: $e';
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

  // Filter teachers based on search query
  List<Map<String, dynamic>> _getFilteredTeachers() {
    if (_searchQuery.isEmpty) {
      return teachersInfo;
    }
    
    return teachersInfo.where((teacher) {
      final name = teacher['teacherName']?.toString().toLowerCase() ?? '';
      final email = teacher['teacherEmail']?.toString().toLowerCase() ?? '';
      final holderName = teacher['holderName']?.toString().toLowerCase() ?? '';
      final phone = teacher['phoneNumber']?.toString().toLowerCase() ?? '';
      final iban = teacher['iban']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      
      return name.contains(query) ||
             email.contains(query) ||
             holderName.contains(query) ||
             phone.contains(query) ||
             iban.contains(query);
    }).toList();
  }

  // TODO: Add PDF download functionality later
  Future<void> _downloadTeacherPDF(Map<String, dynamic> teacher) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF download feature coming soon!'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 TeacherInfo: Building UI with ${teachersInfo.length} teachers');
    print('📺 TeacherInfo: THIS IS THE TEACHER INFO PAGE BEING DISPLAYED');
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '🏦 TEACHER INFO PAGE - IBAN INFORMATION',
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
            onPressed: _fetchTeachersInfo,
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
                hintText: 'Search by teacher name, email, phone, or IBAN number...',
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
          
          // Content
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xff1B1212)),
                        SizedBox(height: 16),
                        Text('Loading teachers IBAN information...'),
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
                              onPressed: _fetchTeachersInfo,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff1B1212),
                              ),
                              child: const Text('Retry', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : _getFilteredTeachers().isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.info, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty 
                                      ? 'No teachers with IBAN information found'
                                      : 'No teachers found matching your search',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchTeachersInfo,
                            color: const Color(0xff1B1212),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _getFilteredTeachers().length,
                              itemBuilder: (context, index) {
                                final teacher = _getFilteredTeachers()[index];
                                return _buildTeacherCard(teacher);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
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
            // Header with teacher name and status (no profile image)
            Row(
              children: [
                // Simple icon instead of profile image
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xff1B1212),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher['teacherName'] ?? 'Unknown Teacher',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        teacher['teacherEmail'] ?? 'No email',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: teacher['isApproved'] ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    teacher['isApproved'] ? 'Approved' : 'Pending',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  onPressed: () => _downloadTeacherPDF(teacher),
                  tooltip: 'Download PDF',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Information fields
            _buildInfoField(
              'Account Holder Name',
              teacher['holderName'] ?? 'Not provided',
              Icons.person_outline,
            ),
            
            _buildInfoField(
              'Phone Number',
              teacher['phoneNumber'] ?? 'Not provided',
              Icons.phone_outlined,
            ),
            
            _buildInfoField(
              'IBAN Number',
              teacher['iban'] ?? 'Not provided',
              Icons.account_balance_outlined,
              isIBAN: true,
            ),
            
            // Timestamps
            if (teacher['updatedAt'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Last updated: ${_formatTimestamp(teacher['updatedAt'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoField(String label, String value, IconData icon, {bool isIBAN = false}) {
    final displayValue = value.isEmpty ? 'Not provided' : value;
    final isValueEmpty = value.isEmpty;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xff1B1212)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isIBAN && !isValueEmpty ? 'TR$displayValue' : displayValue,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isValueEmpty ? Colors.grey : Colors.black87,
                    fontFamily: isIBAN ? 'monospace' : null,
                  ),
                ),
              ],
            ),
          ),
          if (!isValueEmpty)
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => _copyToClipboard(
                isIBAN ? 'TR$value' : value,
                label,
              ),
              tooltip: 'Copy $label',
              color: const Color(0xff1B1212),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else {
        dateTime = DateTime.parse(timestamp.toString());
      }
      
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }
} 