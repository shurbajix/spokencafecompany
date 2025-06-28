import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class Gallery extends StatefulWidget {
  const Gallery({super.key});

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Dio _dio = Dio();
  late TabController _tabController;
  
  List<Map<String, dynamic>> _allPosts = [];
  List<Map<String, dynamic>> _imagePosts = [];
  List<Map<String, dynamic>> _videoPosts = [];
  bool _isLoading = true;
  Map<String, bool> _downloadingStatus = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllPosts();
    _requestPermissions();
    _debugPermissions();
  }

  // Debug method to check current permission status
  Future<void> _debugPermissions() async {
    if (Platform.isAndroid) {
      final storage = await Permission.storage.status;
      final photos = await Permission.photos.status;
      final videos = await Permission.videos.status;
      final manageStorage = await Permission.manageExternalStorage.status;
      
      print('=== PERMISSION STATUS ===');
      print('Storage: $storage');
      print('Photos: $photos');
      print('Videos: $videos');
      print('Manage Storage: $manageStorage');
      print('========================');
    }
  }

  // Show permission info dialog
  void _showPermissionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Information'),
        content: const Text(
          'Downloads are saved in this order of preference:\n\n'
          '1. 📱 Device Gallery (if permission granted)\n'
          '2. 📁 Downloads folder\n'
          '3. 📂 App documents folder\n\n'
          'For best experience, grant storage/photos permission in device settings.\n\n'
          'Files are named: SpokenCafe_[timestamp].[extension]',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Request necessary permissions
  Future<void> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Request basic permissions first
        await Permission.storage.request();
        await Permission.photos.request();
      } else if (Platform.isIOS) {
        await Permission.photos.request();
      }
    } catch (e) {
      print('Permission request error: $e');
      // Continue anyway, we have fallback download methods
    }
  }

  // Get user name from userId
  Future<String> _getUserName(String? userId) async {
    if (userId == null || userId.isEmpty) return 'Unknown User';
    
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final name = userData?['name']?.toString() ?? '';
        final surname = userData?['surname']?.toString() ?? '';
        
        if (name.isNotEmpty || surname.isNotEmpty) {
          return '$name $surname'.trim();
        }
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }
    
    return 'Unknown User';
  }

  // Fetch all posts from Firestore
  Future<void> _fetchAllPosts() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Fetch from posts collection
      List<Map<String, dynamic>> allPosts = [];

      try {
        final querySnapshot = await _firestore.collection('posts').get();
        
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          data['collection'] = 'posts';
          
          // Check if post has media (mediaFiles array)
          final mediaFiles = data['mediaFiles'] as List<dynamic>?;
          if (mediaFiles != null && mediaFiles.isNotEmpty) {
            // Get user name
            final userName = await _getUserName(data['userId']?.toString());
            data['userName'] = userName;
            allPosts.add(data);
          }
        }
      } catch (e) {
        print('Error fetching from posts: $e');
      }

      // Also fetch from post_media_images and post_media_videos collections
      try {
        final imagesSnapshot = await _firestore.collection('post_media_images').get();
        
        for (var doc in imagesSnapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          data['collection'] = 'post_media_images';
          
          // Convert to standard format
          final url = data['url']?.toString();
          if (url != null && url.isNotEmpty) {
            final userName = await _getUserName(data['userId']?.toString());
            allPosts.add({
              'id': doc.id,
              'collection': 'post_media_images',
              'mediaFiles': [url],
              'text': 'Media from post_media_images',
              'userId': data['userId'],
              'createdAt': data['timestamp'] ?? data['uploadedAt'],
              'userName': userName,
            });
          }
        }
      } catch (e) {
        print('Error fetching from post_media_images: $e');
      }

      try {
        final videosSnapshot = await _firestore.collection('post_media_videos').get();
        
        for (var doc in videosSnapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          data['collection'] = 'post_media_videos';
          
          // Convert to standard format
          final url = data['url']?.toString();
          if (url != null && url.isNotEmpty) {
            final userName = await _getUserName(data['userId']?.toString());
            allPosts.add({
              'id': doc.id,
              'collection': 'post_media_videos',
              'mediaFiles': [url],
              'text': 'Media from post_media_videos',
              'userId': data['userId'],
              'createdAt': data['timestamp'] ?? data['uploadedAt'],
              'userName': userName,
            });
          }
        }
      } catch (e) {
        print('Error fetching from post_media_videos: $e');
      }

      // Sort posts by timestamp (newest first)
      allPosts.sort((a, b) {
        final timestampA = a['createdAt'] as Timestamp?;
        final timestampB = b['createdAt'] as Timestamp?;
        
        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;
        
        return timestampB.compareTo(timestampA);
      });

      // Separate into categories
      List<Map<String, dynamic>> imagePosts = [];
      List<Map<String, dynamic>> videoPosts = [];

      for (var post in allPosts) {
        final mediaFiles = post['mediaFiles'] as List<dynamic>? ?? [];
        
        bool hasImage = false;
        bool hasVideo = false;
        
        for (var mediaUrl in mediaFiles) {
          final url = mediaUrl.toString();
          if (url.isNotEmpty) {
            if (_isVideoUrl(url)) {
              hasVideo = true;
            } else {
              hasImage = true;
            }
          }
        }
        
        if (hasImage) {
          imagePosts.add(post);
        }
        if (hasVideo) {
          videoPosts.add(post);
        }
      }

      if (mounted) {
        setState(() {
          _allPosts = allPosts;
          _imagePosts = imagePosts;
          _videoPosts = videoPosts;
          _isLoading = false;
        });
      }

    } catch (e) {
      print('Error fetching posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading posts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Download media to gallery
  Future<void> _downloadMedia(String url, String type, String postId) async {
    try {
      if (mounted) {
        setState(() {
          _downloadingStatus[postId] = true;
        });
      }

      // Get file extension based on URL or type
      String extension;
      if (url.toLowerCase().contains('.png')) {
        extension = '.png';
      } else if (url.toLowerCase().contains('.jpeg') || url.toLowerCase().contains('.jpg')) {
        extension = '.jpg';
      } else if (url.toLowerCase().contains('.mp4')) {
        extension = '.mp4';
      } else if (url.toLowerCase().contains('.mov')) {
        extension = '.mov';
      } else {
        extension = type == 'image' ? '.jpg' : '.mp4';
      }
      
      String fileName = 'SpokenCafe_${DateTime.now().millisecondsSinceEpoch}$extension';

      // Try multiple download approaches
      bool success = false;
      String savedPath = '';

      // Approach 1: Try saving directly to gallery (if permissions available)
      try {
        await _requestPermissions();
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/$fileName';

        // Download file to temp directory
        await _dio.download(
          url,
          tempPath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              print('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
            }
          },
        );

        // Try to save to gallery
        bool? result;
        if (type == 'image') {
          result = await GallerySaver.saveImage(tempPath);
        } else {
          result = await GallerySaver.saveVideo(tempPath);
        }

        if (result == true) {
          success = true;
          savedPath = 'Gallery';
        }

        // Clean up temp file
        try {
          await File(tempPath).delete();
        } catch (e) {
          print('Error deleting temp file: $e');
        }
      } catch (e) {
        print('Gallery save failed: $e');
      }

      // Approach 2: If gallery save failed, save to Downloads folder
      if (!success) {
        try {
          Directory? downloadsDir;
          
          if (Platform.isAndroid) {
            // Try to get Downloads directory
            downloadsDir = Directory('/storage/emulated/0/Download');
            if (!await downloadsDir.exists()) {
              // Fallback to app documents directory if Downloads not accessible
              downloadsDir = await getApplicationDocumentsDirectory();
            }
          } else {
            downloadsDir = await getApplicationDocumentsDirectory();
          }

          if (downloadsDir != null) {
            final filePath = '${downloadsDir.path}/$fileName';
            
            // Download directly to Downloads folder
            await _dio.download(
              url,
              filePath,
              onReceiveProgress: (received, total) {
                if (total != -1) {
                  print('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
                }
              },
            );

            success = true;
            savedPath = Platform.isAndroid ? 'Downloads folder' : 'Documents folder';
          }
        } catch (e) {
          print('Downloads folder save failed: $e');
        }
      }

      // Approach 3: If all else fails, save to app directory
      if (!success) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final filePath = '${appDir.path}/$fileName';
          
          await _dio.download(
            url,
            filePath,
            onReceiveProgress: (received, total) {
              if (total != -1) {
                print('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
              }
            },
          );

          success = true;
          savedPath = 'App folder';
        } catch (e) {
          print('App folder save failed: $e');
        }
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$type saved to $savedPath successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('All download methods failed');
      }

    } catch (e) {
      print('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString().split(':').last.trim()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Help',
              textColor: Colors.white,
              onPressed: _showPermissionInfo,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingStatus[postId] = false;
        });
      }
    }
  }

  // Check permissions
  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      // Check multiple permissions for Android
      final storageStatus = await Permission.storage.status;
      final photosStatus = await Permission.photos.status;
      final videosStatus = await Permission.videos.status;
      final manageStorageStatus = await Permission.manageExternalStorage.status;
      
      // If any permission is granted, we can proceed
      bool hasPermission = storageStatus.isGranted || 
                          photosStatus.isGranted || 
                          videosStatus.isGranted ||
                          manageStorageStatus.isGranted;
      
      if (!hasPermission) {
        // Try to request permissions again
        await _requestPermissions();
        
        // Check again after requesting
        final newStorageStatus = await Permission.storage.status;
        final newPhotosStatus = await Permission.photos.status;
        final newVideosStatus = await Permission.videos.status;
        final newManageStorageStatus = await Permission.manageExternalStorage.status;
        
        hasPermission = newStorageStatus.isGranted || 
                       newPhotosStatus.isGranted || 
                       newVideosStatus.isGranted ||
                       newManageStorageStatus.isGranted;
      }
      
      return hasPermission;
    } else if (Platform.isIOS) {
      final photosStatus = await Permission.photos.status;
      
      if (!photosStatus.isGranted) {
        await _requestPermissions();
        final newPhotosStatus = await Permission.photos.status;
        return newPhotosStatus.isGranted;
      }
      
      return photosStatus.isGranted;
    }
    return true;
  }

  // Check if URL is a video
  bool _isVideoUrl(String url) {
    if (url.isEmpty) return false;
    
    final videoExtensions = [
      '.mp4',
      '.mov',
      '.avi',
      '.wmv',
      '.mkv',
      '.webm',
      '.m4v',
      '.3gp'
    ];
    final lowerUrl = url.toLowerCase();

    for (var ext in videoExtensions) {
      if (lowerUrl.endsWith(ext)) return true;
    }

    if (lowerUrl.contains('post_media_videos') ||
        lowerUrl.contains('videos/') ||
        lowerUrl.contains('video/')) return true;

    return false;
  }

  // Build post card
  Widget _buildPostCard(Map<String, dynamic> post) {
    final postId = post['id'] ?? '';
    final mediaFiles = post['mediaFiles'] as List<dynamic>? ?? [];
    final description = post['text']?.toString() ?? '';
    final userName = post['userName']?.toString() ?? 'Unknown User';
    final timestamp = post['createdAt'] as Timestamp?;
    final isDownloading = _downloadingStatus[postId] ?? false;

    String timeString = '';
    if (timestamp != null) {
      timeString = DateFormat('MMM dd, yyyy - HH:mm').format(timestamp.toDate());
    }

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xff1B1212),
                  child: Text(
                    userName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (timeString.isNotEmpty)
                        Text(
                          timeString,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Media content
          ...mediaFiles.map((mediaUrl) {
            final url = mediaUrl.toString();
            if (url.isEmpty) return const SizedBox.shrink();
            
            if (_isVideoUrl(url)) {
              return _VideoPlayerWidget(
                videoUrl: url,
                onDownload: isDownloading 
                    ? null 
                    : () => _downloadMedia(url, 'video', postId),
                isDownloading: isDownloading,
              );
            } else {
              return Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: url,
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 300,
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 300,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.error, size: 50),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.black.withOpacity(0.7),
                      onPressed: isDownloading 
                          ? null 
                          : () => _downloadMedia(url, 'image', postId),
                      child: isDownloading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download, color: Colors.white),
                    ),
                  ),
                ],
              );
            }
          }).toList(),

          // Description
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                description,
                style: const TextStyle(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Gallery',
          style: TextStyle(
            color: Color(0xff1B1212),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xff1B1212)),
            onPressed: _showPermissionInfo,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xff1B1212)),
            onPressed: _fetchAllPosts,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Color(0xff1B1212),
          unselectedLabelColor: Colors.grey,
          indicatorColor: Color(0xff1B1212),
          tabs: [
            Tab(
              text: 'All (${_allPosts.length})',
              icon: const Icon(Icons.apps),
            ),
            Tab(
              text: 'Images (${_imagePosts.length})',
              icon: const Icon(Icons.image),
            ),
            Tab(
              text: 'Videos (${_videoPosts.length})',
              icon: const Icon(Icons.video_library),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xff1B1212),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // All posts
                _buildPostsList(_allPosts),
                // Images only
                _buildPostsList(_imagePosts),
                // Videos only
                _buildPostsList(_videoPosts),
              ],
            ),
    );
  }

  Widget _buildPostsList(List<Map<String, dynamic>> posts) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No posts found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Posts with media will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        return _buildPostCard(posts[index]);
      },
    );
  }
}

// Custom video player widget
class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final VoidCallback? onDownload;
  final bool isDownloading;

  const _VideoPlayerWidget({
    required this.videoUrl,
    this.onDownload,
    this.isDownloading = false,
  });

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _initializeVideo() async {
    try {
      _controller = VideoPlayerController.network(widget.videoUrl);
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  void _togglePlayPause() {
    if (_controller != null && mounted) {
      setState(() {
        if (_isPlaying) {
          _controller!.pause();
          _isPlaying = false;
        } else {
          _controller!.play();
          _isPlaying = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      child: Stack(
        children: [
          if (_isInitialized && _controller != null)
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            )
          else
            Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),

          // Play/Pause overlay
          if (_isInitialized)
            Positioned.fill(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _isPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Download button
          Positioned(
            top: 8,
            right: 8,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.black.withOpacity(0.7),
              onPressed: widget.onDownload,
              child: widget.isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
