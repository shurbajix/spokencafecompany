import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final profileImageProvider = StateProvider<String?>((ref) => null);

class EditProfile extends ConsumerStatefulWidget {
  const EditProfile({super.key});

  @override
  ConsumerState<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<EditProfile> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  bool isLoading = false;
  File? _imageFile;
  String? profileImageUrl;

  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  Map<String, dynamic> userData = {};

  @override
  void initState() {
    super.initState();
    _refreshUser();
    _loadUserData();
  }

  Future<void> _refreshUser() async {
    await FirebaseAuth.instance.currentUser?.reload();
    setState(() {
      currentUser = FirebaseAuth.instance.currentUser;
    });
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => isLoading = true);
      
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("User")
          .doc(currentUser!.email)
          .get();

      if (doc.exists && doc.data() != null) {
        userData = doc.data() as Map<String, dynamic>;
        nameController.text = userData['username'] ?? '';
        profileImageUrl = userData['profileImageUrl'];
        
        // Initialize the provider with current image
        if (profileImageUrl != null) {
          ref.read(profileImageProvider.notifier).state = profileImageUrl;
        }
      } else {
        userData = {
          "username": currentUser!.displayName ?? "Default Name",
          "surname": "Default Surname",
          "email": currentUser!.email ?? "",
        };
        nameController.text = userData['username'];
        await FirebaseFirestore.instance
            .collection("User")
            .doc(currentUser!.email)
            .set(userData);
      }
    } catch (e) {
      print("Error loading user data: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    try {
      String oldPassword = oldPasswordController.text.trim();
      String newPassword = newPasswordController.text.trim();

      if (oldPassword.isEmpty || newPassword.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            margin: EdgeInsets.all(10),
            behavior: SnackBarBehavior.floating,
            content: Text('Please enter both old and new passwords.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      AuthCredential credential = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: oldPassword,
      );

      await currentUser!.reauthenticateWithCredential(credential);
      await currentUser!.updatePassword(newPassword);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          margin: EdgeInsets.all(10),
          behavior: SnackBarBehavior.floating,
          content: Text('Password updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      oldPasswordController.clear();
      newPasswordController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          margin: const EdgeInsets.all(10),
          behavior: SnackBarBehavior.floating,
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveChanges() async {
    try {
      setState(() => isLoading = true);
      
      final newName = nameController.text.trim();
      
      if (newName.isNotEmpty) {
        await currentUser!.updateDisplayName(newName);
        await _refreshUser();
        userData['username'] = newName;
      }

      if (newPasswordController.text.isNotEmpty) {
        await _updatePassword();
      }

      String? newImageUrl;
      if (_imageFile != null) {
        newImageUrl = await _uploadProfileImage();
      }

      await FirebaseFirestore.instance
          .collection("User")
          .doc(currentUser!.email)
          .set(userData, SetOptions(merge: true));

      // Notify listeners and return the new image URL
      if (newImageUrl != null) {
        ref.read(profileImageProvider.notifier).state = newImageUrl;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          margin: EdgeInsets.all(10),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          content: Text('Profile updated successfully!'),
        ),
      );
      
      // Close the screen after saving
      if (mounted) Navigator.pop(context);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          margin: const EdgeInsets.all(10),
          behavior: SnackBarBehavior.floating,
          content: Text('Error: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

Future<String?> _uploadProfileImage() async {
  if (_imageFile == null) return null;

  try {
    Reference storageRef = FirebaseStorage.instance
        .ref()
        .child('profile_images')
        .child(currentUser!.uid)
        .child('profile.jpg');

    await storageRef.putFile(_imageFile!);
    String downloadUrl = await storageRef.getDownloadURL();

    // Update Firestore
    await FirebaseFirestore.instance
        .collection('users')  // Make sure this matches your collection name
        .doc(currentUser!.uid)
        .update({'profileImageUrl': downloadUrl});

    // Update the provider state
    ref.read(profileImageProvider.notifier).state = downloadUrl;
    
    return downloadUrl;
  } catch (e) {
    print('Error uploading profile image: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Failed to upload image: $e'),
        backgroundColor: Colors.red,
      ),
    );
    return null;
  }
}

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xff1B1212)),
        ),
        backgroundColor: Colors.white,
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xff1B1212),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(
             color:  Color(0xff1B1212),
            backgroundColor: Colors.white,
          ),)
          : ListView(
              shrinkWrap: true,
              children: [
                const SizedBox(height: 40),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (profileImageUrl != null
                              ? NetworkImage(profileImageUrl!) as ImageProvider
                              : null),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 10,
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.6),
                        child: IconButton(
                          icon: const Icon(Icons.upload, color: Colors.white),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("User")
                      .doc(currentUser!.email)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data?.data() == null) {
                      return const Text("Loading...");
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final name = data['username'] ?? 'No Name';

                    return Column(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff1B1212),
                          ),
                        ),
                        Text(
                          currentUser!.email ?? '',
                          style: const TextStyle(color: Color(0xff1B1212)),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 40),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                  child: SizedBox(
                    height: 45,
                    child: TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Enter new name',
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelText: 'New Name',
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                  child: SizedBox(
                    height: 45,
                    child: TextFormField(
                      controller: oldPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelText: 'Old Password',
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                  child: SizedBox(
                    height: 45,
                    child: TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelText: 'New Password',
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff1B1212),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _saveChanges,
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
