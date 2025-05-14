import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spokencafe/AddPhotoAndVideo/AddPhotoAndVideo.dart';
import 'package:spokencafe/CommentPage/CommentPage.dart';
import 'package:spokencafe/Notifiction/Notifiction.dart';
import 'package:spokencafe/model/NavBar/NavBar.dart';
import 'package:spokencafe/model/student/profile_student/profile_student.dart';
import 'package:spokencafe/profile/All_Users_Profile/All_Users_Profile.dart';
import 'package:spokencafe/profile/Profile.dart';
import 'package:video_player/video_player.dart';

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  String? role;
  Map<String, dynamic> userData = {};
  User? currentUser = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> allUsers = [];
  final Map<String, Stream<int>> _commentCountStreams = {};

  @override
  void initState() {
    super.initState();
    _refreshUser();
    _fetchAllUsers();
  }

  Future<void> _refreshUser() async {
    await FirebaseAuth.instance.currentUser?.reload();
    setState(() {
      currentUser = FirebaseAuth.instance.currentUser;
    });
  }

  Future<void> _fetchAllUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final users = snapshot.docs.map((doc) {
        return {
          'uid': doc.id,
          ...doc.data(),
          'profileImageUrl': doc.data()['profileImageUrl'] ?? '',
          'name': doc.data()['name'] ?? '',
          'surname': doc.data()['surname'] ?? '',
          'role': doc.data()['role'] ?? 'student',
        };
      }).toList();

      setState(() {
        allUsers = users;
        if (currentUser != null) {
          final currentUserData = users.firstWhere(
            (user) => user['uid'] == currentUser!.uid,
            orElse: () => {},
          );
          role = currentUserData['role'] ?? 'student';
        }
      });
    } catch (e) {
      print('Error fetching users: $e');
    }
  }

  Stream<int> _getCommentCountStream(String postId) {
    if (!_commentCountStreams.containsKey(postId)) { // Fixed typo: removed "Guar"
      _commentCountStreams[postId] = FirebaseFirestore.instance
          .collection('User posts')
          .doc(postId)
          .collection('Comments')
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    }
    return _commentCountStreams[postId]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                 color:  Color(0xff1B1212),
                  backgroundColor: Colors.white,
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No posts found.'));
          }

          final posts = snapshot.data!.docs;

          return RefreshIndicator(
            color:  Color(0xff1B1212),
            backgroundColor: Colors.white,
            onRefresh: () async {
              await _refreshUser();
              await _fetchAllUsers();
            },
            child: ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final postDoc = posts[index];
                final postData = postDoc.data() as Map<String, dynamic>;
                return _buildPostCard(postDoc.id, postData);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'btn1',
        backgroundColor: const Color(0xff1B1212),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          builder: (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: AddPhotoAndVideo(
              onPostCreated: (_) => Navigator.pop(context),
            ),
          ),
        ),
        child: const Icon(Icons.add, color: Colors.white,),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      title: const Text(
        'Home',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xff1B1212),
          fontSize: 30,
        ),
      ),
      centerTitle: true,
      leading: const Icon(Icons.verified, color: Colors.green),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications, color: Color(0xff1B1212)),
          onPressed: () {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => Notifiction(),),);
          },
        ),
      ],
    );
  }

  Widget _buildPostCard(String postId, Map<String, dynamic> postData) {
    final userData = allUsers.firstWhere(
      (user) => user['uid'] == postData['userId'],
      orElse: () => {
        'uid': '',
        'name': 'Unknown',
        'surname': 'User',
        'profileImageUrl': '',
      },
    );

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.grey,
            offset: Offset(0, 1),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostHeader(postId, postData, userData),
          if (postData['text'] != null && postData['text'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                postData['text'],
                style: const TextStyle(
                  color: Color(0xff1B1212),
                ),
              ),
            ),
          if (postData['mediaFiles'] != null && postData['mediaFiles'].isNotEmpty)
            _buildCarousel(postData['mediaFiles']),
          _buildPostActions(postId, postData),
        ],
      ),
    );
  }

  Widget _buildPostHeader(
      String postId, Map<String, dynamic> postData, Map<String, dynamic> userData) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (userData['uid'] == currentUser?.uid) {
                ref.read(selectIndexProvider.notifier).state = 4;
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllUsersProfile(userId: userData['uid']),
                  ),
                );
              }
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey,
                  backgroundImage: userData['profileImageUrl'] != null &&
                          userData['profileImageUrl'].isNotEmpty
                      ? CachedNetworkImageProvider(userData['profileImageUrl'])
                      : null,
                  child: userData['profileImageUrl'] == null ||
                          userData['profileImageUrl'].isEmpty
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${userData['name']} ${userData['surname']}',
                      style: const TextStyle(
                        color: Color(0xff1B1212),
                      ),
                    ),
                    if (postData['createdAt'] != null)
                      Builder(
                        builder: (context) {
                          final postDate =
                              (postData['createdAt'] as Timestamp).toDate();
                          return Text(
                            DateFormat('MMM dd, yyyy').format(postDate),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (postData['userId'] == currentUser?.uid)
            PopupMenuButton<int>(
              color: Colors.white,
              onSelected: (index) {
                if (index == 1) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    builder: (context) => Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: AddPhotoAndVideo(
                        isEditing: true,
                        existingPostId: postId,
                        existingPostData: postData,
                        onPostCreated: (_) => Navigator.pop(context),
                      ),
                    ),
                  );
                } else if (index == 2) {
                  FirebaseFirestore.instance
                      .collection('posts')
                      .doc(postId)
                      .delete();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 1,
                  child: Text(
                    "Edit",
                    style: TextStyle(
                      color: Color(0xff1B1212),
                    ),
                  ),
                ),
                const PopupMenuItem(
                  value: 2,
                  child: Text(
                    "Delete",
                    style: TextStyle(
                      color: Color(0xff1B1212),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCarousel(List<dynamic> mediaFiles) {
    return SizedBox(
      height: 500,
      child: PageView.builder(
        itemCount: mediaFiles.length,
        itemBuilder: (context, index) {
          final mediaUrl = mediaFiles[index];
          final isVideo = mediaUrl.toString().endsWith('.mp4');

          return Padding(
            padding: const EdgeInsets.all(5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: isVideo
                  ? VideoPlayerWidget(
                      videoUrl: mediaUrl,
                      isNetwork: true,
                    )
                  : InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return Dialog(
                              backgroundColor: Colors.black,
                              insetPadding: EdgeInsets.zero,
                              child: Stack(
                                children: [
                                  InteractiveViewer(
                                    panEnabled: true,
                                    scaleEnabled: true,
                                    minScale: 1.0,
                                    maxScale: 4.0,
                                    child: Center(
                                      child: CachedNetworkImage(
                                        imageUrl: mediaUrl,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) => const Center(
                                          child: CircularProgressIndicator(
                                            backgroundColor: Colors.white,
                                            color: Color(0xff1B1212),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Icons.error),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 40,
                                    right: 20,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: CachedNetworkImage(
                        imageUrl: mediaUrl,
                        width: MediaQuery.of(context).size.width,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                             color:  Color(0xff1B1212),
                               backgroundColor: Colors.white,
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostActions(String postId, Map<String, dynamic> post) {
    final likes = List<String>.from(post['likes'] ?? []);
    final isLiked = likes.contains(currentUser?.uid);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  color: Color(0xff1B1212),
                ),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CommentPage(
                                postId: postId,
                                comments: {},
                              ),),);
                },
              ),
              StreamBuilder<int>(
                stream: _getCommentCountStream(postId),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Text(
                    '$count',
                    style: const TextStyle(
                      color: Color(0xff1B1212),
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : const Color(0xff1B1212),
                ),
                onPressed: () => _toggleLike(postId, isLiked),
              ),
              Text(
                '${likes.length}',
                style: const TextStyle(
                  color: Color(0xff1B1212),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xff1B1212)),
            onPressed: () => Share.share(post['text'] ?? 'Check out this post!'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike(String postId, bool isLiked) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    try {
      if (isLiked) {
        await postRef.update({
          'likes': FieldValue.arrayRemove([currentUser?.uid])
        });
      } else {
        await postRef.update({
          'likes': FieldValue.arrayUnion([currentUser?.uid])
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          content: Text("Error updating like"),
        ),
      );
    }
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool isNetwork;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.isNetwork = false,
  });

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.isNetwork
        ? VideoPlayerController.contentUri(Uri.parse(widget.videoUrl))
        : VideoPlayerController.file(File(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
      }).catchError((error) {
        print('Error initializing video: $error');
        setState(() {
          _isInitialized = false;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isInitialized
        ? Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              IconButton(
                icon: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 50,
                ),
                onPressed: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                    }
                  });
                },
              ),
            ],
          )
        : const Center(
            child: CircularProgressIndicator(
              color: Color(0xff1B1212),
              backgroundColor: Colors.transparent,
            ),
          );
  }
}

