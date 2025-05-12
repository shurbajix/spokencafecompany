import 'dart:io';

import 'package:blurrycontainer/blurrycontainer.dart';
import 'package:file_picker/file_picker.dart';
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
  File? _isSelctedUpdate;
  bool _isDescriptionFilled = false;

  final TextEditingController _descriptionControll = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isImageSelected = false;
  File? _selectedVideo;
  bool _isVideoSelected = false;
  bool _isFirstUploadDone = false; // Track if the first upload is done
  bool _isSecondUploadDone = false;

  Future<void> pickVideo() async {
    try {
      FilePickerResult? result =
          await FilePicker.platform.pickFiles(type: FileType.video);
      if (result != null) {
        setState(() {
          _selectedVideo = File(result.files.single.path!);
          _isVideoSelected = true;
          _isFirstUploadDone = true; // Mark first upload as done
        });
        print('Selected video path: ${result.files.single.path}');
      } else {
        print('No video selected.');
      }
    } catch (e) {
      print('Error picking video: $e');
    }
  }

  Future<void> pickeImage() async {
    try {
      final PickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (PickedFile != null) {
        setState(() {
          _selectedImage = File(PickedFile.path);
          _isImageSelected = true;
          _isSecondUploadDone = true; // Mark first upload as done
        });
        print('Selected image path: ${PickedFile.path}');
      } else {
        print('No image selected.');
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  bool get isSaveEnabled =>
      _isVideoSelected && _isImageSelected && _isDescriptionFilled;

  @override
  void dispose() {
    _descriptionControll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomSheet: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
        child: SizedBox(
          height: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isSaveEnabled ? const Color(0xff3D5CFF) : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Navbar(),
                      ),
                    );
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white, fontSize: 25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Verfied Page',
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
                      child: IconButton(
                        onPressed: pickVideo,
                        icon: const Icon(Icons.add, size: 80),
                      ),
                    ),
                  ),
                  if (_selectedVideo != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Selected Video: ${_selectedVideo!.path.split('/').last}',
                        style:
                            const TextStyle(fontSize: 16, color: Colors.black),
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
                          color: _isVideoSelected ? Colors.green : Colors.black,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _isFirstUploadDone ? pickVideo : null,
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
                onChanged: (value) {
                  setState(() {
                    _isDescriptionFilled = value.trim().isNotEmpty;
                  });
                },
                decoration: InputDecoration(
                  suffixIcon: Icon(
                    Icons.verified,
                    color: _isDescriptionFilled ? Colors.green : Colors.black,
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
            const SizedBox(height: 7),
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
                              onPressed: pickeImage,
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
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //   children: [
                  //     Padding(
                  //       padding: const EdgeInsets.all(8.0),
                  //       child: Icon(
                  //         Icons.verified,
                  //         color: _isImageSelected ? Colors.green : Colors.black,
                  //       ),
                  //     ),
                  //     Row(
                  //       children: [
                  //         IconButton(
                  //           onPressed: _isSecondUploadDone
                  //               ? pickeImage
                  //               : null, // Enable update only after first upload
                  //           icon: const Icon(Icons.update),
                  //         ),
                  //         IconButton(
                  //           onPressed: () {
                  //             showDialog(
                  //               barrierDismissible: false,
                  //               context: context,
                  //               builder: (context) => AlertDialog(
                  //                 backgroundColor: Colors.grey[200],
                  //                 title: const Text('About Upload doucoment'),
                  //                 contentPadding: const EdgeInsets.all(20),
                  //                 content: const Text(
                  //                     'upload doucoment you should upload your certifcation or upload id card and we will saw and accept'),
                  //                 actions: [
                  //                   TextButton(
                  //                     onPressed: () {
                  //                       Navigator.pop(context);
                  //                     },
                  //                     child: const Text(
                  //                       'Close',
                  //                       style: TextStyle(
                  //                           color: Colors.black, fontSize: 20),
                  //                     ),
                  //                   ),
                  //                 ],
                  //               ),
                  //             );
                  //           },
                  //           icon: const Icon(
                  //             Icons.info,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),
            SizedBox(
              height: 90,
            ),
          ],
        ),
      ),
    );
  }
}

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// class VerfiedScreen extends ConsumerStatefulWidget {
//   const VerfiedScreen({super.key});

//   @override
//   ConsumerState<VerfiedScreen> createState() => _VerfiedScreenState();
// }

// class _VerfiedScreenState extends ConsumerState<VerfiedScreen> {
//   // File? _selectedVideo;
//   // File? _selectedImage;

//   // bool _isVideoSelected = false;
//   // bool _isImageSelected = false;
//   bool _isDescriptionFilled = false;

//   final TextEditingController _descriptionController = TextEditingController();

//   // Future<void> pickVideo() async {
//   //   // Skipped
//   // }

//   // Future<void> pickImage() async {
//   //   // Skipped
//   // }

//   bool get isSaveEnabled => _isDescriptionFilled;

//   Future<void> submitToFirestore() async {
//     try {
//       await FirebaseFirestore.instance.collection('verifiedTeachers').add({
//         'description': _descriptionController.text.trim(),
//         'timestamp': FieldValue.serverTimestamp(),
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Description submitted to Firestore!')),
//       );
//     } catch (e) {
//       print('Firestore error: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e')),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _descriptionController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Verified Page'),
//         centerTitle: true,
//       ),
//       bottomSheet: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: ElevatedButton(
//           onPressed: isSaveEnabled ? submitToFirestore : null,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: isSaveEnabled ? Colors.blue : Colors.grey,
//             minimumSize: const Size(double.infinity, 50),
//           ),
//           child: const Text('Save', style: TextStyle(fontSize: 18)),
//         ),
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(20),
//         children: [
//           const Text('Description', style: TextStyle(fontSize: 18)),
//           const SizedBox(height: 10),
//           TextField(
//             controller: _descriptionController,
//             maxLines: 3,
//             decoration: InputDecoration(
//               border: OutlineInputBorder(),
//               hintText: 'Write about yourself...',
//               suffixIcon: Icon(
//                 Icons.check_circle,
//                 color: _isDescriptionFilled ? Colors.green : Colors.grey,
//               ),
//             ),
//             onChanged: (value) {
//               setState(() {
//                 _isDescriptionFilled = value.trim().isNotEmpty;
//               });
//             },
//           ),
//           const SizedBox(height: 100),

//           // const Text('Upload Video (disabled)'),
//           // const SizedBox(height: 10),
//           // GestureDetector(
//           //   onTap: null,
//           //   child: Container(
//           //     height: 150,
//           //     color: Colors.grey[300],
//           //     child: const Center(child: Icon(Icons.video_call, size: 50)),
//           //   ),
//           // ),

//           // const SizedBox(height: 30),
//           // const Text('Upload Image (disabled)'),
//           // const SizedBox(height: 10),
//           // GestureDetector(
//           //   onTap: null,
//           //   child: Container(
//           //     height: 150,
//           //     color: Colors.grey[300],
//           //     child: const Center(child: Icon(Icons.image, size: 50)),
//           //   ),
//           // ),
//         ],
//       ),
//     );
//   }
// }
