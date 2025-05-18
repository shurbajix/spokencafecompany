// import 'dart:async';
// import 'dart:io';
// import 'dart:typed_data';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:spokencafe/model/Account/Log/Login.dart';
// import 'package:spokencafe/profile/Edit_Profile/Edit_Profile.dart';
// import 'package:spokencafe/profile/Help/Help.dart';
// import 'package:spokencafe/profile/settings/settings.dart';
// import 'package:video_player/video_player.dart';

// // Assuming profileImageProvider is defined elsewhere
// final profileImageProvider = StateProvider<String?>((ref) => null);

// class Profile extends ConsumerStatefulWidget {
//   final Map<String, dynamic> user;
//   final bool isTeacher;

//   const Profile({super.key, required this.user, required this.isTeacher});

//   @override
//   ConsumerState<Profile> createState() => _ProfileState();
// }

// class _ProfileState extends ConsumerState<Profile> {
//   final TextEditingController _controller = TextEditingController();
//   late String uid;
//   bool _isEditable = false;
//   bool _showCheckIcon = false;
//   bool isLoading = false;
//   String? userName;
//   bool isFollowing = false;
//   File? _imageFile;
//   Uint8List? pickedImage;
//    User ?currentUser;
//   String? profileImageUrl;
//   int followersCount = 0;
//   int followingCount = 0;
//   List<String> imageUrls = [];
//   List<String> videoUrls = [];
//   StreamSubscription? _followStatusSubscription;
//   StreamSubscription? _followersCountSubscription;
//   StreamSubscription? _followingCountSubscription;
//   String? _uploadedVideoUrl;
//   String? _currentVideoDocId;
//   final Map<String, VideoPlayerController> _videoControllers = {};
//   bool _isVideoLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     currentUser = FirebaseAuth.instance.currentUser!;
//     uid = currentUser!.uid;
//     _loadText();
//     _loadUserName();
//     _initUser();
//     _setupFollowStatusListener();
//     _setupFollowersCountListener();
//     _setupFollowingCountListener();
//   }

//   void _setupFollowStatusListener() {
//     if (currentUser!.uid != widget.user['uid']) {
//       _followStatusSubscription = FirebaseFirestore.instance
//           .collection('users')
//           .doc(widget.user['uid'])
//           .collection('followers')
//           .doc(currentUser!.uid)
//           .snapshots()
//           .listen((snapshot) {
//         if (mounted) {
//           setState(() => isFollowing = snapshot.exists);
//         }
//       });
//     }
//   }

//   void _setupFollowersCountListener() {
//     _followersCountSubscription = FirebaseFirestore.instance
//         .collection('users')
//         .doc(widget.user['uid'])
//         .collection('followers')
//         .snapshots()
//         .listen((snapshot) {
//       if (mounted) {
//         setState(() => followersCount = snapshot.size);
//       }
//     });
//   }

//   void _setupFollowingCountListener() {
//     _followingCountSubscription = FirebaseFirestore.instance
//         .collection('users')
//         .doc(widget.user['uid'])
//         .collection('following')
//         .snapshots()
//         .listen((snapshot) {
//       if (mounted) {
//         setState(() => followingCount = snapshot.size);
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _followStatusSubscription?.cancel();
//     _followersCountSubscription?.cancel();
//     _followingCountSubscription?.cancel();
//     _controller.dispose();
//     for (var controller in _videoControllers.values) {
//       controller.dispose();
//     }
//     _videoControllers.clear();
//     super.dispose();
//   }

//   Future<void> _toggleFollow() async {
//     try {
//       if (currentUser!.uid == widget.user['uid']) return;

//       setState(() => isLoading = true);

//       final batch = FirebaseFirestore.instance.batch();

//       final followersRef = FirebaseFirestore.instance
//           .collection('users')
//           .doc(widget.user['uid'])
//           .collection('followers')
//           .doc(currentUser!.uid);

//       final followingRef = FirebaseFirestore.instance
//           .collection('users')
//           .doc(currentUser!.uid)
//           .collection('following')
//           .doc(widget.user['uid']);

//       if (isFollowing) {
//         batch.delete(followersRef);
//         batch.delete(followingRef);
//       } else {
//         batch.set(followersRef, {'timestamp': FieldValue.serverTimestamp()});
//         batch.set(followingRef, {'timestamp': FieldValue.serverTimestamp()});
//       }

//       await batch.commit();
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             behavior: SnackBarBehavior.floating,
//             content: Text('Error: ${e.toString()}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => isLoading = false);
//       }
//     }
//   }

//   Future<void> _loadUserName() async {
//     try {
//       DocumentSnapshot userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(currentUser!.uid)
//           .get();

//       if (userDoc.exists) {
//         setState(() {
//           userName = userDoc['userName'] ?? 'Loading...';
//           isLoading = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         userName = 'Error loading user data';
//         isLoading = false;
//       });
//       print('Error fetching user data: $e');
//     }
//   }

//   Future<void> _initUser() async {
//     await _fetchProfileImageUrl();
//   }

//   Future<void> _fetchProfileImageUrl() async {
//     try {
//       DocumentSnapshot userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(currentUser!.uid)
//           .get();

//       if (userDoc.exists && userDoc['profileImageUrl'] != null) {
//         setState(() {
//           profileImageUrl = userDoc['profileImageUrl'];
//         });
//       }
//     } catch (e) {
//       print('Error fetching profile image URL: $e');
//     }
//   }

//   Future<void> _loadText() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? savedText = prefs.getString('saved_text');

//     if (savedText != null && savedText.isNotEmpty) {
//       _controller.text = savedText;
//     } else {
//       await _fetchDescription();
//     }
//   }

//   Future<void> _fetchDescription() async {
//     try {
//       final doc = await FirebaseFirestore.instance
//           .collection(
//               widget.isTeacher ? 'teacher_description' : 'student_description')
//           .doc(uid)
//           .get();

//       if (doc.exists && doc.data() != null) {
//         _controller.text = doc.data()!['description'] ?? '';
//       }
//     } catch (e) {
//       print('Error fetching description: $e');
//     }
//   }

//   Future<void> _saveText(String description) async {
//     try {
//       final SharedPreferences prefs = await SharedPreferences.getInstance();
//       await prefs.setString('saved_text', description);

//       final collectionName =
//           widget.isTeacher ? 'teacher_description' : 'student_description';

//       await FirebaseFirestore.instance
//           .collection(collectionName)
//           .doc(currentUser!.uid)
//           .set({
//         'description': description.trim(),
//         'timestamp': FieldValue.serverTimestamp(),
//         'uid': currentUser!.uid,
//         'email': currentUser!.email,
//       }, SetOptions(merge: true));

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           behavior: SnackBarBehavior.floating,
//           backgroundColor: Colors.green,
//           content: Text('Description saved successfully'),
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           behavior: SnackBarBehavior.floating,
//           backgroundColor: Colors.red,
//           content: Text('Failed to save description'),
//         ),
//       );
//     }
//   }

//   Future<void> _videoPicker() async {
//     try {
//       setState(() {
//         isLoading = true;
//       });

//       final pickedFile = await ImagePicker().pickVideo(
//         source: ImageSource.gallery,
//       );

//       if (pickedFile != null) {
//         File videoFile = File(pickedFile.path);

//         String fileName =
//             'videos/${currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}.mp4';
//         final ref = FirebaseStorage.instance.ref().child(fileName);
//         UploadTask uploadTask = ref.putFile(videoFile);
//         TaskSnapshot snapshot = await uploadTask;
//         String downloadURL = await snapshot.ref.getDownloadURL();

//         // Prompt user for description (optional, can be hardcoded for testing)
//         String description =
//             "Sample video description"; // Replace with user input if needed

//         DocumentReference docRef =
//             await FirebaseFirestore.instance.collection('media').add({
//           'userId': currentUser!.uid,
//           'url': downloadURL,
//           'type': 'video',
//           'description': description, // Add description field
//           'timestamp': FieldValue.serverTimestamp(),
//         });

//         setState(() {
//           _uploadedVideoUrl = downloadURL;
//           _currentVideoDocId = docRef.id;
//           videoUrls.insert(0, downloadURL);
//           _isVideoLoading = true;
//         });

//         await _initializeVideo(downloadURL);
//         setState(() {
//           _isVideoLoading = false;
//         });
//       }

//       setState(() {
//         isLoading = false;
//       });
//     } catch (e) {
//       print('❌ Error uploading video: $e');
//       setState(() {
//         isLoading = false;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           behavior: SnackBarBehavior.floating,
//           content: Text('Error uploading video: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   Future<void> _updateVideo() async {
//     try {
//       setState(() {
//         isLoading = true;
//       });

//       final pickedFile = await ImagePicker().pickVideo(
//         source: ImageSource.gallery,
//       );

//       if (pickedFile != null) {
//         File videoFile = File(pickedFile.path);

//         String fileName =
//             'videos/${currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}.mp4';
//         final ref = FirebaseStorage.instance.ref().child(fileName);
//         UploadTask uploadTask = ref.putFile(videoFile);
//         TaskSnapshot snapshot = await uploadTask;
//         String downloadURL = await snapshot.ref.getDownloadURL();

//         String description =
//             "Updated video description"; // Replace with user input if needed

//         String? oldVideoUrl = _uploadedVideoUrl;

//         if (_currentVideoDocId != null) {
//           await FirebaseFirestore.instance
//               .collection('media')
//               .doc(_currentVideoDocId)
//               .update({
//             'url': downloadURL,
//             'description': description, // Update description
//             'timestamp': FieldValue.serverTimestamp(),
//           });
//         } else {
//           DocumentReference docRef =
//               await FirebaseFirestore.instance.collection('media').add({
//             'userId': currentUser!.uid,
//             'url': downloadURL,
//             'type': 'video',
//             'description': description, // Add description
//             'timestamp': FieldValue.serverTimestamp(),
//           });
//           _currentVideoDocId = docRef.id;
//         }

//         setState(() {
//           _uploadedVideoUrl = downloadURL;
//           if (videoUrls.isNotEmpty) {
//             videoUrls[0] = downloadURL;
//           } else {
//             videoUrls.add(downloadURL);
//           }
//           _isVideoLoading = true;
//         });

//         await _initializeVideo(downloadURL);
//         setState(() {
//           _isVideoLoading = false;
//         });

//         if (oldVideoUrl != null) {
//           try {
//             final oldRef = FirebaseStorage.instance.refFromURL(oldVideoUrl);
//             await oldRef.delete();
//           } catch (e) {
//             print('Error deleting old video: $e');
//           }
//         }
//       }

//       setState(() {
//         isLoading = false;
//       });
//     } catch (e) {
//       print('❌ Error updating video: $e');
//       setState(() {
//         isLoading = false;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           behavior: SnackBarBehavior.floating,
//           content: Text('Error updating video: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   void _handleNewPost(Map<String, dynamic> postData) {
//     setState(() {
//       final mediaFiles = List<String>.from(postData['mediaFiles'] ?? []);
//       for (var url in mediaFiles) {
//         if (url.toLowerCase().endsWith('.jpg') ||
//             url.toLowerCase().endsWith('.jpeg') ||
//             url.toLowerCase().endsWith('.png')) {
//           imageUrls.insert(0, url);
//         } else if (url.toLowerCase().endsWith('.mp4')) {
//           videoUrls.insert(0, url);
//           _initializeVideo(url).then((controller) {
//             setState(() {
//               _videoControllers[url] = controller;
//             });
//           });
//         }
//       }
//     });
//   }

//   Future<VideoPlayerController> _initializeVideo(String url) async {
//     if (_videoControllers.containsKey(url)) {
//       final controller = _videoControllers[url]!;
//       if (controller.value.isInitialized) {
//         return controller;
//       } else {
//         controller.dispose();
//         _videoControllers.remove(url);
//       }
//     }

//     final controller = VideoPlayerController.network(url);
//     _videoControllers[url] = controller;
//     try {
//       await controller.initialize();
//       return controller;
//     } catch (e) {
//       print('Error initializing video: $e');
//       _videoControllers.remove(url);
//       controller.dispose();
//       rethrow;
//     }
//   }

//   Widget _buildVideoThumbnail(String url) {
//     return FutureBuilder(
//       future: Future.wait([
//         _initializeVideo(url),
//         // Fetch the description from Firestore
//         FirebaseFirestore.instance
//             .collection('media')
//             .where('url', isEqualTo: url)
//             .get()
//             .then((snapshot) => snapshot.docs.isNotEmpty
//                 ? snapshot.docs.first['description'] ?? 'No description'
//                 : 'No description'),
//       ]),
//       builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
//         if (snapshot.connectionState == ConnectionState.done &&
//             snapshot.hasData) {
//           final controller = snapshot.data![0] as VideoPlayerController;
//           final description = snapshot.data![1] as String;

//           return InkWell(
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => VideoPlayerScreen(
//                     controller: controller,
//                     description:
//                         description, // Pass description to VideoPlayerScreen
//                   ),
//                 ),
//               );
//             },
//             child: Column(
//               children: [
//                 Stack(
//                   alignment: Alignment.center,
//                   children: [
//                     ClipRect(
//                       child: SizedBox(
//                         width: double.infinity,
//                         height: 200,
//                         child: FittedBox(
//                           fit: BoxFit.cover,
//                           child: SizedBox(
//                             width: controller.value.size.width,
//                             height: controller.value.size.height,
//                             child: VideoPlayer(controller),
//                           ),
//                         ),
//                       ),
//                     ),
//                     const Icon(
//                       Icons.play_circle_fill,
//                       color: Colors.white,
//                       size: 50,
//                     ),
//                   ],
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.all(8.0),
//                   child: Text(
//                     description,
//                     style: const TextStyle(
//                       color: Color(0xff1B1212),
//                       fontSize: 14,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//                 ),
//               ],
//             ),
//           );
//         } else if (snapshot.hasError) {
//           return Container(
//             width: double.infinity,
//             height: 200,
//             color: Colors.black12,
//             child: const Center(
//               child: Text(
//                 'Failed to load video',
//                 style: TextStyle(color: Colors.red),
//               ),
//             ),
//           );
//         } else {
//           return Container(
//             width: double.infinity,
//             height: 200,
//             color: Colors.black12,
//             child: const Center(child: CircularProgressIndicator()),
//           );
//         }
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     bool isOwnProfile = widget.user['uid'] == currentUser!.uid;

//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         backgroundColor: Colors.white,
//         appBar: PreferredSize(
//           preferredSize: const Size.fromHeight(90),
//           child: AppBar(
//             elevation: 0,
//             shadowColor: Colors.white,
//             centerTitle: true,
//             backgroundColor: Colors.white,
//             actions: [
//               IconButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     PageRouteBuilder(
//                       pageBuilder: (context, animation, secondaryAnimation) =>
//                           const Settingsd(),
//                       transitionsBuilder:
//                           (context, animation, secondaryAnimation, child) {
//                         const begin = Offset(1.0, 0.0);
//                         const end = Offset.zero;
//                         const curve = Curves.easeInOut;

//                         var tween = Tween(begin: begin, end: end)
//                             .chain(CurveTween(curve: curve));
//                         return SlideTransition(
//                           position: animation.drive(tween),
//                           child: child,
//                         );
//                       },
//                     ),
//                   );
//                 },
//                 icon: const Icon(Icons.payment, color: Color(0xff1B1212)),
//               ),
//               // IconButton(
//               //   onPressed: () {
//               //     showDialog(
//               //       context: context,
//               //       builder: (context) => AlertDialog(
//               //         backgroundColor: Colors.white,
//               //         content: const Text(
//               //           'Are your sure you want to Logout',
//               //           style: TextStyle(color: Color(0xff1B1212)),
//               //         ),
//               //         title: const Text(
//               //           'Logout',
//               //           style: TextStyle(color: Color(0xff1B1212)),
//               //         ),
//               //         actions: [
//               //           TextButton(
//               //             onPressed: () {
//               //               Navigator.pop(context);
//               //             },
//               //             child: const Text(
//               //               'Cancel',
//               //               style: TextStyle(fontSize: 16, color: Colors.blue),
//               //             ),
//               //           ),
//               //           TextButton(
//               //             onPressed: ()async {
//               //               await FirebaseAuth.instance.signOut(); // Wait for sign-out
//               //               Navigator.pop(context);
//               //               Navigator.pushAndRemoveUntil(
//               //                 context,
//               //                 MaterialPageRoute(
//               //                   builder: (context) => const PopScope(
//               //                     canPop: false,
//               //                     child: Login(),
//               //                   ),
//               //                 ),
//               //                 (route) => false, // Removes all previous routes
//               //               );

//               //             },
//               //             child: const Text(
//               //               'Logout',
//               //               style: TextStyle(fontSize: 16, color: Colors.red),
//               //             ),
//               //           ),
//               //         ],
//               //       ),
//               //     );
//               //   },
//               //   icon: const Icon(Icons.logout_sharp, color: Color(0xff1B1212)),
//               // ),
//               IconButton(
//                 onPressed: () {
//                   showDialog(
//                     context: context,
//                     builder: (context) => AlertDialog(
//                       backgroundColor: Colors.white,
//                       content: const Text(
//                         'Are you sure you want to Logout',
//                         style: TextStyle(color: Color(0xff1B1212)),
//                       ),
//                       title: const Text(
//                         'Logout',
//                         style: TextStyle(color: Color(0xff1B1212)),
//                       ),
//                       actions: [
//                         TextButton(
//                           onPressed: () {
//                             Navigator.pop(context); // Close dialog
//                           },
//                           child: const Text(
//                             'Cancel',
//                             style: TextStyle(fontSize: 16, color: Colors.blue),
//                           ),
//                         ),
//                         TextButton(
//                           onPressed: () async {
//                             try {
//                               await FirebaseAuth.instance
//                                   .signOut(); // Wait for sign-out
//                               if (context.mounted) {
//                                 Navigator.pop(context); // Close dialog
//                                 Navigator.pushAndRemoveUntil(
//                                   context,
//                                   MaterialPageRoute(
//                                     builder: (context) => const PopScope(
//                                       canPop: false,
//                                       child: Login(),
//                                     ),
//                                   ),
//                                   (route) =>
//                                       false, // Removes all previous routes
//                                 );
//                               }
//                             } catch (e) {
//                               if (context.mounted) {
//                                 ScaffoldMessenger.of(context).showSnackBar(
//                                   SnackBar(
//                                     behavior: SnackBarBehavior.floating,
//                                     content: Text('Error logging out: $e'),
//                                     backgroundColor: Colors.red,
//                                   ),
//                                 );
//                               }
//                             }
//                           },
//                           child: const Text(
//                             'Logout',
//                             style: TextStyle(fontSize: 16, color: Colors.red),
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//                 icon: const Icon(Icons.logout_sharp, color: Color(0xff1B1212)),
//               ),
//               IconButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     PageRouteBuilder(
//                       pageBuilder: (context, animation, secondaryAnimation) =>
//                           const Help(),
//                       transitionsBuilder:
//                           (context, animation, secondaryAnimation, child) {
//                         const begin = Offset(1.0, 0.0);
//                         const end = Offset.zero;
//                         const curve = Curves.easeInOut;

//                         var tween = Tween(begin: begin, end: end)
//                             .chain(CurveTween(curve: curve));
//                         return SlideTransition(
//                           position: animation.drive(tween),
//                           child: child,
//                         );
//                       },
//                     ),
//                   );
//                 },
//                 icon: const Icon(Icons.help, color: Color(0xff1B1212)),
//               ),
//             ],
//             automaticallyImplyLeading: false,
//             title: Row(
//               children: [
//                 Consumer(
//                   builder: (context, ref, child) {
//                     final imageUrl =
//                         ref.watch(profileImageProvider) ?? profileImageUrl;
//                     return CircleAvatar(
//                       radius: 20,
//                       backgroundColor: Colors.grey.shade300,
//                       backgroundImage: imageUrl != null && imageUrl.isNotEmpty
//                           ? NetworkImage(imageUrl)
//                           : null,
//                       child: imageUrl == null || imageUrl.isEmpty
//                           ? const Icon(Icons.person, color: Colors.grey)
//                           : null,
//                     );
//                   },
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         currentUser!.displayName ?? 'No Name',
//                         style: const TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                           color: Color(0xff1B1212),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//         body: SingleChildScrollView(
//           child: SafeArea(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 20),
//                   child: OutlinedButton(
//                     style: OutlinedButton.styleFrom(
//                       side:
//                           const BorderSide(color: Color(0xff1B1212), width: 1),
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10)),
//                     ),
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   const EditProfile(),
//                           transitionsBuilder:
//                               (context, animation, secondaryAnimation, child) {
//                             const begin = Offset(1.0, 0.0);
//                             const end = Offset.zero;
//                             const curve = Curves.easeInOut;

//                             var tween = Tween(begin: begin, end: end)
//                                 .chain(CurveTween(curve: curve));
//                             return SlideTransition(
//                               position: animation.drive(tween),
//                               child: child,
//                             );
//                           },
//                         ),
//                       );
//                     },
//                     child: const Text(
//                       'Edit Profile',
//                       style: TextStyle(
//                           color: Color(0xff1B1212),
//                           fontWeight: FontWeight.bold),
//                     ),
//                   ),
//                 ),
//                 if (!isOwnProfile) ...[
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 20),
//                         child: Column(
//                           children: [
//                             const Text(
//                               'Followers',
//                               style: TextStyle(
//                                   fontSize: 20, color: Color(0xff1B1212)),
//                             ),
//                             Text(
//                               followersCount.toString(),
//                               style: const TextStyle(
//                                   fontSize: 17, color: Color(0xff1B1212)),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 20),
//                         child: Column(
//                           children: [
//                             const Text(
//                               'Following',
//                               style: TextStyle(
//                                   fontSize: 20, color: Color(0xff1B1212)),
//                             ),
//                             Text(
//                               followingCount.toString(),
//                               style: const TextStyle(
//                                   fontSize: 17, color: Color(0xff1B1212)),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//                 const Text(
//                   'Introduction Video',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Color(0xff1B1212)),
//                 ),
//                 Column(
//                   children: [
//                     InkWell(
//                       onTap: _videoPicker,
//                       child: Container(
//                         height: 200,
//                         width: double.infinity,
//                         padding: const EdgeInsets.all(10),
//                         margin: const EdgeInsets.symmetric(
//                             horizontal: 10, vertical: 10),
//                         decoration: BoxDecoration(
//                           border:
//                               Border.all(color: Color(0xff1B1212), width: 2),
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: _uploadedVideoUrl != null && !_isVideoLoading
//                             ? _buildVideoThumbnail(_uploadedVideoUrl!)
//                             : const Column(
//                                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(Icons.add,
//                                       size: 40, color: Color(0xff1B1212)),
//                                 ],
//                               ),
//                       ),
//                     ),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.end,
//                       children: [
//                         IconButton(
//                           onPressed: _updateVideo,
//                           icon: const Icon(Icons.update,
//                               color: Color(0xff1B1212)),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 const Text(
//                   'Description',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Color(0xff1B1212)),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.all(8.0),
//                   child: TextFormField(
//                     controller: _controller,
//                     maxLines: null,
//                     readOnly: !_isEditable,
//                     decoration: InputDecoration(
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(10),
//                         borderSide: const BorderSide(
//                             color: Color(0xff1B1212), width: 2),
//                       ),
//                       prefixIcon: IconButton(
//                         icon: const CircleAvatar(
//                           backgroundColor: Color(0xff1B1212),
//                           radius: 15,
//                           child:
//                               Icon(Icons.edit, size: 20, color: Colors.white),
//                         ),
//                         onPressed: () {
//                           setState(() {
//                             _isEditable = true;
//                             _showCheckIcon = true;
//                           });
//                         },
//                       ),
//                       suffixIcon: _showCheckIcon
//                           ? IconButton(
//                               icon: const CircleAvatar(
//                                 backgroundColor: Color(0xff1B1212),
//                                 radius: 15,
//                                 child: Icon(Icons.check, color: Colors.white),
//                               ),
//                               onPressed: () {
//                                 setState(() {
//                                   _isEditable = false;
//                                   _showCheckIcon = false;
//                                 });
//                                 _saveText(_controller.text);
//                               },
//                             )
//                           : null,
//                     ),
//                   ),
//                 ),
//                 StreamBuilder<QuerySnapshot>(
//                   stream: FirebaseFirestore.instance
//                       .collection('posts')
//                       .where('userId', isEqualTo: widget.user['uid'])
//                       .orderBy('createdAt', descending: true)
//                       .snapshots(),
//                   builder: (context, snapshot) {
//                     if (snapshot.connectionState == ConnectionState.waiting) {
//                       return const Center(
//                           child: CircularProgressIndicator(
//                         color: Color(0xff1B1212),
//                         backgroundColor: Colors.white,
//                       ));
//                     }
//                     if (snapshot.hasError) {
//                       return Center(child: Text('Error: ${snapshot.error}'));
//                     }
//                     if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                       return const Center(child: Text('No posts available'));
//                     }

//                     imageUrls.clear();
//                     videoUrls.clear();

//                     for (var doc in snapshot.data!.docs) {
//                       final data = doc.data() as Map<String, dynamic>;
//                       final mediaFiles =
//                           List<String>.from(data['mediaFiles'] ?? []);
//                       for (var url in mediaFiles) {
//                         if (url.toLowerCase().endsWith('.jpg') ||
//                             url.toLowerCase().endsWith('.jpeg') ||
//                             url.toLowerCase().endsWith('.png')) {
//                           imageUrls.add(url);
//                         } else if (url.toLowerCase().endsWith('.mp4')) {
//                           videoUrls.add(url);
//                           if (!_videoControllers.containsKey(url)) {
//                             _initializeVideo(url).then((controller) {
//                               setState(() {
//                                 _videoControllers[url] = controller;
//                               });
//                             });
//                           }
//                         }
//                       }
//                     }

//                     return Column(
//                       children: [
//                         const TabBar(
//                           indicatorColor: Color(0xff1B1212),
//                           labelColor: Color(0xff1B1212),
//                           unselectedLabelColor: Colors.grey,
//                           tabs: [
//                             Tab(icon: Icon(Icons.image, size: 30)),
//                             Tab(icon: Icon(Icons.video_library, size: 30)),
//                           ],
//                         ),
//                         SizedBox(
//                           height: 400,
//                           child: TabBarView(
//                             children: [
//                               GridView.builder(
//                                 itemCount: imageUrls.length,
//                                 gridDelegate:
//                                     const SliverGridDelegateWithFixedCrossAxisCount(
//                                   crossAxisCount: 3,
//                                   childAspectRatio: 0.8,
//                                 ),
//                                 itemBuilder: (context, index) => Padding(
//                                   padding: const EdgeInsets.all(5),
//                                   child: ClipRRect(
//                                     borderRadius: BorderRadius.circular(10),
//                                     child: Image.network(imageUrls[index],
//                                         fit: BoxFit.cover),
//                                   ),
//                                 ),
//                               ),
//                               GridView.builder(
//                                 itemCount: videoUrls.length,
//                                 gridDelegate:
//                                     const SliverGridDelegateWithFixedCrossAxisCount(
//                                   crossAxisCount: 3,
//                                   childAspectRatio: 0.8,
//                                 ),
//                                 itemBuilder: (context, index) => Padding(
//                                   padding: const EdgeInsets.all(5),
//                                   child: ClipRRect(
//                                     borderRadius: BorderRadius.circular(10),
//                                     child:
//                                         _buildVideoThumbnail(videoUrls[index]),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     );
//                   },
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class VideoPlayerScreen extends StatefulWidget {
//   final VideoPlayerController controller;
//   final String description;

//   const VideoPlayerScreen({
//     super.key,
//     required this.controller,
//     required this.description,
//   });

//   @override
//   State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
// }

// class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
//   @override
//   void initState() {
//     super.initState();
//     widget.controller.setLooping(true);
//   }

//   @override
//   void dispose() {
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Video Player')),
//       body: Column(
//         children: [
//           AspectRatio(
//             aspectRatio: widget.controller.value.aspectRatio,
//             child: Stack(
//               alignment: Alignment.bottomCenter,
//               children: [
//                 VideoPlayer(widget.controller),
//                 VideoProgressIndicator(widget.controller, allowScrubbing: true),
//                 IconButton(
//                   icon: Icon(
//                     widget.controller.value.isPlaying
//                         ? Icons.pause
//                         : Icons.play_arrow,
//                     color: Colors.white,
//                     size: 50,
//                   ),
//                   onPressed: () {
//                     setState(() {
//                       if (widget.controller.value.isPlaying) {
//                         widget.controller.pause();
//                       } else {
//                         widget.controller.play();
//                       }
//                     });
//                   },
//                 ),
//               ],
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Text(
//               widget.description,
//               style: const TextStyle(
//                 color: Color(0xff1B1212),
//                 fontSize: 16,
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spokencafe/model/Account/Log/Login.dart';
import 'package:spokencafe/profile/Edit_Profile/Edit_Profile.dart';
import 'package:spokencafe/profile/Help/Help.dart';
import 'package:spokencafe/profile/settings/settings.dart';
import 'package:video_player/video_player.dart';

// Assuming profileImageProvider is defined elsewhere
final profileImageProvider = StateProvider<String?>((ref) => null);

class Profile extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final bool isTeacher;

  const Profile({super.key, required this.user, required this.isTeacher});

  @override
  ConsumerState<Profile> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<Profile> {
  final TextEditingController _controller = TextEditingController();
  late String uid;
  bool _isEditable = false;
  bool _showCheckIcon = false;
  bool isLoading = false;
  String? userName;
  bool isFollowing = false;
  File? _imageFile;
  Uint8List? pickedImage;
  late User currentUser;
  String? profileImageUrl;
  int followersCount = 0;
  int followingCount = 0;
  List<String> imageUrls = [];
  List<String> videoUrls = [];
  StreamSubscription? _followStatusSubscription;
  StreamSubscription? _followersCountSubscription;
  StreamSubscription? _followingCountSubscription;
  String? _uploadedVideoUrl;
  String? _currentVideoDocId;
  final Map<String, VideoPlayerController> _videoControllers = {};
  bool _isVideoLoading = true;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser!;
    uid = currentUser.uid;
    _loadText();
    _loadUserName();
    _initUser();
    _setupFollowStatusListener();
    _setupFollowersCountListener();
    _setupFollowingCountListener();
    _loadExistingIntroVideo();
  }

  /// Fetch the latest intro video + description from Firestore
  Future<void> _loadExistingIntroVideo() async {
    final snap = await FirebaseFirestore.instance
        .collection('media')
        .where('userId', isEqualTo: uid)
        .where('type', isEqualTo: 'video')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final doc = snap.docs.first;
      _uploadedVideoUrl = doc['url'] as String?;
      _currentVideoDocId = doc.id;
      if (_uploadedVideoUrl != null) {
        await _initializeVideo(_uploadedVideoUrl!);
      }
    }
    setState(() => _isVideoLoading = false);
  }

  void _setupFollowStatusListener() {
    if (currentUser.uid != widget.user['uid']) {
      _followStatusSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user['uid'])
          .collection('followers')
          .doc(currentUser.uid)
          .snapshots()
          .listen((snapshot) {
        if (mounted) setState(() => isFollowing = snapshot.exists);
      });
    }
  }

  void _setupFollowersCountListener() {
    _followersCountSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user['uid'])
        .collection('followers')
        .snapshots()
        .listen((snapshot) {
      if (mounted) setState(() => followersCount = snapshot.size);
    });
  }

  void _setupFollowingCountListener() {
    _followingCountSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user['uid'])
        .collection('following')
        .snapshots()
        .listen((snapshot) {
      if (mounted) setState(() => followingCount = snapshot.size);
    });
  }

  @override
  void dispose() {
    _followStatusSubscription?.cancel();
    _followersCountSubscription?.cancel();
    _followingCountSubscription?.cancel();
    _controller.dispose();
    for (var c in _videoControllers.values) {
      c.dispose();
    }
    _videoControllers.clear();
    super.dispose();
  }

  Future<void> _toggleFollow() async {
    try {
      if (currentUser.uid == widget.user['uid']) return;
      setState(() => isLoading = true);

      final batch = FirebaseFirestore.instance.batch();
      final followersRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user['uid'])
          .collection('followers')
          .doc(currentUser.uid);
      final followingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('following')
          .doc(widget.user['uid']);

      if (isFollowing) {
        batch.delete(followersRef);
        batch.delete(followingRef);
      } else {
        batch.set(followersRef, {'timestamp': FieldValue.serverTimestamp()});
        batch.set(followingRef, {'timestamp': FieldValue.serverTimestamp()});
      }
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadUserName() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          userName = userDoc['userName'] ?? 'Loading...';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        userName = 'Error loading user data';
        isLoading = false;
      });
    }
  }

  Future<void> _initUser() async => _fetchProfileImageUrl();

  Future<void> _fetchProfileImageUrl() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (userDoc.exists && userDoc['profileImageUrl'] != null) {
        setState(() => profileImageUrl = userDoc['profileImageUrl']);
      }
    } catch (_) {}
  }

  Future<void> _loadText() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('saved_text');
    if (saved != null && saved.isNotEmpty) {
      _controller.text = saved;
    } else {
      await _fetchDescription();
    }
  }

  Future<void> _fetchDescription() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(widget.isTeacher
              ? 'teacher_description'
              : 'student_description')
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        _controller.text = doc.data()!['description'] ?? '';
      }
    } catch (_) {}
  }

  Future<void> _saveText(String description) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_text', description);
      final col = widget.isTeacher
          ? 'teacher_description'
          : 'student_description';
      await FirebaseFirestore.instance.collection(col).doc(currentUser.uid).set({
        'description': description.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'uid': currentUser.uid,
        'email': currentUser.email,
      }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          content: Text('Description saved successfully'),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          content: Text('Failed to save description'),
        ),
      );
    }
  }

  Future<void> _videoPicker() async {
    try {
      setState(() => isLoading = true);
      final picked =
          await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        final file = File(picked.path);
        final path =
            'videos/${currentUser.uid}/${DateTime.now().millisecondsSinceEpoch}.mp4';
        final ref = FirebaseStorage.instance.ref().child(path);
        final snap = await ref.putFile(file);
        final url = await snap.ref.getDownloadURL();

        final desc = "Sample video description";
        final docRef =
            await FirebaseFirestore.instance.collection('media').add({
          'userId': currentUser.uid,
          'url': url,
          'type': 'video',
          'description': desc,
          'timestamp': FieldValue.serverTimestamp(),
        });

        setState(() {
          _uploadedVideoUrl = url;
          _currentVideoDocId = docRef.id;
          _isVideoLoading = true;
        });
        await _initializeVideo(url);
        setState(() => _isVideoLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Error uploading video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _updateVideo() async {
    try {
      setState(() => isLoading = true);
      final picked =
          await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        final file = File(picked.path);
        final path =
            'videos/${currentUser.uid}/${DateTime.now().millisecondsSinceEpoch}.mp4';
        final ref = FirebaseStorage.instance.ref().child(path);
        final snap = await ref.putFile(file);
        final url = await snap.ref.getDownloadURL();

        final desc = "Updated video description";
        final old = _uploadedVideoUrl;
        if (_currentVideoDocId != null) {
          await FirebaseFirestore.instance
              .collection('media')
              .doc(_currentVideoDocId)
              .update({
            'url': url,
            'description': desc,
            'timestamp': FieldValue.serverTimestamp(),
          });
        } else {
          final docRef =
              await FirebaseFirestore.instance.collection('media').add({
            'userId': currentUser.uid,
            'url': url,
            'type': 'video',
            'description': desc,
            'timestamp': FieldValue.serverTimestamp(),
          });
          _currentVideoDocId = docRef.id;
        }

        setState(() {
          _uploadedVideoUrl = url;
          _isVideoLoading = true;
        });
        await _initializeVideo(url);
        setState(() => _isVideoLoading = false);

        if (old != null) {
          try {
            await FirebaseStorage.instance.refFromURL(old).delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Error updating video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<VideoPlayerController> _initializeVideo(String url) async {
    if (_videoControllers.containsKey(url)) {
      final c = _videoControllers[url]!;
      if (c.value.isInitialized) return c;
      c.dispose();
      _videoControllers.remove(url);
    }
    final file = await DefaultCacheManager().getSingleFile(url);
    final ctrl = VideoPlayerController.file(file);
    _videoControllers[url] = ctrl;
    await ctrl.initialize();
    return ctrl;
  }

  Widget _buildVideoThumbnail(String url) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _initializeVideo(url),
        FirebaseFirestore.instance
            .collection('media')
            .where('url', isEqualTo: url)
            .get()
            .then((snap) => snap.docs.isNotEmpty
                ? snap.docs.first['description'] ?? 'No description'
                : 'No description'),
      ]),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.done && snap.hasData) {
          final ctrl = snap.data![0] as VideoPlayerController;
          final desc = snap.data![1] as String;
          return InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    VideoPlayerScreen(controller: ctrl, description: desc),
              ),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRect(
                      child: SizedBox(
                        width: double.infinity,
                        height: 200,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: ctrl.value.size.width,
                            height: ctrl.value.size.height,
                            child: VideoPlayer(ctrl),
                          ),
                        ),
                      ),
                    ),
                    const Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 50),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    desc,
                    style: const TextStyle(
                        color: Color(0xff1B1212), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        } else if (snap.hasError) {
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.black12,
            child: const Center(
              child: Text('Failed to load video',
                  style: TextStyle(color: Colors.red)),
            ),
          );
        }
        return Container(
          width: double.infinity,
          height: 200,
          color: Colors.black12,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = widget.user['uid'] == currentUser.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: AppBar(
            elevation: 0,
            shadowColor: Colors.white,
            centerTitle: true,
            backgroundColor: Colors.white,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const Settingsd(),
                    transitionsBuilder: (_, anim, __, child) {
                      return SlideTransition(
                        position: anim.drive(
                          Tween(begin: const Offset(1, 0), end: Offset.zero)
                              .chain(CurveTween(curve: Curves.easeInOut)),
                        ),
                        child: child,
                      );
                    },
                  ),
                ),
                icon: const Icon(Icons.payment, color: Color(0xff1B1212)),
              ),
              IconButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: Colors.white,
                    title: const Text('Logout',
                        style: TextStyle(color: Color(0xff1B1212))),
                    content: const Text('Are you sure you want to Logout',
                        style: TextStyle(color: Color(0xff1B1212))),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child:
                            const Text('Cancel', style: TextStyle(color: Colors.blue)),
                      ),
                      TextButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.pop(context);
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const PopScope(canPop: false, child: Login())),
                              (_) => false,
                            );
                          }
                        },
                        child:
                            const Text('Logout', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.logout_sharp, color: Color(0xff1B1212)),
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const Help(),
                    transitionsBuilder: (_, anim, __, child) {
                      return SlideTransition(
                        position: anim.drive(
                          Tween(begin: const Offset(1, 0), end: Offset.zero)
                              .chain(CurveTween(curve: Curves.easeInOut)),
                        ),
                        child: child,
                      );
                    },
                  ),
                ),
                icon: const Icon(Icons.help, color: Color(0xff1B1212)),
              ),
            ],
            title: Row(
              children: [
                Consumer(builder: (ctx, ref, child) {
                  final imageUrl =
                      ref.watch(profileImageProvider) ?? profileImageUrl;
                  return CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(imageUrl)
                        : null,
                    child: (imageUrl == null || imageUrl.isEmpty)
                        ? const Icon(Icons.person, color: Colors.grey)
                        : null,
                  );
                }),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentUser.displayName ?? 'No Name',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1B1212),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xff1B1212), width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const EditProfile(),
                        transitionsBuilder: (_, anim, __, child) {
                          return SlideTransition(
                            position: anim.drive(
                              Tween(begin: const Offset(1, 0), end: Offset.zero)
                                  .chain(CurveTween(curve: Curves.easeInOut)),
                            ),
                            child: child,
                          );
                        },
                      ),
                    ),
                    child: const Text(
                      'Edit Profile',
                      style: TextStyle(
                          color: Color(0xff1B1212),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (!isOwnProfile) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            const Text(
                              'Followers',
                              style: TextStyle(
                                  fontSize: 20, color: Color(0xff1B1212)),
                            ),
                            Text(
                              followersCount.toString(),
                              style: const TextStyle(
                                  fontSize: 17, color: Color(0xff1B1212)),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            const Text(
                              'Following',
                              style: TextStyle(
                                  fontSize: 20, color: Color(0xff1B1212)),
                            ),
                            Text(
                              followingCount.toString(),
                              style: const TextStyle(
                                  fontSize: 17, color: Color(0xff1B1212)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const Text(
                  'Introduction Video',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1B1212)),
                ),
                Column(
                  children: [
                    InkWell(
                      onTap: _videoPicker,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xff1B1212), width: 2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _uploadedVideoUrl != null && !_isVideoLoading
                            ? _buildVideoThumbnail(_uploadedVideoUrl!)
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add,
                                      size: 40, color: Color(0xff1B1212)),
                                ],
                              ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: _updateVideo,
                          icon: const Icon(Icons.update,
                              color: Color(0xff1B1212)),
                        ),
                      ],
                    ),
                  ],
                ),
                const Text(
                  'Description',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff1B1212)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    controller: _controller,
                    maxLines: null,
                    readOnly: !_isEditable,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xff1B1212), width: 2),
                      ),
                      prefixIcon: IconButton(
                        icon: const CircleAvatar(
                          backgroundColor: Color(0xff1B1212),
                          radius: 15,
                          child:
                              Icon(Icons.edit, size: 20, color: Colors.white),
                        ),
                        onPressed: () {
                          setState(() {
                            _isEditable = true;
                            _showCheckIcon = true;
                          });
                        },
                      ),
                      suffixIcon: _showCheckIcon
                          ? IconButton(
                              icon: const CircleAvatar(
                                backgroundColor: Color(0xff1B1212),
                                radius: 15,
                                child: Icon(Icons.check, color: Colors.white),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isEditable = false;
                                  _showCheckIcon = false;
                                });
                                _saveText(_controller.text);
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // *** your existing StreamBuilder of 'posts' goes here exactly as before, unmodified ***
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('userId', isEqualTo: widget.user['uid'])
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                        color: Color(0xff1B1212),
                        backgroundColor: Colors.white,
                      ));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No posts available'));
                    }

                    imageUrls.clear();
                    videoUrls.clear();

                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final mediaFiles =
                          List<String>.from(data['mediaFiles'] ?? []);
                      for (var url in mediaFiles) {
                        if (url.toLowerCase().endsWith('.jpg') ||
                            url.toLowerCase().endsWith('.jpeg') ||
                            url.toLowerCase().endsWith('.png')) {
                          imageUrls.add(url);
                        } else if (url.toLowerCase().endsWith('.mp4')) {
                          videoUrls.add(url);
                          if (!_videoControllers.containsKey(url)) {
                            _initializeVideo(url).then((controller) {
                              setState(() {
                                _videoControllers[url] = controller;
                              });
                            });
                          }
                        }
                      }
                    }

                    return Column(
                      children: [
                        const TabBar(
                          indicatorColor: Color(0xff1B1212),
                          labelColor: Color(0xff1B1212),
                          unselectedLabelColor: Colors.grey,
                          tabs: [
                            Tab(icon: Icon(Icons.image, size: 30)),
                            Tab(icon: Icon(Icons.video_library, size: 30)),
                          ],
                        ),
                        SizedBox(
                          height: 400,
                          child: TabBarView(
                            children: [
                              GridView.builder(
                                itemCount: imageUrls.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 0.8,
                                ),
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(imageUrls[index],
                                        fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                              GridView.builder(
                                itemCount: videoUrls.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 0.8,
                                ),
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: _buildVideoThumbnail(videoUrls[index]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final VideoPlayerController controller;
  final String description;

  const VideoPlayerScreen({
    super.key,
    required this.controller,
    required this.description,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.setLooping(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Player')),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: widget.controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                VideoPlayer(widget.controller),
                VideoProgressIndicator(widget.controller, allowScrubbing: true),
                IconButton(
                  icon: Icon(
                    widget.controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                  onPressed: () => setState(() {
                    if (widget.controller.value.isPlaying) {
                      widget.controller.pause();
                    } else {
                      widget.controller.play();
                    }
                  }),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.description,
              style: const TextStyle(
                color: Color(0xff1B1212),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
