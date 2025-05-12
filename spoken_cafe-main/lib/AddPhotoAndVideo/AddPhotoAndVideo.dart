
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart' as material;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class AddPhotoAndVideo extends material.StatefulWidget {
  final bool isEditing;
  final String? existingPostId;
  final Map<String, dynamic>? existingPostData;
  final Function(Map<String, dynamic>) onPostCreated;

  const AddPhotoAndVideo({
    super.key,
    required this.onPostCreated,
    this.isEditing = false,
    this.existingPostId,
    this.existingPostData,
  });

  @override
  _AddPhotoAndVideoState createState() => _AddPhotoAndVideoState();
}

class _AddPhotoAndVideoState extends material.State<AddPhotoAndVideo> {
  final material.TextEditingController _textController = material.TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<File> _mediaFiles = [];
  final List<String> _existingMediaUrls = [];
  bool isLoading = false;
  final Map<File, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.existingPostData != null) {
      _textController.text = widget.existingPostData!['text'] ?? '';
      List<dynamic> media = widget.existingPostData!['mediaFiles'] ?? [];
      _existingMediaUrls.addAll(media.map((e) => e.toString()));
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _mediaFiles.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _pickVideo() async {
    final pickedFile = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final controller = VideoPlayerController.file(file)
        ..initialize().then((_) {
          setState(() {});
        }).catchError((error) {
          print('Error initializing video preview: $error');
        });
      setState(() {
        _mediaFiles.add(file);
        _videoControllers[file] = controller;
      });
    }
  }

  Future<void> _postContent() async {
    if (_textController.text.isEmpty && _mediaFiles.isEmpty && _existingMediaUrls.isEmpty) {
      material.ScaffoldMessenger.of(context).showSnackBar(
        
        const material.SnackBar(content: material.Text('Please add text or media to post.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated. Please sign in.');
      }

      await user.getIdToken(true);

      List<String> mediaUrls = [..._existingMediaUrls];
      const maxRetries = 3;

      for (var file in _mediaFiles) {
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        int attempt = 0;
        bool success = false;
        String? downloadUrl;

        while (attempt < maxRetries && !success) {
          try {
            UploadTask uploadTask = FirebaseStorage.instance
                .ref('post_media/$fileName')
                .putFile(file);

            TaskSnapshot taskSnapshot = await uploadTask;
            downloadUrl = await taskSnapshot.ref.getDownloadURL();
            success = true;
          } catch (e) {
            attempt++;
            if (attempt == maxRetries) {
              throw Exception('Failed to upload file after $maxRetries attempts: $e');
            }
            print('Upload attempt $attempt failed: $e');
            await Future.delayed(Duration(seconds: 2 * attempt));
          }
        }

        if (downloadUrl != null) {
          mediaUrls.add(downloadUrl);
        }
      }

      final postData = {
        'text': _textController.text,
        'mediaFiles': mediaUrls,
        'createdAt': firestore.Timestamp.now(),
        'userId': user.uid,
        'likes': [],
      };

      if (widget.isEditing && widget.existingPostId != null) {
        await firestore.FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.existingPostId)
            .update(postData);
      } else {
        await firestore.FirebaseFirestore.instance.collection('posts').add(postData);
      }

      widget.onPostCreated(postData);

      _textController.clear();
      for (var controller in _videoControllers.values) {
        controller.dispose();
      }
      setState(() {
        _mediaFiles.clear();
        _videoControllers.clear();
        isLoading = false;
      });
    } catch (e) {
      print("Error during post creation: $e");
      setState(() => isLoading = false);
      material.showDialog(
        context: context,
        builder: (context) => material.AlertDialog(
          title: const material.Text('Upload Error'),
          content: material.Text('An error occurred: $e'),
          actions: [
            material.TextButton(
              onPressed: () => material.Navigator.of(context).pop(),
              child: const material.Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  material.Widget build(material.BuildContext context) {
    return material.Padding(
      padding: const material.EdgeInsets.only(bottom: 20),
      child: material.SingleChildScrollView(
        child: material.Column(
          children: [
            const material.SizedBox(height: 10),
            material.Text(
              widget.isEditing ? 'Edit Post' : 'Add A New Post',
              textAlign: material.TextAlign.center,
              style: const material.TextStyle(
                fontSize: 20,
                color: material.Color(0xff1B1212),
                fontWeight: material.FontWeight.bold,
              ),
            ),
            material.Container(
              margin: const material.EdgeInsets.all(20),
              decoration: material.BoxDecoration(
                color: material.Colors.white,
                border: material.Border.all(color: material.Color(0xff1B1212), width: 2),
                borderRadius: material.BorderRadius.circular(10),
              ),
              child: material.Column(
                crossAxisAlignment: material.CrossAxisAlignment.stretch,
                children: [
                  material.Padding(
                    padding: const material.EdgeInsets.all(10.0),
                    child: material.TextFormField(
                      controller: _textController,
                      maxLines: null,
                      decoration: material.InputDecoration(
                        hintText: 'Write A post',
                        border: material.OutlineInputBorder(
                          borderRadius: material.BorderRadius.circular(10),
                          borderSide: const material.BorderSide(
                            color: material.Color(0xff1B1212),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  material.Row(
                    mainAxisAlignment: material.MainAxisAlignment.spaceAround,
                    children: [
                      _mediaPickerButton(
                        label: 'Photo',
                        assetPath: 'assets/images/image.png',
                        onTap: _pickImage,
                      ),
                      _mediaPickerButton(
                        label: 'Video',
                        assetPath: 'assets/images/video.png',
                        onTap: _pickVideo,
                      ),
                    ],
                  ),
                  const material.SizedBox(height: 20),
                  if (_existingMediaUrls.isNotEmpty || _mediaFiles.isNotEmpty)
                    material.SizedBox(
                      height: 150,
                      child: material.ListView(
                        scrollDirection: material.Axis.horizontal,
                        children: [
                          ..._existingMediaUrls.map((url) {
                            return material.Padding(
                              padding: const material.EdgeInsets.all(10),
                              child: url.endsWith('.mp4')
                                  ? material.SizedBox(
                                      width: 150,
                                      child: VideoPlayerWidget(
                                        videoUrl: url,
                                        isNetwork: true,
                                      ),
                                    )
                                  : material.Image.network(
                                      url,
                                      height: 150,
                                      fit: material.BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const material.Icon(material.Icons.error),
                                    ),
                            );
                          }).toList(),
                          ..._mediaFiles.map((file) {
                            return material.Padding(
                              padding: const material.EdgeInsets.all(10),
                              child: file.path.endsWith('.mp4')
                                  ? material.SizedBox(
                                      width: 150,
                                      child: _videoControllers.containsKey(file) &&
                                              _videoControllers[file]!.value.isInitialized
                                          ? material.Stack(
                                              alignment: material.Alignment.center,
                                              children: [
                                                material.AspectRatio(
                                                  aspectRatio: _videoControllers[file]!
                                                      .value.aspectRatio,
                                                  child: VideoPlayer(
                                                      _videoControllers[file]!),
                                                ),
                                                material.IconButton(
                                                  icon: material.Icon(
                                                    _videoControllers[file]!
                                                            .value.isPlaying
                                                        ? material.Icons.pause
                                                        : material.Icons.play_arrow,
                                                    color: material.Colors.white,
                                                    size: 50,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      if (_videoControllers[file]!
                                                          .value.isPlaying) {
                                                        _videoControllers[file]!
                                                            .pause();
                                                      } else {
                                                        _videoControllers[file]!
                                                            .play();
                                                      }
                                                    });
                                                  },
                                                ),
                                              ],
                                            )
                                          : const material.CircularProgressIndicator(
                                              color: material.Color(0xff1B1212),
                                              backgroundColor: material.Colors.white,
                                              
                                            ),
                                    )
                                  : material.Image.file(
                                      file,
                                      height: 150,
                                      fit: material.BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const material.Icon(material.Icons.error),
                                    ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  const material.SizedBox(height: 20),
                  material.Padding(
                    padding: const material.EdgeInsets.symmetric(horizontal: 30),
                    child: material.SizedBox(
                      height: 55,
                      child: material.ElevatedButton(
                        style: material.ElevatedButton.styleFrom(
                          backgroundColor: const material.Color(0xff1B1212),
                          shape: material.RoundedRectangleBorder(
                            borderRadius: material.BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: isLoading ? null : _postContent,
                        child: isLoading
                            ? const material.CircularProgressIndicator(
                                
                                 color:  material.Color(0xff1B1212),
                               backgroundColor: material.Colors.white,
                              )
                            : material.Text(
                                widget.isEditing ? 'Update' : 'Post',
                                style: const material.TextStyle(
                                  fontSize: 20,
                                  color: material.Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const material.SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  material.Widget _mediaPickerButton({
    required String label,
    required String assetPath,
    required material.VoidCallback onTap,
  }) {
    return material.Column(
      children: [
        material.GestureDetector(
          onTap: onTap,
          child: material.Container(
            height: 50,
            width: 50,
            decoration: material.BoxDecoration(
              border: material.Border.all(color: material.Color(0xff1B1212), width: 2),
              borderRadius: material.BorderRadius.circular(10),
            ),
            child: material.Padding(
              padding: const material.EdgeInsets.all(10.0),
              child: material.Image.asset(
                assetPath,
                color: material.Color(0xff1B1212),
              ),
            ),
          ),
        ),
        const material.SizedBox(height: 5),
        material.Text(
          label,
          style: const material.TextStyle(
            fontSize: 20,
            color: material.Color(0xff1B1212),
            fontWeight: material.FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// Placeholder for VideoPlayerWidget, as it's not defined in the provided code
class VideoPlayerWidget extends material.StatelessWidget {
  final String videoUrl;
  final bool isNetwork;

  const VideoPlayerWidget({super.key, required this.videoUrl, required this.isNetwork});

  @override
  material.Widget build(material.BuildContext context) {
    final controller = isNetwork
        ? VideoPlayerController.network(videoUrl)
        : VideoPlayerController.file(File(videoUrl));

    return material.FutureBuilder(
      future: controller.initialize(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == material.ConnectionState.done) {
          return material.AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          );
        } else {
          return const material.Center(child: material.CircularProgressIndicator(
             color: material.Color(0xff1B1212),
                               backgroundColor: material.Colors.white,
          ),);
        }
      },
    );
  }
}



// <!-- <?xml version="1.0" encoding="utf-8"?>
// <resources>
//     <!-- Theme applied to the Android Window while the process is starting when the OS's Dark Mode setting is off -->
//     <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
//         <!-- Show a splash screen on the activity. Automatically removed when
//              the Flutter engine draws its first frame -->
//         <item name="android:windowBackground">@drawable/launch_background</item>
//         <item name="android:forceDarkAllowed">false</item>
//         <item name="android:windowFullscreen">false</item>
//         <item name="android:windowDrawsSystemBarBackgrounds">false</item>
//         <item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>
//     </style>
//     <!-- Theme applied to the Android Window as soon as the process has started.
//          This theme determines the color of the Android Window while your
//          Flutter UI initializes, as well as behind your Flutter UI while it's
//          running.

//          This Theme is only used starting with V2 of Flutter's Android embedding. -->
//     <style name="NormalTheme" parent="Theme.MaterialComponents">
//         <item name="android:windowBackground">?android:colorBackground</item>
//     </style>
//     <!-- App Strings -->
//     <string name="app_name">spokencafe</string>
//     <string name="done">Done</string>
// </resources> -->