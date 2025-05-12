// import 'dart:io';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/material.dart';

// class YourUploadClass extends StatefulWidget {
//   @override
//   _YourUploadClassState createState() => _YourUploadClassState();
// }

// class _YourUploadClassState extends State<YourUploadClass> {
//   final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

//   Future<void> uploadFile(File file) async {
//     try {
//       // Prepare the file for upload
//       String fileName = DateTime.now().millisecondsSinceEpoch.toString();
//       UploadTask uploadTask = _firebaseStorage
//           .ref('post_media/$fileName')
//           .putFile(file);

//       // Listen to the upload task to track progress
//       uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
//         if (snapshot.state == TaskState.running) {
//           double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
//           print("Upload Progress: $progress%");
//         }
//       });

//       // Await the task completion and get the download URL
//       TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() {});

//       // Get the download URL after the upload is complete
//       String downloadUrl = await taskSnapshot.ref.getDownloadURL();

//       print("Upload completed successfully: $downloadUrl");

//       // Handle your post creation here (for example, saving the URL to Firestore)
//       // Example: savePostData(downloadUrl);

//     } catch (e) {
//       // Handle specific Firebase Storage errors
//       print("Error during upload: $e");

//       if (e is FirebaseException) {
//         // Firebase-specific error handling
//         print("Firebase Error Code: ${e.code}");
//         print("Firebase Error Message: ${e.message}");
//       }
//     }
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     // TODO: implement build
//     throw UnimplementedError();
//   }
// }

import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

Future<void> uploadFileToStorage() async {
  final file = File('path_to_file');  // Replace with your file path
  try {
    final storageRef = FirebaseStorage.instance.ref().child('uploads/${file.uri.pathSegments.last}');
    
    // Start upload
    final uploadTask = storageRef.putFile(file);

    // Listen to upload progress and log events
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      print("Upload progress: ${snapshot.bytesTransferred} / ${snapshot.totalBytes}");
      print("Upload state: ${snapshot.state}");
    });

    // Wait for the upload to complete
    await uploadTask.whenComplete(() {
      print("Upload complete!");
    });
  } catch (e) {
    print("Error during upload: $e");
  }
}