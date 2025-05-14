
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

class Teacher {
  final String name;
  final String email;
  final String phoneNumber;
  final String docId;
  final String? profileImageUrl; // Added profileImageUrl

  Teacher({
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.docId,
    this.profileImageUrl, // Nullable field
  });

  factory Teacher.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?; // Safely cast to Map or null
    return Teacher(
      name: data?['name']?.toString() ?? 'No name',
      email: data?['email']?.toString() ?? 'No email',
      phoneNumber: data?['phoneNumber']?.toString() ?? 'No phone number',
      docId: doc.id,
      profileImageUrl: data?['profileImageUrl']?.toString(), // Parse profileImageUrl
    );
  }
}

class Teachers extends StatefulWidget {
  const Teachers({super.key});

  @override
  State<Teachers> createState() => _TeachersState();
}

class _TeachersState extends State<Teachers> {
  final ScrollController _scrollController = ScrollController();
  bool _showPostsPage = false;
  bool _showGalleryPage = false;
  List<Teacher> teachers = [];
  bool isLoading = true;
  String? errorMessage;
  late CollectionReference _usersCollection;
  bool _hasFetched = false;
  String? _selectedTeacherDocId;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  void _initializeFirebase() {
    _usersCollection = FirebaseFirestore.instance.collection('users');
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    if (_hasFetched) return;
    _hasFetched = true;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Authentication required. Please sign in.');

      await user.getIdToken();

      QuerySnapshot snapshot = await _usersCollection
          .where('role', isEqualTo: 'teacher')
          .get()
          .timeout(const Duration(seconds: 15));

      List<Teacher> fetchedTeachers = snapshot.docs.map((doc) => Teacher.fromFirestore(doc)).toList();

      setState(() {
        teachers = fetchedTeachers;
        isLoading = false;
      });
    } on FirebaseException catch (e) {
      setState(() {
        errorMessage = _handleFirebaseError(e);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  String _handleFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You don\'t have permission to access this data.';
      case 'unavailable':
        return 'Network error. Please check your connection.';
      default:
        return 'Firestore error: ${e.message}';
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        print("File picked: ${file.name}");
      }
    } catch (e) {
      print("Error picking file: $e");
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: Drawer(
        width: 700,
        child: _showPostsPage
            ? _buildPostsPage()
            : _showGalleryPage
                ? _buildGalleryPage()
                : _buildOriginalDrawerContent(),
      ),
      body: ListView(
        shrinkWrap: true,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    children: [
                      Text('Underlines', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    children: [
                      Text('Underlines', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  spreadRadius: 2,
                ),
              ],
            ),
            height: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    "Teachers List",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(errorMessage!),
                                  ElevatedButton(
                                    onPressed: () {
                                      _hasFetched = false;
                                      _fetchTeachers();
                                    },
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : teachers.isEmpty
                              ? const Center(child: Text('No teachers found'))
                              : RefreshIndicator(
                                  onRefresh: () async {
                                    _hasFetched = false;
                                    await _fetchTeachers();
                                  },
                                  child: Scrollbar(
                                    controller: _scrollController,
                                    thickness: 8,
                                    radius: const Radius.circular(10),
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      itemCount: teachers.length,
                                      itemBuilder: (context, index) {
                                        return ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(horizontal: 20),
                                          trailing: SizedBox(
                                            width: 279,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Expanded(
                                                  child: TextButton(
                                                    onPressed: () {},
                                                    child: const Text(
                                                      'Accept',
                                                      style: TextStyle(
                                                        color: Colors.green,
                                                        fontSize: 20,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: TextButton(
                                                    onPressed: () {
                                                      showDialog(
                                                        context: context,
                                                        builder: (context) {
                                                          return AlertDialog(
                                                            backgroundColor: Colors.white,
                                                            title: const Text('Write the Reason not Accept'),
                                                            content: TextFormField(
                                                              decoration: InputDecoration(
                                                                border: OutlineInputBorder(
                                                                  borderRadius: BorderRadius.circular(10),
                                                                ),
                                                                hintText: 'Enter reason',
                                                              ),
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () {
                                                                  Navigator.pop(context);
                                                                },
                                                                child: const Text(
                                                                  'Cancel',
                                                                  style: TextStyle(color: Colors.red, fontSize: 20),
                                                                ),
                                                              ),
                                                              TextButton(
                                                                onPressed: () {},
                                                                child: const Text(
                                                                  'Accept',
                                                                  style: TextStyle(color: Colors.green, fontSize: 20),
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                    },
                                                    child: const Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 20,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: TextButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _selectedTeacherDocId = teachers[index].docId;
                                                      });
                                                      Scaffold.of(context).openEndDrawer();
                                                    },
                                                    child: const Text(
                                                      'View',
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 20,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          title: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const CircleAvatar(
                                                radius: 20,
                                                backgroundColor: Colors.amber,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Name: ${teachers[index].name}',
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      'Email: ${teachers[index].email}',
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      'Phone: ${teachers[index].phoneNumber}',
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginalDrawerContent() {
    if (_selectedTeacherDocId == null) {
      print('Debug: No teacher selected');
      return const Center(child: Text('Please select a teacher to view their profile'));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _usersCollection.doc(_selectedTeacherDocId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('Debug: Fetching document for docId: $_selectedTeacherDocId');
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print('Debug: Error fetching document for docId: $_selectedTeacherDocId, error: ${snapshot.error}');
          return const Center(child: Text('Error loading teacher data'));
        }
        if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
          print('Debug: No document found or data is null for docId: $_selectedTeacherDocId');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No teacher data found for this user'),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedTeacherDocId = null;
                    });
                  },
                  child: const Text('Back'),
                ),
              ],
            ),
          );
        }

        Map<String, dynamic>? data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null || data['role'] != 'teacher') {
          print('Debug: Invalid data or user with docId $_selectedTeacherDocId is not a teacher, data: $data');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Selected user is not a teacher or data is invalid'),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedTeacherDocId = null;
                    });
                  },
                  child: const Text('Back'),
                ),
              ],
            ),
          );
        }

        Teacher teacher = Teacher.fromFirestore(snapshot.data!);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Colors.blue),
                child: Center(
                  child: CircleAvatar(
                    radius: 50, // Adjust size as needed
                    backgroundImage: data['profileImageUrl'] != null
                        ? NetworkImage(data['profileImageUrl']) // Use profile image URL from Firestore
                        : const AssetImage('assets/default_profile.png'), // Fallback to default image
                    backgroundColor: Colors.grey, // Fallback background color
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${teacher.name}', style: const TextStyle(fontSize: 20)),
                    Text('Email: ${teacher.email}', style: const TextStyle(fontSize: 20)),
                    Text('Phone: ${teacher.phoneNumber}', style: const TextStyle(fontSize: 20)),
                    const Divider(),
                  ],
                ),
              ),
              const Text('Video Description', style: TextStyle(fontSize: 30)),
              Container(
                height: 200,
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.add, size: 90),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 40),
                  ),
                ],
              ),
              const Text('Description', style: TextStyle(fontSize: 30)),
              Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(width: 2, color: Colors.black),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'This will add the teacher description and help understand everything.',
                  style: TextStyle(fontSize: 20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showGalleryPage = true;
                      _showPostsPage = false;
                    });
                  },
                  child: const Text('Go to Gallery'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showPostsPage = true;
                      _showGalleryPage = false;
                    });
                  },
                  child: const Text('Go to Posts'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGalleryPage() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          const Text('Gallery Page', style: TextStyle(fontSize: 24)),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showGalleryPage = false;
              });
            },
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsPage() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          const Text('Posts Page', style: TextStyle(fontSize: 24)),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showPostsPage = false;
              });
            },
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

List<String> teacherinfo = ['Name: ', 'Email: ', 'Phone Number: '];