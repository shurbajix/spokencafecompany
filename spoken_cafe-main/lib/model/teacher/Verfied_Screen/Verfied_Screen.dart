
import 'dart:io';

import 'package:blurrycontainer/blurrycontainer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:spokencafe/model/NavBar/NavBar.dart';

class VerfiedScreen extends ConsumerStatefulWidget {
  const VerfiedScreen({super.key});

  @override
  ConsumerState<VerfiedScreen> createState() => _VerfiedScreenState();
}

class _VerfiedScreenState extends ConsumerState<VerfiedScreen> {
  File? _selectedImage;
  File? _selectedVideo;
  final TextEditingController _descriptionControll =
      TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isImageSelected = false;
  bool _isVideoSelected = false;
  bool _isDescriptionFilled = false;
  bool _isSubmitting = false;

  Future<void> pickVideo() async {
    try {
      final pickedFile =
          await _picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedVideo = File(pickedFile.path);
          _isVideoSelected = true;
        });
      }
    } catch (e) {
      print('Error picking video: $e');
      _showSnackBar('Error picking video: $e', Colors.red);
    }
  }

  Future<void> pickImage() async {
    try {
      final pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _isImageSelected = true;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      _showSnackBar('Error picking image: $e', Colors.red);
    }
  }

  Future<String?> _uploadFile(File file, String folder) async {
    try {
      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}.${folder == 'verification_videos' ? 'mp4' : 'jpg'}';
      Reference ref = FirebaseStorage.instance
          .ref()
          .child("$folder/${FirebaseAuth.instance.currentUser!.uid}/$fileName");
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  Future<void> _submitVerification() async {
    if (!isSaveEnabled) {
      _showSnackBar('Please complete all required fields', Colors.red);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('User not authenticated', Colors.red);
        setState(() => _isSubmitting = false);
        return;
      }

      String? videoUrl = _selectedVideo != null
          ? await _uploadFile(_selectedVideo!, 'verification_videos')
          : null;
      String? imageUrl = _selectedImage != null
          ? await _uploadFile(_selectedImage!, 'verification_documents')
          : null;

      if (videoUrl == null || imageUrl == null) {
        _showSnackBar('Error uploading files', Colors.red);
        setState(() => _isSubmitting = false);
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'verificationVideo': videoUrl,
        'verificationDocument': imageUrl,
        'verificationDescription': _descriptionControll.text.trim(),
        'isVerified': false,
        'verificationSubmittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('media').add({
        'userId': user.uid,
        'url': videoUrl,
        'type': 'video',
        'description': _descriptionControll.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnackBar(
          'Verification submitted. Awaiting admin approval.', Colors.green);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Navbar()),
        );
      }
    } catch (e) {
      print('Submission error: $e');
      _showSnackBar('Error submitting verification: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool get isSaveEnabled =>
      _isVideoSelected && _isImageSelected && _isDescriptionFilled;

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionControll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomSheet: SizedBox(
        height: 60,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSaveEnabled && !_isSubmitting
                      ? const Color(0xff3D5CFF)
                      : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isSaveEnabled && !_isSubmitting
                    ? _submitVerification
                    : null,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit',
                        style: TextStyle(color: Colors.white, fontSize: 25),
                      ),
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Verification Page',
          style: TextStyle(color: Colors.black, fontSize: 30),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            const Text(
              'Upload Video',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  BlurryContainer(
                    elevation: 0,
                    height: 190,
                    blur: 5,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: Center(
                      child: _selectedVideo == null
                          ? IconButton(
                              onPressed: _isSubmitting ? null : pickVideo,
                              icon: const Icon(Icons.add, size: 80),
                            )
                          : const Text(
                              'Video Selected',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.black),
                            ),
                    ),
                  ),
                  if (_selectedVideo != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Selected Video: ${_selectedVideo!.path.split('/').last}',
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.verified,
                          color:
                              _isVideoSelected ? Colors.green : Colors.black,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _isSubmitting ? null : pickVideo,
                            icon: const Icon(Icons.update),
                          ),
                          IconButton(
                            onPressed: () {
                              showDialog(
                                barrierDismissible: false,
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.grey[200],
                                  title: const Text('About Upload Video'),
                                  contentPadding: const EdgeInsets.all(20),
                                  content: const Text(
                                    'The video you will upload should explain about yourself (1–2 minutes). If you upload something else, your account may be rejected.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text(
                                        'Close',
                                        style: TextStyle(
                                            color: Colors.black, fontSize: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.info),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Description',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextFormField(
                keyboardType: TextInputType.multiline,
                maxLines: null,
                controller: _descriptionControll,
                enabled: !_isSubmitting,
                onChanged: (value) {
                  setState(() {
                    _isDescriptionFilled = value.trim().isNotEmpty;
                  });
                },
                decoration: InputDecoration(
                  suffixIcon: Icon(
                    Icons.verified,
                    color:
                        _isDescriptionFilled ? Colors.green : Colors.black,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  fillColor: Colors.grey[200],
                  filled: true,
                  contentPadding: const EdgeInsets.all(50),
                  hintText: 'Explain about yourself by writing',
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Document',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BlurryContainer(
                    elevation: 0,
                    height: 190,
                    blur: 5,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: Center(
                      child: _selectedImage == null
                          ? IconButton(
                              onPressed: _isSubmitting ? null : pickImage,
                              icon: const Icon(Icons.add, size: 80),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 190,
                              ),
                            ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.verified,
                          color:
                              _isImageSelected ? Colors.green : Colors.black,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _isSubmitting ? null : pickImage,
                            icon: const Icon(Icons.update),
                          ),
                          IconButton(
                            onPressed: () {
                              showDialog(
                                barrierDismissible: false,
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.grey[200],
                                  title:
                                      const Text('About Upload Document'),
                                  contentPadding: const EdgeInsets.all(20),
                                  content: const Text(
                                    'Upload your certification or ID card. We will review and approve your submission.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context),
                                      child: const Text(
                                        'Close',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.info),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}
