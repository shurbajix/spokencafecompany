// import 'dart:ui';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:spokencafe/model/Account/Log/Login.dart';
// import 'package:video_player/video_player.dart';
// import '../../../Credit_Card/Credit_Card.dart';
// import '../../../profile/Edit_Profile/Edit_Profile.dart';
// import '../../../profile/Help/Help.dart';

// final profileImageProvider = StateProvider<String?>((ref) => null);

// class ProfileStudent extends ConsumerStatefulWidget {
//   final Map<String, dynamic> user;
//   const ProfileStudent(this.user, {super.key});

//   @override
//   ConsumerState<ProfileStudent> createState() => _ProfileStudentState();
// }

// class _ProfileStudentState extends ConsumerState<ProfileStudent> {
//   late Map<String, dynamic> user;
//   final TextEditingController _controller = TextEditingController();
//   bool _isEditable = false;
//   bool _showCheckIcon = false;
//   bool isLoading = false;
//   bool isFollowing = false;
//   int followersCount = 0;
//   int followingCount = 0;
//   String? profileImageUrl;
//   final currentUser = FirebaseAuth.instance.currentUser!;
//   List<String> imageUrls = [];
//   List<String> videoUrls = [];

//   @override
//   void initState() {
//     super.initState();
//     user = widget.user;
//     _loadDescription();
//     _loadFollowCounts();
//     _checkFollowingStatus();
//     _loadFilesFromFirestore();
//     _fetchProfileImageUrl();
//      ref.listenManual(profileImageProvider, (previous, next) {
//     if (next != null && next.isNotEmpty) {
//       setState(() {
//         profileImageUrl = next;
//       });
//     }
//   });
//   }

//   Future<void> _loadFollowCounts() async {
//     try {
//       final followersSnapshot = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(user['uid'])
//           .collection('followers')
//           .get();

//       final followingSnapshot = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(user['uid'])
//           .collection('following')
//           .get();

//       setState(() {
//         followersCount = followersSnapshot.size;
//         followingCount = followingSnapshot.size;
//       });
//     } catch (e) {
//       print('Error loading follow counts: $e');
//     }
//   }

//   Future<void> _fetchProfileImageUrl() async {
//     try {
//       DocumentSnapshot userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(currentUser.uid)
//           .get();

//       if (userDoc.exists && userDoc['profileImageUrl'] != null) {
//         setState(() {
//           profileImageUrl = userDoc['profileImageUrl'];
//         });
//         ref.read(profileImageProvider.notifier).state = userDoc['profileImageUrl'];
//       }
//     } catch (e) {
//       print('Error fetching profile image URL: $e');
//     }
//   }

//   Future<void> _checkFollowingStatus() async {
//     try {
//       if (currentUser.uid == user['uid']) return;

//       final followSnapshot = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(user['uid'])
//           .collection('followers')
//           .doc(currentUser.uid)
//           .get();

//       setState(() => isFollowing = followSnapshot.exists);
//     } catch (e) {
//       print('Error checking following status: $e');
//     }
//   }

//   Future<void> _toggleFollow() async {
//     try {
//       if (currentUser.uid == user['uid']) return;

//       setState(() => isLoading = true);

//       final followersRef = FirebaseFirestore.instance
//           .collection('users')
//           .doc(user['uid'])
//           .collection('followers')
//           .doc(currentUser.uid);

//       if (isFollowing) {
//         await followersRef.delete();
//       } else {
//         await followersRef.set({'timestamp': FieldValue.serverTimestamp()});
//       }

//       await _loadFollowCounts();
//       setState(() => isFollowing = !isFollowing);
//     } catch (e) {
//       print('Follow operation failed: $e');
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   Future<void> _saveDescription(String description) async {
//     try {
//       await FirebaseFirestore.instance
//           .collection('student_description')
//           .doc(currentUser.uid)
//           .set({
//             'description': description,
//             'timestamp': FieldValue.serverTimestamp(),
//             'uid': currentUser.uid,
//             'email': currentUser.email,
//             'displayName': currentUser.displayName ?? '',
//           });

//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       await prefs.setString('user_description', description);

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Description saved successfully'),
//           backgroundColor: Colors.green,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     } catch (e) {
//       print('Error saving description: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Failed to save description'),
//           backgroundColor: Colors.red,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     }
//   }

//   Future<void> _loadDescription() async {
//     try {
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       String? localDescription = prefs.getString('user_description');

//       if (localDescription != null && localDescription.isNotEmpty) {
//         _controller.text = localDescription;
//       } else {
//         DocumentSnapshot doc = await FirebaseFirestore.instance
//             .collection('student_description')
//             .doc(currentUser.uid)
//             .get();

//         if (doc.exists && doc['description'] != null) {
//           String firestoreDescription = doc['description'];
//           _controller.text = firestoreDescription;
//           await prefs.setString('user_description', firestoreDescription);
//         }
//       }
//     } catch (e) {
//       print('Error loading description: $e');
//     }
//   }

//   Future<void> _loadFilesFromFirestore() async {
//     final snapshot = await FirebaseFirestore.instance
//         .collection('media')
//         .orderBy('timestamp', descending: true)
//         .get();

//     final images = <String>[];
//     final videos = <String>[];

//     for (var doc in snapshot.docs) {
//       final data = doc.data();
//       final url = data['url'];
//       final type = data['type'];

//       if (type == 'image') {
//         images.add(url);
//       } else if (type == 'video') {
//         videos.add(url);
//       }
//     }

//     setState(() {
//       imageUrls = images;
//       videoUrls = videos;
//     });
//   }

//   Widget _buildVideoThumbnail(String url) {
//     return FutureBuilder(
//       future: _initializeVideo(url),
//       builder: (context, AsyncSnapshot<VideoPlayerController> snapshot) {
//         if (snapshot.connectionState == ConnectionState.done &&
//             snapshot.hasData) {
//           final controller = snapshot.data!;
//           return Stack(
//             alignment: Alignment.center,
//             children: [
//               AspectRatio(
//                 aspectRatio: controller.value.aspectRatio,
//                 child: VideoPlayer(controller),
//               ),
//               const Icon(
//                 Icons.play_circle_fill,
//                 color: Colors.white,
//                 size: 50,
//               ),
//             ],
//           );
//         } else {
//           return Container(
//             color: Colors.black12,
//             child: const Center(child: CircularProgressIndicator()),
//           );
//         }
//       },
//     );
//   }

//   Future<VideoPlayerController> _initializeVideo(String url) async {
//     final controller = VideoPlayerController.network(url);
//     await controller.initialize();
//     return controller;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isOwnProfile = currentUser.uid == user['uid'];

//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         backgroundColor: Colors.white,
//         appBar: PreferredSize(
//           preferredSize: const Size.fromHeight(90),
//           child: AppBar(
//             shadowColor: Colors.white,
//             centerTitle: true,
//             backgroundColor: Colors.white,
//             automaticallyImplyLeading: false,
//             actions: [
//               TextButton.icon(
//                 onPressed: () => Navigator.push(
//                   context,
//                   PageRouteBuilder(
//                     pageBuilder: (context, animation, secondaryAnimation) =>
//                         const CreditCard(),
//                     transitionsBuilder:
//                         (context, animation, secondaryAnimation, child) {
//                       const begin = Offset(1.0, 0.0);
//                       const end = Offset.zero;
//                       const curve = Curves.easeInOut;
//                       var tween = Tween(begin: begin, end: end)
//                           .chain(CurveTween(curve: curve));
//                       return SlideTransition(
//                         position: animation.drive(tween),
//                         child: child,
//                       );
//                     },
//                   ),
//                 ),
//                 label: const Text(
//                   'Add Card',
//                   style: TextStyle(color: Color(0xff1B1212)),
//                 ),
//                 icon: const Icon(Icons.credit_card, color: Color(0xff1B1212)),
//               ),
//               IconButton(
//                 onPressed: () => showDialog(
//                   context: context,
//                   builder: (context) => AlertDialog(
//                     backgroundColor: Colors.white,
//                     content: const Text('Are you sure you want to Logout?',
//                         style: TextStyle(
//                           color: Color(0xff1B1212),
//                         ),),
//                     title: const Text('Logout',
//                         style: TextStyle(
//                           color: Color(0xff1B1212),
//                         ),),
//                     actions: [
//                       TextButton(
//                         onPressed: () => Navigator.pop(context),
//                         child: const Text(
//                           'Cancel',
//                           style: TextStyle(color: Colors.blue),
//                         ),
//                       ),
//                       TextButton(
//                         onPressed: () {
//                           FirebaseAuth.instance.signOut();
//                           Navigator.pushReplacement(
//                             context,
//                             MaterialPageRoute(
//                               builder: (_) => const PopScope(
//                                 canPop: false,
//                                 child: Login(),
//                               ),
//                             ),
//                           );
//                         },
//                         child: const Text(
//                           'Logout',
//                           style: TextStyle(color: Colors.red),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 icon: const Icon(Icons.logout_sharp, color: Color(0xff1B1212)),
//               ),
//               IconButton(
//                 onPressed: () => Navigator.push(
//                   context,
//                   PageRouteBuilder(
//                     pageBuilder: (context, animation, secondaryAnimation) =>
//                         const Help(),
//                     transitionsBuilder:
//                         (context, animation, secondaryAnimation, child) {
//                       const begin = Offset(1.0, 0.0);
//                       const end = Offset.zero;
//                       const curve = Curves.easeInOut;
//                       var tween = Tween(begin: begin, end: end)
//                           .chain(CurveTween(curve: curve));
//                       return SlideTransition(
//                         position: animation.drive(tween),
//                         child: child,
//                       );
//                     },
//                   ),
//                 ),
//                 icon: const Icon(Icons.help, color: Color(0xff1B1212)),
//               ),
//             ],
//             title: Row(
//               children: [
//                 Consumer(
//                   builder: (context, ref, child) {
//                     final imageUrl = ref.watch(profileImageProvider) ?? profileImageUrl;
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
//                         currentUser.displayName ?? 'No Name',
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
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         PageRouteBuilder(
//                           pageBuilder: (context, animation, secondaryAnimation) =>
//                               EditProfile(),
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
//                         color: Color(0xff1B1212),
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     style: OutlinedButton.styleFrom(
//                       side: const BorderSide(color: Color(0xff1B1212), width: 1),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                   ),
//                 ),
//                 if (!isOwnProfile) ...[
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: List.generate(
//                       2,
//                       (index) => Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 20),
//                         child: Column(
//                           children: [
//                             Text(
//                               index == 0 ? 'Followers' : 'Following',
//                               style: const TextStyle(
//                                 fontSize: 20,
//                                 color: Color(0xff1B1212),
//                               ),
//                             ),
//                             Text(
//                               index == 0
//                                   ? followersCount.toString()
//                                   : followingCount.toString(),
//                               style: const TextStyle(
//                                 fontSize: 17,
//                                 color: Color(0xff1B1212),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//                 const Text(
//                   'Description',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Color(0xff1B1212),
//                   ),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.all(20.0),
//                   child: TextFormField(
//                     controller: _controller,
//                     maxLines: null,
//                     readOnly: !_isEditable,
//                     decoration: InputDecoration(
//                       border: OutlineInputBorder(
//                         borderSide: BorderSide(
//                           color: Color(0xff1B1212),
//                           width: 2,
//                         ),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       prefixIcon: IconButton(
//                         onPressed: () {
//                           setState(() {
//                             _isEditable = true;
//                             _showCheckIcon = true;
//                           });
//                         },
//                         icon: const CircleAvatar(
//                           backgroundColor: Color(0xff1B1212),
//                           radius: 15,
//                           child: Icon(Icons.edit, size: 20, color: Colors.white,),
//                         ),
//                       ),
//                       suffixIcon: _showCheckIcon
//                           ? IconButton(
//                               onPressed: () {
//                                 setState(() {
//                                   _isEditable = false;
//                                   _showCheckIcon = false;
//                                 });
//                                 _saveDescription(_controller.text);
//                               },
//                               icon: const CircleAvatar(
//                                 radius: 15,
//                                 backgroundColor: Color(0xff1B1212),
//                                 child: Icon(Icons.check, color: Colors.white),
//                               ),
//                             )
//                           : null,
//                     ),
//                   ),
//                 ),
               
//                Column(
//                     children: [
//                       const TabBar(
//                         indicatorColor: Color(0xff1B1212),
//                         labelColor: Color(0xff1B1212),
//                         unselectedLabelColor: Colors.grey,
//                         tabs: [
//                           Tab(icon: Icon(Icons.image, size: 30)),
//                           Tab(icon: Icon(Icons.video_library, size: 30)),
//                         ],
//                       ),
//                       SizedBox(
//                         height: 400,
//                         child: TabBarView(
//                           children: [
//                             GridView.builder(
//                               itemCount: imageUrls.length,
//                               gridDelegate:
//                                   const SliverGridDelegateWithFixedCrossAxisCount(
//                                 crossAxisCount: 3,
//                                 childAspectRatio: 0.8,
//                               ),
//                               itemBuilder: (context, index) => Padding(
//                                 padding: const EdgeInsets.all(5),
//                                 child: ClipRRect(
//                                   borderRadius: BorderRadius.circular(10),
//                                   child: Image.network(
//                                     imageUrls[index],
//                                     fit: BoxFit.cover,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                             GridView.builder(
//                               itemCount: videoUrls.length,
//                               gridDelegate:
//                                   const SliverGridDelegateWithFixedCrossAxisCount(
//                                 crossAxisCount: 3,
//                                 childAspectRatio: 0.8,
//                               ),
//                               itemBuilder: (context, index) => Padding(
//                                 padding: const EdgeInsets.all(5),
//                                 child: ClipRRect(
//                                   borderRadius: BorderRadius.circular(10),
//                                   child: _buildVideoThumbnail(videoUrls[index]),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spokencafe/model/Account/Log/Login.dart';
import 'package:video_player/video_player.dart';
import '../../../Credit_Card/Credit_Card.dart';
import '../../../profile/Edit_Profile/Edit_Profile.dart';
import '../../../profile/Help/Help.dart';

final profileImageProvider = StateProvider<String?>((ref) => null);

class ProfileStudent extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  const ProfileStudent(this.user, {super.key});

  @override
  ConsumerState<ProfileStudent> createState() => _ProfileStudentState();
}

class _ProfileStudentState extends ConsumerState<ProfileStudent> {
  late Map<String, dynamic> user;
  final TextEditingController _controller = TextEditingController();
  bool _isEditable = false;
  bool _showCheckIcon = false;
  bool isLoading = false;
  bool isFollowing = false;
  int followersCount = 0;
  int followingCount = 0;
  final currentUser = FirebaseAuth.instance.currentUser!;
  List<String> imageUrls = [];
  List<String> videoUrls = [];

  @override
  void initState() {
    super.initState();
    user = widget.user;
    _loadDescription();
    _loadFollowCounts();
    _checkFollowingStatus();
    _loadFilesFromFirestore();
    _fetchProfileImageUrl();
  }

  Future<void> _loadFollowCounts() async {
    try {
      final followersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user['uid'])
          .collection('followers')
          .get();

      final followingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user['uid'])
          .collection('following')
          .get();

      setState(() {
        followersCount = followersSnapshot.size;
        followingCount = followingSnapshot.size;
      });
    } catch (e) {
      print('Error loading follow counts: $e');
    }
  }

Future<void> _fetchProfileImageUrl() async {
  try {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    if (userDoc.exists && userDoc['profileImageUrl'] != null) {
      // Update the provider state
      ref.read(profileImageProvider.notifier).state = userDoc['profileImageUrl'];
    }
  } catch (e) {
    print('Error fetching profile image URL: $e');
  }
}

  Future<void> _checkFollowingStatus() async {
    try {
      if (currentUser.uid == user['uid']) return;

      final followSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user['uid'])
          .collection('followers')
          .doc(currentUser.uid)
          .get();

      setState(() => isFollowing = followSnapshot.exists);
    } catch (e) {
      print('Error checking following status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    try {
      if (currentUser.uid == user['uid']) return;

      setState(() => isLoading = true);

      final followersRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user['uid'])
          .collection('followers')
          .doc(currentUser.uid);

      if (isFollowing) {
        await followersRef.delete();
      } else {
        await followersRef.set({'timestamp': FieldValue.serverTimestamp()});
      }

      await _loadFollowCounts();
      setState(() => isFollowing = !isFollowing);
    } catch (e) {
      print('Follow operation failed: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveDescription(String description) async {
    try {
      await FirebaseFirestore.instance
          .collection('student_description')
          .doc(currentUser.uid)
          .set({
            'description': description,
            'timestamp': FieldValue.serverTimestamp(),
            'uid': currentUser.uid,
            'email': currentUser.email,
            'displayName': currentUser.displayName ?? '',
          });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_description', description);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Description saved successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Error saving description: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save description'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  

  Future<void> _loadDescription() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? localDescription = prefs.getString('user_description');

      if (localDescription != null && localDescription.isNotEmpty) {
        _controller.text = localDescription;
      } else {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('student_description')
            .doc(currentUser.uid)
            .get();

        if (doc.exists && doc['description'] != null) {
          String firestoreDescription = doc['description'];
          _controller.text = firestoreDescription;
          await prefs.setString('user_description', firestoreDescription);
        }
      }
    } catch (e) {
      print('Error loading description: $e');
    }
  }

  // Future<void> _loadFilesFromFirestore() async {
  //   final snapshot = await FirebaseFirestore.instance
  //       .collection('media')
  //       .orderBy('timestamp', descending: true)
  //       .get();

  //   final images = <String>[];
  //   final videos = <String>[];

  //   for (var doc in snapshot.docs) {
  //     final data = doc.data();
  //     final url = data['url'];
  //     final type = data['type'];

  //     if (type == 'image') {
  //       images.add(url);
  //     } else if (type == 'video') {
  //       videos.add(url);
  //     }
  //   }

  //   setState(() {
  //     imageUrls = images;
  //     videoUrls = videos;
  //   });
  // }
Future<void> _loadFilesFromFirestore() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: currentUser.uid) // Filter by current user's ID
        .orderBy('createdAt', descending: true)
        .get();

    final images = <String>[];
    final videos = <String>[];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final mediaFiles = List<String>.from(data['mediaFiles'] ?? []);

      for (var url in mediaFiles) {
        if (url.endsWith('.mp4')) {
          videos.add(url);
        } else {
          images.add(url);
        }
      }
    }

    setState(() {
      imageUrls = images;
      videoUrls = videos;
    });
  } catch (e) {
    print('Error loading files from Firestore: $e');
  }
}
  Widget _buildVideoThumbnail(String url) {
    return FutureBuilder(
      future: _initializeVideo(url),
      builder: (context, AsyncSnapshot<VideoPlayerController> snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          final controller = snapshot.data!;
          return Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
              const Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 50,
              ),
            ],
          );
        } else {
          return Container(
            color: Colors.black12,
            child: const Center(child: CircularProgressIndicator(
               color:  Color(0xff1B1212),
                               backgroundColor: Colors.white,
            ),),
          );
        }
      },
    );
  }

  Future<VideoPlayerController> _initializeVideo(String url) async {
    final controller = VideoPlayerController.network(url);
    await controller.initialize();
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = currentUser.uid == user['uid'];

    return Consumer(
      builder: (context, ref, child) {
        final profileImageUrl = ref.watch(profileImageProvider);
        
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(90),
              child: AppBar(
                shadowColor: Colors.white,
                centerTitle: true,
                backgroundColor: Colors.white,
                automaticallyImplyLeading: false,
                actions: [
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const CreditCard(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin = Offset(1.0, 0.0);
                          const end = Offset.zero;
                          const curve = Curves.easeInOut;
                          var tween = Tween(begin: begin, end: end)
                              .chain(CurveTween(curve: curve));
                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                      ),
                    ),
                    label: const Text(
                      'Add Card',
                      style: TextStyle(color: Color(0xff1B1212)),
                    ),
                    icon: const Icon(Icons.credit_card, color: Color(0xff1B1212)),
                  ),
                  IconButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.white,
                        content: const Text('Are you sure you want to Logout?',
                            style: TextStyle(
                              color: Color(0xff1B1212),
                            ),),
                        title: const Text('Logout',
                            style: TextStyle(
                              color: Color(0xff1B1212),
                            ),),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              FirebaseAuth.instance.signOut();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PopScope(
                                    canPop: false,
                                    child: Login(),
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Logout',
                              style: TextStyle(color: Colors.red),
                            ),
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
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const Help(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin = Offset(1.0, 0.0);
                          const end = Offset.zero;
                          const curve = Curves.easeInOut;
                          var tween = Tween(begin: begin, end: end)
                              .chain(CurveTween(curve: curve));
                          return SlideTransition(
                            position: animation.drive(tween),
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
                     CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : null,
                child: profileImageUrl == null || profileImageUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
                    // CircleAvatar(
                    //   radius: 20,
                    //   backgroundColor: Colors.grey.shade300,
                    //   backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                    //       ? NetworkImage(profileImageUrl)
                    //       : null,
                    //   child: profileImageUrl == null || profileImageUrl.isEmpty
                    //       ? const Icon(Icons.person, color: Colors.grey)
                    //       : null,
                    // ),
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
                        onPressed: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  EditProfile(),
                              transitionsBuilder:
                                  (context, animation, secondaryAnimation, child) {
                                const begin = Offset(1.0, 0.0);
                                const end = Offset.zero;
                                const curve = Curves.easeInOut;
                                var tween = Tween(begin: begin, end: end)
                                    .chain(CurveTween(curve: curve));
                                return SlideTransition(
                                  position: animation.drive(tween),
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                        child: const Text(
                          'Edit Profile',
                          style: TextStyle(
                            color: Color(0xff1B1212),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xff1B1212), width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    if (!isOwnProfile) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          2,
                          (index) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                Text(
                                  index == 0 ? 'Followers' : 'Following',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: Color(0xff1B1212),
                                  ),
                                ),
                                Text(
                                  index == 0
                                      ? followersCount.toString()
                                      : followingCount.toString(),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    color: Color(0xff1B1212),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const Text(
                      'Description',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff1B1212),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: TextFormField(
                        controller: _controller,
                        maxLines: null,
                        readOnly: !_isEditable,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xff1B1212),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _isEditable = true;
                                _showCheckIcon = true;
                              });
                            },
                            icon: const CircleAvatar(
                              backgroundColor: Color(0xff1B1212),
                              radius: 15,
                              child: Icon(Icons.edit, size: 20, color: Colors.white,),
                            ),
                          ),
                          suffixIcon: _showCheckIcon
                              ? IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditable = false;
                                      _showCheckIcon = false;
                                    });
                                    _saveDescription(_controller.text);
                                  },
                                  icon: const CircleAvatar(
                                    radius: 15,
                                    backgroundColor: Color(0xff1B1212),
                                    child: Icon(Icons.check, color: Colors.white),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                   
                   Column(
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
                                      child: Image.network(
                                        imageUrls[index],
                                        fit: BoxFit.cover,
                                      ),
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
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}