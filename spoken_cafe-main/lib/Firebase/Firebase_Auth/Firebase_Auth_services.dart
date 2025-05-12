import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class FirebaseAuthServices {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<User?> signUpWithEmailAndPassword(
    String name,
    String surname,
    String phoneNumber,
    String email,
    String password,
    File? imageFile,
    //Strings,
  ) async {
    UserCredential? credential;
    try {
      // 1. Create user with email/password
      credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = credential.user;
      if (user == null) return null;

      String? photoUrl;
      // 2. Upload image if provided
      if (imageFile != null) {
        photoUrl = await _uploadProfileImage(imageFile, user.uid);
      }

      // 3. Update user profile with name and photo
      await user.updateProfile(
        displayName: "$name $surname",
        photoURL: photoUrl,
      );
      await user.reload();
      user = _auth.currentUser;

      // 4. Save additional data to Firestore
      await _firestore.collection('users').doc(user!.uid).set({
        'uid': user.uid,
        'name': name,
        'surname': surname,
        'phoneNumber': phoneNumber,
        'email': email,
        'profileImageUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return user;
    } catch (e) {
      print("Signup error: $e");
      // Delete user if creation fails
      if (credential?.user != null) await credential!.user?.delete();
      rethrow;
    }
  }

  // Add this method to your FirebaseAuthServices class
  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      print("Sign-in error: $e");
      rethrow;
    }
  }

  Future<String> _uploadProfileImage(File imageFile, String userId) async {
    try {
      String fileExtension = path.extension(imageFile.path).toLowerCase();
      if (!['.jpg', '.jpeg', '.png'].contains(fileExtension)) {
        fileExtension = '.jpg';
      }

      Reference storageRef =
          _storage.ref().child('profile_images/$userId$fileExtension');

      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Image upload error: $e");
      rethrow;
    }
  }
}


// rules_version = '2';

// service cloud.firestore {
//   match /databases/{database}/documents {
//     match /{document=**} {
//       allow read, write: if true;
//     }
//   }
// }