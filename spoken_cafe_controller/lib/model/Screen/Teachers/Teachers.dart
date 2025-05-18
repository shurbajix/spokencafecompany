
// import 'dart:io';

// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:video_player/video_player.dart';

// class Teacher {
//   final String name;
//   final String email;
//   final String phoneNumber;
//   final String docId;
//   final String? profileImageUrl;
//   final String? verificationVideo;
//   final String? verificationDocument;
//   final String? verificationDescription;
//   final bool isVerified;

//   Teacher({
//     required this.name,
//     required this.email,
//     required this.phoneNumber,
//     required this.docId,
//     this.profileImageUrl,
//     this.verificationVideo,
//     this.verificationDocument,
//     this.verificationDescription,
//     required this.isVerified,
//   });

//   factory Teacher.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>? ?? {};
//     return Teacher(
//       name: data['name']?.toString() ?? 'No name',
//       email: data['email']?.toString() ?? 'No email',
//       phoneNumber: data['phoneNumber']?.toString() ?? 'No phone number',
//       docId: doc.id,
//       profileImageUrl: data['profileImageUrl'] as String?,
//       verificationVideo: data['verificationVideo'] as String?,
//       verificationDocument: data['verificationDocument'] as String?,
//       verificationDescription: data['verificationDescription'] as String?,
//       isVerified: data['isVerified'] == true,
//     );
//   }
// }

// class Teachers extends StatefulWidget {
//   const Teachers({super.key});

//   @override
//   _TeachersState createState() => _TeachersState();
// }

// class _TeachersState extends State<Teachers> {
//   final ScrollController _scrollController = ScrollController();
//   bool _showPostsPage = false;
//   bool _showGalleryPage = false;
//   List<Teacher> teachers = [];
//   bool isLoading = true;
//   String? errorMessage;
//   late CollectionReference _usersCollection;
//   bool _hasFetched = false;
//   String? _selectedTeacherDocId;
//   String _searchQuery = '';

//   @override
//   void initState() {
//     super.initState();
//     _initializeFirebase();
//   }

//   void _initializeFirebase() {
//     _usersCollection = FirebaseFirestore.instance.collection('users');
//     _fetchTeachers();
//   }

//   Future<void> _fetchTeachers() async {
//     if (_hasFetched) return;
//     _hasFetched = true;

//     setState(() {
//       isLoading = true;
//       errorMessage = null;
//     });

//     try {
//       final snapshot = await _usersCollection
//           .where('role', isEqualTo: 'teacher')
//           .get()
//           .timeout(const Duration(seconds: 15));

//       teachers = snapshot.docs.map((doc) => Teacher.fromFirestore(doc)).toList();

//       setState(() => isLoading = false);
//     } on FirebaseException catch (e) {
//       setState(() {
//         errorMessage = _handleFirebaseError(e);
//         isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         errorMessage = 'Error: ${e.toString()}';
//         isLoading = false;
//       });
//     }
//   }

//   String _handleFirebaseError(FirebaseException e) {
//     switch (e.code) {
//       case 'permission-denied':
//         return 'You don\'t have permission to access this data.';
//       case 'unavailable':
//         return 'Network error. Please check your connection.';
//       default:
//         return 'Firestore error: ${e.message}';
//     }
//   }

//   Future<void> _approve(String docId) async {
//     try {
//       await _usersCollection.doc(docId).update({'isVerified': true});
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Teacher approved')),
//       );
//       _hasFetched = false;
//       await _fetchTeachers();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Approve failed: $e')),
//       );
//     }
//   }

//   Future<void> _reject(String docId, String reason) async {
//     try {
//       await _usersCollection.doc(docId).update({
//         'isVerified': false,
//         'rejectionReason': reason,
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Teacher rejected')),
//       );
//       _hasFetched = false;
//       await _fetchTeachers();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Reject failed: $e')),
//       );
//     }
//   }

//   Future<void> _pickFile() async {
//     try {
//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         type: FileType.video,
//         allowMultiple: false,
//       );
//       if (result != null) {
//         PlatformFile file = result.files.first;
//         print("File picked: ${file.name}");
//       }
//     } catch (e) {
//       print("Error picking file: $e");
//     }
//   }

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     super.dispose();
//   }
//   Future<void> _downloadImage(String imageUrl) async {
//     try {
//       var status = await Permission.storage.request();
//       if (!status.isGranted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Storage permission is required to download images.')),
//         );
//         return;
//       }

//       Directory directory;
//       if (Platform.isAndroid) {
//         directory = (await getExternalStorageDirectory())!;
//       } else if (Platform.isIOS) {
//         directory = await getApplicationDocumentsDirectory();
//       } else {
//         directory = await getApplicationDocumentsDirectory();
//       }

//       String fileName = imageUrl.split('/').last.split('?').first;
//       String savePath = '${directory.path}/$fileName';

//       Dio dio = Dio();
//       await dio.download(imageUrl, savePath);

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Downloaded to $savePath')),
//       );
//     } catch (e, stacktrace) {
//       print('Download error: $e');
//       print('Stack trace: $stacktrace');

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error downloading image: $e')),
//       );
//     }
//   }
//   List<Teacher> get _filteredTeachers {
//     if (_searchQuery.isEmpty) return teachers;
//     final q = _searchQuery.toLowerCase();
//     return teachers.where((t) {
//       return t.name.toLowerCase().contains(q) ||
//           t.email.toLowerCase().contains(q) ||
//           t.phoneNumber.toLowerCase().contains(q);
//     }).toList();
//   }

//   bool _isVideoUrl(String url) {
//     final lower = url.toLowerCase();
//     return lower.endsWith('.mp4') ||
//         lower.endsWith('.mov') ||
//         lower.endsWith('.avi') ||
//         lower.endsWith('.wmv') ||
//         lower.endsWith('.flv') ||
//         lower.endsWith('.mkv');
//   }

//   void _showFullScreenImage(BuildContext context, String imageUrl) {
//     showDialog(
//       context: context,
//       builder: (_) => Dialog(
//         child: InteractiveViewer(
//           child: Image.network(imageUrl, fit: BoxFit.contain),
//         ),
//       ),
//     );
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       endDrawer: Drawer(
//         width: 700,
//         child: _showPostsPage
//             ? _buildPostsPage()
//             : _showGalleryPage
//                 ? _buildGalleryPage()
//                 : _buildOriginalDrawerContent(),
//       ),
//       body: ListView(
//         shrinkWrap: true,
//         children: [
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             child: TextField(
//               decoration: InputDecoration(
//                 hintText: 'Search by name, email or phone',
//                 prefixIcon: const Icon(Icons.search),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide: const BorderSide(color: Colors.grey),
//                 ),
//               ),
//               onChanged: (val) => setState(() => _searchQuery = val),
//             ),
//           ),
//           Row(
//             children: [
//               Expanded(
//                 child: Container(
//                   margin: const EdgeInsets.all(10),
//                   decoration: BoxDecoration(
//                     color: Colors.grey,
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: const Column(
//                     children: [
//                       Text('Underlines', style: TextStyle(fontSize: 20)),
//                     ],
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: Container(
//                   margin: const EdgeInsets.all(10),
//                   decoration: BoxDecoration(
//                     color: Colors.grey,
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: const Column(
//                     children: [
//                       Text('Underlines', style: TextStyle(fontSize: 20)),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           Container(
//             margin: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(10),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.1),
//                   blurRadius: 4,
//                   spreadRadius: 2,
//                 ),
//               ],
//             ),
//             height: 600,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 const Padding(
//                   padding: EdgeInsets.all(10),
//                   child: Text(
//                     "Teachers List",
//                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//                 const Divider(),
//                 Expanded(
//                   child: isLoading
//                       ? const Center(child: CircularProgressIndicator())
//                       : errorMessage != null
//                           ? Center(
//                               child: Column(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   Text(errorMessage!),
//                                   ElevatedButton(
//                                     onPressed: () {
//                                       _hasFetched = false;
//                                       _fetchTeachers();
//                                     },
//                                     child: const Text('Retry'),
//                                   ),
//                                 ],
//                               ),
//                             )
//                           : _filteredTeachers.isEmpty
//                               ? const Center(child: Text('No teachers found'))
//                               : RefreshIndicator(
//                                   onRefresh: () async {
//                                     _hasFetched = false;
//                                     await _fetchTeachers();
//                                   },
//                                   child: Scrollbar(
//                                     controller: _scrollController,
//                                     thickness: 8,
//                                     radius: const Radius.circular(10),
//                                     child: ListView.builder(
//                                       controller: _scrollController,
//                                       itemCount: _filteredTeachers.length,
//                                       itemBuilder: (context, index) {
//                                         final t = _filteredTeachers[index];
//                                         return ListTile(
//                                           contentPadding:
//                                               const EdgeInsets.symmetric(horizontal: 20),
//                                           trailing: SizedBox(
//                                             width: 279,
//                                             child: Row(
//                                               mainAxisSize: MainAxisSize.min,
//                                               children: [
//                                                 Expanded(
//                                                   child: TextButton(
//                                                     onPressed: t.isVerified
//                                                         ? null
//                                                         : () => _approve(t.docId),
//                                                     child: Text(
//                                                       'Accept',
//                                                       style: TextStyle(
//                                                         color: t.isVerified
//                                                             ? Colors.grey
//                                                             : Colors.green,
//                                                         fontSize: 20,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   child: TextButton(
//                                                     onPressed: () {
//                                                       showDialog(
//                                                         context: context,
//                                                         builder: (context) {
//                                                           final ctrl = TextEditingController();
//                                                           return AlertDialog(
//                                                             backgroundColor: Colors.white,
//                                                             title:
//                                                                 const Text('Reason for rejection'),
//                                                             content: TextFormField(
//                                                               controller: ctrl,
//                                                               decoration: InputDecoration(
//                                                                 border: OutlineInputBorder(
//                                                                   borderRadius:
//                                                                       BorderRadius.circular(10),
//                                                                 ),
//                                                                 hintText: 'Enter reason',
//                                                               ),
//                                                             ),
//                                                             actions: [
//                                                               TextButton(
//                                                                 onPressed: () =>
//                                                                     Navigator.pop(context),
//                                                                 child: const Text(
//                                                                   'Cancel',
//                                                                   style: TextStyle(
//                                                                       color: Colors.red,
//                                                                       fontSize: 20),
//                                                                 ),
//                                                               ),
//                                                               TextButton(
//                                                                 onPressed: () {
//                                                                   _reject(
//                                                                       t.docId, ctrl.text.trim());
//                                                                   Navigator.pop(context);
//                                                                 },
//                                                                 child: const Text(
//                                                                   'Reject',
//                                                                   style: TextStyle(
//                                                                       color: Colors.red,
//                                                                       fontSize: 20),
//                                                                 ),
//                                                               ),
//                                                             ],
//                                                           );
//                                                         },
//                                                       );
//                                                     },
//                                                     child: const Text(
//                                                       'Delete',
//                                                       style:
//                                                           TextStyle(color: Colors.red, fontSize: 20),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   child: TextButton(
//                                                     onPressed: () {
//                                                       setState(() {
//                                                         _selectedTeacherDocId = t.docId;
//                                                         _showPostsPage = false;
//                                                         _showGalleryPage = true;
//                                                       });
//                                                       Scaffold.of(context).openEndDrawer();
//                                                     },
//                                                     child: const Text(
//                                                       'View',
//                                                       style: TextStyle(
//                                                           color: Colors.black, fontSize: 20),
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                           title: Row(
//                                             mainAxisSize: MainAxisSize.min,
//                                             children: [
//                                               CircleAvatar(
//                                                 radius: 20,
//                                                 backgroundColor: Colors.amber,
//                                                 backgroundImage: t.profileImageUrl != null
//                                                     ? NetworkImage(t.profileImageUrl!)
//                                                     : null,
//                                                 child: t.profileImageUrl == null
//                                                     ? const Icon(Icons.person,
//                                                         size: 20, color: Colors.white)
//                                                     : null,
//                                               ),
//                                               const SizedBox(width: 10),
//                                               Expanded(
//                                                 child: Column(
//                                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                                   children: [
//                                                     Text('Name: ${t.name}',
//                                                         overflow: TextOverflow.ellipsis),
//                                                     Text('Email: ${t.email}',
//                                                         overflow: TextOverflow.ellipsis),
//                                                     Text('Phone: ${t.phoneNumber}',
//                                                         overflow: TextOverflow.ellipsis),
//                                                   ],
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         );
//                                       },
//                                     ),
//                                   ),
//                                 ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildOriginalDrawerContent() {
//     if (_selectedTeacherDocId == null) {
//       return const Center(child: Text('Please select a teacher to view their profile'));
//     }

//     return FutureBuilder<DocumentSnapshot>(
//       future: _usersCollection.doc(_selectedTeacherDocId).get(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
//         if (snapshot.hasError) {
//           return const Center(child: Text('Error loading teacher data'));
//         }
//         if (!snapshot.hasData || !snapshot.data!.exists) {
//           return Center(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Text('No teacher data found for this user'),
//                 ElevatedButton(
//                   onPressed: () => setState(() => _selectedTeacherDocId = null),
//                   child: const Text('Back'),
//                 ),
//               ],
//             ),
//           );
//         }
//         final teacher = Teacher.fromFirestore(snapshot.data!);
//         return SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               DrawerHeader(
//                 decoration: const BoxDecoration(color: Colors.blue),
//                 child: Center(
//                   child: CircleAvatar(
//                     radius: 50,
//                     backgroundColor: Colors.grey,
//                     backgroundImage: teacher.profileImageUrl != null
//                         ? NetworkImage(teacher.profileImageUrl!)
//                         : null,
//                     child: teacher.profileImageUrl == null
//                         ? const Icon(Icons.person, size: 50, color: Colors.white)
//                         : null,
//                   ),
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text('Name: ${teacher.name}', style: const TextStyle(fontSize: 20)),
//                     Text('Email: ${teacher.email}', style: const TextStyle(fontSize: 20)),
//                     Text('Phone: ${teacher.phoneNumber}', style: const TextStyle(fontSize: 20)),
//                     const Divider(),
//                   ],
//                 ),
//               ),
//               const Text('Verification Video', style: TextStyle(fontSize: 18)),
//               if (teacher.verificationVideo != null)
//                 SizedBox(
//                   height: 200,
//                   child: ElevatedButton(
//                     onPressed: () {
//                       // preview video logic here
//                     },
//                     child: const Text('Play Video'),
//                   ),
//                 )
//               else
//                 const Text('No video submitted'),
//               const Divider(),
//               const Text('Description', style: TextStyle(fontSize: 18)),
//               Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Text(teacher.verificationDescription ?? 'No description'),
//               ),
//               const Divider(),
//               const Text('Document', style: TextStyle(fontSize: 18)),
//               if (teacher.verificationDocument != null)
//                 GestureDetector(
//                   onTap: () => showDialog(
//                     context: context,
//                     builder: (_) => Dialog(
//                       child: InteractiveViewer(
//                         child: Image.network(teacher.verificationDocument!),
//                       ),
//                     ),
//                   ),
//                   child: Image.network(
//                     teacher.verificationDocument!,
//                     height: 200,
//                     fit: BoxFit.cover,
//                   ),
//                 )
//               else
//                 const Text('No document submitted'),
//               const SizedBox(height: 20),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 child: ElevatedButton(
//                   onPressed: () {
//                     setState(() {
//                       _showGalleryPage = true;
//                       _showPostsPage = false;
//                     });
//                     Scaffold.of(context).openEndDrawer();
//                   },
//                   child: const Text('Go to Gallery'),
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 child: ElevatedButton(
//                   onPressed: () {
//                     setState(() {
//                       _showPostsPage = true;
//                       _showGalleryPage = false;
//                     });
//                     Scaffold.of(context).openEndDrawer();
//                   },
//                   child: const Text('Go to Posts'),
//                 ),
//               ),
//               const SizedBox(height: 20),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildGalleryPage() {
//     if (_selectedTeacherDocId == null) {
//       return const Center(child: Text('No teacher selected'));
//     }

//     return StreamBuilder<QuerySnapshot>(
//       stream: FirebaseFirestore.instance
//           .collection('posts')
//           .where('userId', isEqualTo: _selectedTeacherDocId)
//           .orderBy('createdAt', descending: true)
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
//         if (snapshot.hasError) {
//           return Center(child: Text('Error loading gallery: ${snapshot.error}'));
//         }
//         if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//           return const Center(child: Text('No posts found'));
//         }

//         final posts = snapshot.data!.docs;

//         // Extract images and videos only from posts' mediaFiles
//         List<String> images = [];
//         List<String> videos = [];

//         for (var postDoc in posts) {
//           final postData = postDoc.data() as Map<String, dynamic>;
//           final List<dynamic>? mediaFiles = postData['mediaFiles'];
//           if (mediaFiles != null) {
//             for (var mediaUrl in mediaFiles) {
//               if (mediaUrl is String && mediaUrl.isNotEmpty) {
//                 if (_isVideoUrl(mediaUrl)) {
//                   videos.add(mediaUrl);
//                 } else {
//                   images.add(mediaUrl);
//                 }
//               }
//             }
//           }
//         }

//         return DefaultTabController(
//           length: 2,
//           child: Scaffold(
//             appBar: AppBar(
//               leading: IconButton(
//                 icon: const Icon(Icons.arrow_back_ios_new),
//                 onPressed: () {
//                   setState(() {
//                     _showGalleryPage = false;
//                   });
//                   Scaffold.of(context).openEndDrawer();
//                 },
//               ),
//               title: const Text('Gallery from Posts'),
//               bottom: const TabBar(
//                 tabs: [
//                   Tab(text: 'Images'),
//                   Tab(text: 'Videos'),
//                 ],
//               ),
//             ),
//             body: TabBarView(
//               children: [
//                 images.isEmpty
//                     ? const Center(child: Text('No images found'))
//                     : Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: GridView.builder(
//                           gridDelegate:
//                               const SliverGridDelegateWithFixedCrossAxisCount(
//                             crossAxisCount: 3,
//                             crossAxisSpacing: 8,
//                             mainAxisSpacing: 8,
//                           ),
//                           itemCount: images.length,
//                           itemBuilder: (context, index) {
//                             final imageUrl = images[index];
//                             return GestureDetector(
//                               onTap: () => _showFullScreenImage(context, imageUrl),
//                               child: ClipRRect(
//                                 borderRadius: BorderRadius.circular(8),
//                                 child: Image.network(
//                                   imageUrl,
//                                   fit: BoxFit.cover,
//                                   loadingBuilder:
//                                       (context, child, loadingProgress) {
//                                     if (loadingProgress == null) return child;
//                                     return const Center(
//                                         child: CircularProgressIndicator());
//                                   },
//                                   errorBuilder: (context, error, stackTrace) =>
//                                       const Icon(Icons.broken_image),
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                 videos.isEmpty
//                     ? const Center(child: Text('No videos found'))
//                     : ListView.builder(
//                         itemCount: videos.length,
//                         itemBuilder: (context, index) {
//                           final videoUrl = videos[index];
//                           return ListTile(
//                             leading: const Icon(Icons.play_circle_fill,
//                                 size: 40, color: Colors.redAccent),
//                             title: Text('Video ${index + 1}'),
//                             onTap: () => Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) =>
//                                     VideoPlayerScreen(videoUrl: videoUrl),
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildPostsPage() {
//     if (_selectedTeacherDocId == null) {
//       return const Center(child: Text('No teacher selected'));
//     }

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         automaticallyImplyLeading: false, // remove default back button
//         title: const Text('Posts'),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new),
//           onPressed: () {
//             setState(() {
//               _showPostsPage = false;
//             });
//             Scaffold.of(context).openEndDrawer();
//           },
//         ),
//       ),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('posts')
//             .where('userId', isEqualTo: _selectedTeacherDocId)
//             .orderBy('createdAt', descending: true)
//             .snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return const Center(child: Text('No posts found.'));
//           }
//           final posts = snapshot.data!.docs;

//           return GridView.builder(
//             padding: const EdgeInsets.all(8),
//             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: 2,
//               crossAxisSpacing: 18,
//               mainAxisSpacing: 18,
//               childAspectRatio: 0.7,
//             ),
//             itemCount: posts.length,
//             itemBuilder: (context, index) {
//               final postDoc = posts[index];
//               final postData = postDoc.data() as Map<String, dynamic>;
//               return _buildPostGridItem(postDoc.id, postData);
//             },
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildPostGridItem(String postId, Map<String, dynamic> postData) {
//     return Container(
//       margin: const EdgeInsets.all(4),
//       decoration: BoxDecoration(
//         color: Colors.amber,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       padding: const EdgeInsets.all(8),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           if (postData['text'] != null && postData['text'].isNotEmpty)
//             Text(
//               postData['text'],
//               style: const TextStyle(fontSize: 16, color: Colors.black87),
//               maxLines: 3,
//               overflow: TextOverflow.ellipsis,
//             ),
//           const SizedBox(height: 8),
//           if (postData['mediaFiles'] != null && postData['mediaFiles'].isNotEmpty)
//             Expanded(
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(10),
//                 child: Image.network(
//                   postData['mediaFiles'][0],
//                   fit: BoxFit.cover,
//                   width: double.infinity,
//                 ),
//               ),
//             ),
//              IconButton(
//             onPressed: () {
//               final imageUrl = postData['mediaFiles'][0];
//               if (imageUrl != null && imageUrl.isNotEmpty) {
//                 _downloadImage(imageUrl);
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('No image to download')),
//                 );
//               }
//             },
//             icon: const Icon(Icons.download),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class VideoPlayerScreen extends StatefulWidget {
//   final String videoUrl;
//   const VideoPlayerScreen({Key? key, required this.videoUrl}) : super(key: key);

//   @override
//   _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
// }

// class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
//   late VideoPlayerController _controller;
//   bool _initialized = false;

//   @override
//   void initState() {
//     super.initState();
//     _controller = VideoPlayerController.network(widget.videoUrl)
//       ..initialize().then((_) {
//         setState(() {
//           _initialized = true;
//         });
//         _controller.play();
//       });
//   }

//   @override
//   void dispose() {
//     _controller.pause();
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Video Player'),
//       ),
//       body: Center(
//         child: _initialized
//             ? AspectRatio(
//                 aspectRatio: _controller.value.aspectRatio,
//                 child: Stack(
//                   alignment: Alignment.bottomCenter,
//                   children: [
//                     VideoPlayer(_controller),
//                     VideoProgressIndicator(_controller, allowScrubbing: true),
//                     GestureDetector(
//                       onTap: () {
//                         setState(() {
//                           if (_controller.value.isPlaying) {
//                             _controller.pause();
//                           } else {
//                             _controller.play();
//                           }
//                         });
//                       },
//                       child: Container(
//                         color: Colors.transparent,
//                         alignment: Alignment.center,
//                         child: !_controller.value.isPlaying
//                             ? const Icon(Icons.play_arrow, size: 80, color: Colors.white)
//                             : null,
//                       ),
//                     ),
//                   ],
//                 ),
//               )
//             : const CircularProgressIndicator(),
//       ),
//     );
//   }
// }

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

class Teacher {
  final String name;
  final String email;
  final String phoneNumber;
  final String docId;
  final String? profileImageUrl;
  final String? verificationVideo;
  final String? verificationDocument;
  final String? verificationDescription;
  final bool isVerified;

  Teacher({
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.docId,
    this.profileImageUrl,
    this.verificationVideo,
    this.verificationDocument,
    this.verificationDescription,
    required this.isVerified,
  });

  factory Teacher.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Teacher(
      name: data['name']?.toString() ?? 'No name',
      email: data['email']?.toString() ?? 'No email',
      phoneNumber: data['phoneNumber']?.toString() ?? 'No phone number',
      docId: doc.id,
      profileImageUrl: data['profileImageUrl'] as String?,
      verificationVideo: data['verificationVideo'] as String?,
      verificationDocument: data['verificationDocument'] as String?,
      verificationDescription: data['verificationDescription'] as String?,
      isVerified: data['isVerified'] == true,
    );
  }
}

class Teachers extends StatefulWidget {
  const Teachers({super.key});

  @override
  _TeachersState createState() => _TeachersState();
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
  String _searchQuery = '';

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
      final snapshot = await _usersCollection
          .where('role', isEqualTo: 'teacher')
          .get()
          .timeout(const Duration(seconds: 15));

      teachers = snapshot.docs.map((doc) => Teacher.fromFirestore(doc)).toList();

      setState(() => isLoading = false);
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

  Future<void> _approve(String docId) async {
    try {
      await _usersCollection.doc(docId).update({'isVerified': true});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher approved')),
      );
      _hasFetched = false;
      await _fetchTeachers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approve failed: $e')),
      );
    }
  }

  Future<void> _reject(String docId, String reason) async {
    try {
      await _usersCollection.doc(docId).update({
        'isVerified': false,
        'rejectionReason': reason,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher rejected')),
      );
      _hasFetched = false;
      await _fetchTeachers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject failed: $e')),
      );
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
  
  Future<void> _downloadImage(String imageUrl) async {
    try {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to download images.')),
        );
        return;
      }

      Directory directory;
      if (Platform.isAndroid) {
        directory = (await getExternalStorageDirectory())!;
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      String fileName = imageUrl.split('/').last.split('?').first;
      String savePath = '${directory.path}/$fileName';

      Dio dio = Dio();
      await dio.download(imageUrl, savePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded to $savePath')),
      );
    } catch (e, stacktrace) {
      print('Download error: $e');
      print('Stack trace: $stacktrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading image: $e')),
      );
    }
  }
  
  List<Teacher> get _filteredTeachers {
    if (_searchQuery.isEmpty) return teachers;
    final q = _searchQuery.toLowerCase();
    return teachers.where((t) {
      return t.name.toLowerCase().contains(q) ||
          t.email.toLowerCase().contains(q) ||
          t.phoneNumber.toLowerCase().contains(q);
    }).toList();
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.wmv') ||
        lower.endsWith('.flv') ||
        lower.endsWith('.mkv');
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, email or phone',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
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
                          : _filteredTeachers.isEmpty
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
                                      itemCount: _filteredTeachers.length,
                                      itemBuilder: (context, index) {
                                        final t = _filteredTeachers[index];
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
                                                    onPressed: t.isVerified
                                                        ? null
                                                        : () => _approve(t.docId),
                                                    child: Text(
                                                      'Accept',
                                                      style: TextStyle(
                                                        color: t.isVerified
                                                            ? Colors.grey
                                                            : Colors.green,
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
                                                          final ctrl = TextEditingController();
                                                          return AlertDialog(
                                                            backgroundColor: Colors.white,
                                                            title:
                                                                const Text('Reason for rejection'),
                                                            content: TextFormField(
                                                              controller: ctrl,
                                                              decoration: InputDecoration(
                                                                border: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(10),
                                                                ),
                                                                hintText: 'Enter reason',
                                                              ),
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(context),
                                                                child: const Text(
                                                                  'Cancel',
                                                                  style: TextStyle(
                                                                      color: Colors.red,
                                                                      fontSize: 20),
                                                                ),
                                                              ),
                                                              TextButton(
                                                                onPressed: () {
                                                                  _reject(
                                                                      t.docId, ctrl.text.trim());
                                                                  Navigator.pop(context);
                                                                },
                                                                child: const Text(
                                                                  'Reject',
                                                                  style: TextStyle(
                                                                      color: Colors.red,
                                                                      fontSize: 20),
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                    },
                                                    child: const Text(
                                                      'Delete',
                                                      style:
                                                          TextStyle(color: Colors.red, fontSize: 20),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: TextButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _selectedTeacherDocId = t.docId;
                                                        _showPostsPage = false;
                                                        _showGalleryPage = true;
                                                      });
                                                      Scaffold.of(context).openEndDrawer();
                                                    },
                                                    child: const Text(
                                                      'View',
                                                      style: TextStyle(
                                                          color: Colors.black, fontSize: 20),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          title: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor: Colors.amber,
                                                backgroundImage: t.profileImageUrl != null
                                                    ? NetworkImage(t.profileImageUrl!)
                                                    : null,
                                                child: t.profileImageUrl == null
                                                    ? const Icon(Icons.person,
                                                        size: 20, color: Colors.white)
                                                    : null,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Name: ${t.name}',
                                                        overflow: TextOverflow.ellipsis),
                                                    Text('Email: ${t.email}',
                                                        overflow: TextOverflow.ellipsis),
                                                    Text('Phone: ${t.phoneNumber}',
                                                        overflow: TextOverflow.ellipsis),
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
      return const Center(child: Text('Please select a teacher to view their profile'));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _usersCollection.doc(_selectedTeacherDocId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading teacher data'));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No teacher data found for this user'),
                ElevatedButton(
                  onPressed: () => setState(() => _selectedTeacherDocId = null),
                  child: const Text('Back'),
                ),
              ],
            ),
          );
        }
        final teacher = Teacher.fromFirestore(snapshot.data!);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Colors.blue),
                child: Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey,
                    backgroundImage: teacher.profileImageUrl != null
                        ? NetworkImage(teacher.profileImageUrl!)
                        : null,
                    child: teacher.profileImageUrl == null
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
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
              const Text('Verification Video', style: TextStyle(fontSize: 18)),
              if (teacher.verificationVideo != null)
                SizedBox(
                  height: 200,
                  child: ElevatedButton(
                    onPressed: () {
                      // preview video logic here
                    },
                    child: const Text('Play Video'),
                  ),
                )
              else
                const Text('No video submitted'),
              const Divider(),
              const Text('Description', style: TextStyle(fontSize: 18)),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(teacher.verificationDescription ?? 'No description'),
              ),
              const Divider(),
              const Text('Document', style: TextStyle(fontSize: 18)),
              if (teacher.verificationDocument != null)
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: InteractiveViewer(
                        child: Image.network(teacher.verificationDocument!),
                      ),
                    ),
                  ),
                  child: Image.network(
                    teacher.verificationDocument!,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                )
              else
                const Text('No document submitted'),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showGalleryPage = true;
                      _showPostsPage = false;
                    });
                    Scaffold.of(context).openEndDrawer();
                  },
                  child: const Text('Go to Gallery'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showPostsPage = true;
                      _showGalleryPage = false;
                    });
                    Scaffold.of(context).openEndDrawer();
                  },
                  child: const Text('Go to Posts'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGalleryPage() {
    if (_selectedTeacherDocId == null) {
      return const Center(child: Text('No teacher selected'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: _selectedTeacherDocId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading gallery: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No posts found'));
        }

        final posts = snapshot.data!.docs;

        // Extract images and videos only from posts' mediaFiles
        List<String> images = [];
        List<String> videos = [];

        for (var postDoc in posts) {
          final postData = postDoc.data() as Map<String, dynamic>;
          final List<dynamic>? mediaFiles = postData['mediaFiles'];
          if (mediaFiles != null) {
            for (var mediaUrl in mediaFiles) {
              if (mediaUrl is String && mediaUrl.isNotEmpty) {
                if (_isVideoUrl(mediaUrl)) {
                  videos.add(mediaUrl);
                } else {
                  images.add(mediaUrl);
                }
              }
            }
          }
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () {
                  setState(() {
                    _showGalleryPage = false;
                  });
                  Scaffold.of(context).openEndDrawer();
                },
              ),
              title: const Text('Gallery from Posts'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Images'),
                  Tab(text: 'Videos'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                images.isEmpty
                    ? const Center(child: Text('No images found'))
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            final imageUrl = images[index];
                            return GestureDetector(
                              onTap: () => _showFullScreenImage(context, imageUrl),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  },
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                videos.isEmpty
                    ? const Center(child: Text('No videos found'))
                    : ListView.builder(
                        itemCount: videos.length,
                        itemBuilder: (context, index) {
                          final videoUrl = videos[index];
                          return ListTile(
                            leading: const Icon(Icons.play_circle_fill,
                                size: 40, color: Colors.redAccent),
                            title: Text('Video ${index + 1}'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    VideoPlayerScreen(videoUrl: videoUrl),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostsPage() {
    if (_selectedTeacherDocId == null) {
      return const Center(child: Text('No teacher selected'));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text('Posts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            setState(() {
              _showPostsPage = false;
            });
            Scaffold.of(context).openEndDrawer();
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: _selectedTeacherDocId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No posts found.'));
          }
          final posts = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              childAspectRatio: 0.7,
            ),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final postDoc = posts[index];
              final postData = postDoc.data() as Map<String, dynamic>;
              return _buildPostGridItem(postDoc.id, postData);
            },
          );
        },
      ),
    );
  }

  Widget _buildPostGridItem(String postId, Map<String, dynamic> postData) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (postData['text'] != null && postData['text'].isNotEmpty)
            Text(
              postData['text'],
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          // NEW: Show description if available
          if (postData['description'] != null && postData['description'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6.0, bottom: 6.0),
              child: Text(
                postData['description'],
                style: const TextStyle(fontSize: 14, color: Colors.black54),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 8),
          if (postData['mediaFiles'] != null && postData['mediaFiles'].isNotEmpty)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  postData['mediaFiles'][0],
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          IconButton(
            onPressed: () {
              final imageUrl = postData['mediaFiles'][0];
              if (imageUrl != null && imageUrl.isNotEmpty) {
                _downloadImage(imageUrl);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No image to download')),
                );
              }
            },
            icon: const Icon(Icons.download),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Player'),
      ),
      body: Center(
        child: _initialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_controller.value.isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                        });
                      },
                      child: Container(
                        color: Colors.transparent,
                        alignment: Alignment.center,
                        child: !_controller.value.isPlaying
                            ? const Icon(Icons.play_arrow, size: 80, color: Colors.white)
                            : null,
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
