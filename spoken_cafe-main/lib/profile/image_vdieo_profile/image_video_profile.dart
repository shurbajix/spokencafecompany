import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';

class Images_Video_Profile extends ConsumerStatefulWidget {
  const Images_Video_Profile({super.key});

  @override
  ConsumerState<Images_Video_Profile> createState() =>
      _Images_Video_ProfileState();
}

class _Images_Video_ProfileState extends ConsumerState<Images_Video_Profile> {
  List<String> imageUrls = [];
  List<String> videoUrls = [];

  @override
  void initState() {
    super.initState();
    _loadFilesFromFirestore();
  }

  Future<void> _loadFilesFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('media')
        .orderBy('timestamp', descending: true)
        .get();

    final images = <String>[];
    final videos = <String>[];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final url = data['url'];
      final type = data['type'];

      if (type == 'image') {
        images.add(url);
      } else if (type == 'video') {
        videos.add(url);
      }
    }

    setState(() {
      imageUrls = images;
      videoUrls = videos;
    });
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
            )),
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_ios_new,color: Color(0xff1B1212),),
          ),
          centerTitle: true,
          title: const Text(
            'Gallery',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xff1B1212),
            ),
          ),
          bottom: const TabBar(
            unselectedLabelColor: Color(0xff1B1212),
            indicatorColor: Color(0xff1B1212),
            labelColor: Color(0xff1B1212),
            tabs: [
              Tab(icon: Icon(Icons.image,color: Color(0xff1B1212),),),
              Tab(icon: Icon(Icons.video_call,color: Color(0xff1B1212),),),
            ],
          ),
        ),
        body: TabBarView(
          
          children: [
            // 🖼️ Images Tab
            GridView.builder(
              itemCount: imageUrls.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(imageUrls[index], fit: BoxFit.cover),
                  ),
                );
              },
            ),
            // 🎥 Videos Tab
            GridView.builder(
              itemCount: videoUrls.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildVideoThumbnail(videoUrls[index]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


// import 'dart:io';

// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:video_player/video_player.dart';

// class Images_Video_Profile extends ConsumerStatefulWidget {
//   const Images_Video_Profile({super.key});

//   @override
//   ConsumerState<Images_Video_Profile> createState() =>
//       _Images_Video_ProfileState();
// }

// class _Images_Video_ProfileState extends ConsumerState<Images_Video_Profile> {
//   final List<File> _images = [];
//   final List<File> _videos = [];

//   @override
//   void initState() {
//     super.initState();
//     _loadFiles();
//   }

//   Future<void> _pickImage() async {
//     FilePickerResult? result = await FilePicker.platform.pickFiles(
//       type: FileType.image,
//       allowMultiple: true,
//     );

//     if (result != null && result.files.isNotEmpty) {
//       setState(() {
//         _images.addAll(
//           result.files.map((file) => File(file.path!)).toList(),
//         );
//       });
//       _saveFiles();
//     }
//   }

//   Future<void> _pickVideo() async {
//     FilePickerResult? resultvideo = await FilePicker.platform.pickFiles(
//       type: FileType.video,
//       allowMultiple: true,
//     );

//     if (resultvideo != null && resultvideo.files.isNotEmpty) {
//       setState(() {
//         _videos.addAll(
//           resultvideo.files.map((file) => File(file.path!)).toList(),
//         );
//       });
//       _saveFiles();
//     }
//   }

//   Future<void> _saveFiles() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String> imagePaths = _images
//         .map(
//           (file) => file.path,
//         )
//         .toList();
//     List<String> videoPaths = _videos
//         .map(
//           (file) => file.path,
//         )
//         .toList();

//     print(
//       'Saving image paths: $imagePaths',
//     );
//     print(
//       'Saving video paths: $videoPaths',
//     );

//     await prefs.setStringList(
//       'images',
//       imagePaths,
//     );
//     await prefs.setStringList(
//       'videos',
//       videoPaths,
//     );
//   }

//   Future<void> _loadFiles() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     List<String>? imagePaths = prefs.getStringList(
//       'images',
//     );
//     List<String>? videoPaths = prefs.getStringList(
//       'videos',
//     );

//     print(
//       'Loaded image paths: $imagePaths',
//     );
//     print(
//       'Loaded video paths: $videoPaths',
//     );

//     if (imagePaths != null) {
//       setState(() {
//         _images.addAll(
//           imagePaths.map((path) => File(path)).toList(),
//         );
//       });
//     }

//     if (videoPaths != null) {
//       setState(() {
//         _videos.addAll(
//           videoPaths.map((path) => File(path)).toList(),
//         );
//       });
//     }
//   }

//   Future<Widget> _buildVideoThumbnail(File videoFile) async {
//     final VideoPlayerController videoPlayerController =
//         VideoPlayerController.file(videoFile);
//     await videoPlayerController.initialize();
//     return Stack(
//       alignment: Alignment.center,
//       children: [
//         AspectRatio(
//           aspectRatio: videoPlayerController.value.aspectRatio,
//           child: VideoPlayer(
//             videoPlayerController,
//           ),
//         ),
//         const Icon(
//           Icons.play_circle_fill,
//           color: Colors.white,
//           size: 50,
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         backgroundColor: Colors.white,
//         appBar: AppBar(
//           backgroundColor: Colors.white,
//           leading: IconButton(
//             onPressed: () {
//               Navigator.pop(context);
//             },
//             icon: Icon(
//               Icons.arrow_back_ios_new,
//             ),
//           ),
//           // backgroundColor: Colors.white,
//           centerTitle: true,
//           title: const Text(
//             'Gallery',
//             style: TextStyle(
//               fontSize: 30,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           bottom: const TabBar(
//             labelColor: Colors.black,
//             tabs: [
//               Tab(
//                 icon: Icon(
//                   Icons.image,
//                 ),
//               ),
//               Tab(
//                 icon: Icon(
//                   Icons.video_call,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         body: TabBarView(
//           children: [
//           Container(
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//               ),
//               child: GridView.builder(
//                 itemCount: 20,
//                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 3,
//                 ),
//                 itemBuilder: (context, index) {
//                   return  Container(
//                         margin: const EdgeInsets.all(10),
//                         height: 100,
//                         width: 100,
//                         decoration: BoxDecoration(
//                           color: Colors.grey[300],
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: const Icon(
//                           FontAwesomeIcons.video,
//                           color: Colors.grey,
//                         ),
                      
//                     );
                
//                 },
//               ),
//             ),
//             Container(
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//               ),
//               child: GridView.builder(
//                 itemCount: 20,
//                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 3,
//                 ),
//                 itemBuilder: (context, index) {
//                   return  Container(
//                         margin: const EdgeInsets.all(10),
//                         height: 100,
//                         width: 100,
//                         decoration: BoxDecoration(
//                           color: Colors.grey[300],
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: const Icon(
//                           FontAwesomeIcons.video,
//                           color: Colors.grey,
//                         ),
                      
//                     );
                
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


  // if (index == 0) {
  //                   return 
  //                 } else {
  //                   return FutureBuilder<Widget>(
  //                     future: _buildVideoThumbnail(
  //                       _videos[index - 1],
  //                     ),
  //                     builder: (context, snapshot) {
  //                       if (snapshot.connectionState == ConnectionState.done) {
  //                         return Container(
  //                           margin: const EdgeInsets.all(10),
  //                           height: 100,
  //                           width: 100,
  //                           decoration: BoxDecoration(
  //                             borderRadius: BorderRadius.circular(10),
  //                           ),
  //                           child: snapshot.data,
  //                         );
  //                       } else {
  //                         return Container(
  //                           margin: const EdgeInsets.all(10),
  //                           height: 100,
  //                           width: 100,
  //                           decoration: BoxDecoration(
  //                             color: Colors.grey[300],
  //                             borderRadius: BorderRadius.circular(10),
  //                           ),
  //                           child: const Center(
  //                             child: CircularProgressIndicator(),
  //                           ),
  //                         );
  //                       }
  //                     },
  //                   );
  //                 }