
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spokencafe/Firebase/Firebase_Auth/Firebase_Auth_services.dart';
import 'package:spokencafe/model/Account/Log/Login.dart';
import 'package:spokencafe/model/NavBar/NavBar.dart';
import 'package:spokencafe/model/teacher/Verfied_Screen/Verfied_Screen.dart';

class Signup extends ConsumerStatefulWidget {
  const Signup({super.key});

  @override
  ConsumerState<Signup> createState() => _SignupState();
}

class _SignupState extends ConsumerState<Signup> {
  
  final FirebaseAuthServices _authServices = FirebaseAuthServices();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  File? _imageFile;
  Uint8List? pickedImage;
  bool _obscureText = true;
  bool isLoading = false;

  List<bool> isChecked = [false, false]; // [Student, Teacher]
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void toggleCheckbox(int index) {
    setState(() {
      for (int i = 0; i < isChecked.length; i++) {
        isChecked[i] = (i == index);
      }
    });
  }

  Future<File?> _pickImage() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      return File(result.files.single.path!);
    }
    return null;
  }

  Future<String?> _uploadImage(File image) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref =
          FirebaseStorage.instance.ref().child("profile_images/$fileName");

      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  Future<void> _signUpWithGoogle() async {
    if (!isChecked.contains(true)) {
      _showSnackBar('Please select either Student or Teacher role.', Colors.red);
      return;
    }

    try {
      setState(() => isLoading = true);
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        String role = isChecked[1] ? 'teacher' : 'student';
        String? uploadedImage =
            _imageFile != null ? await _uploadImage(_imageFile!) : null;

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': user.displayName ?? '',
          'email': user.email,
          'phone': _phoneController.text.trim(),
          'role': role,
          'profileImage': uploadedImage,
          'isVerified': role == 'teacher' ? false : true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => role == 'teacher' ? VerfiedScreen() : const Navbar(),
            ),
          );
        }
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red,);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

 Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    if (!isChecked.contains(true)) {
      _showSnackBar('Please select either Student or Teacher role.', Colors.red);
      return;
    }

    setState(() => isLoading = true);

    try {
      // Fix role assignment - index 0 is Teacher, index 1 is Student
      String role = isChecked[0] ? 'teacher' : 'student';

      final user = await _authServices.signUpWithEmailAndPassword(
        _nameController.text.trim(),
        _surnameController.text.trim(),
        _phoneController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _imageFile,
      );

      if (user != null) {
        String? uploadedImage =
            _imageFile != null ? await _uploadImage(_imageFile!) : null;

        // Save to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _nameController.text.trim(),
          'surname': _surnameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': role,
          'profileImage': uploadedImage,
          'isVerified': role == 'teacher' ? false : null,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Save role to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('role', role);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => role == 'teacher' ? VerfiedScreen() : const Navbar(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // ... (keep existing error handling)
    } catch (e) {
      // ... (keep existing error handling)
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
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
  Widget build(BuildContext context) {
    final List<String> signupFields = [
      'Name',
      'Surname',
      'Email',
      'Password',
      'Phone Number',
    ];

    final List<TextEditingController> controllers = [
      _nameController,
      _surnameController,
      _emailController,
      _passwordController,
      _phoneController,
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Create Account',style:TextStyle(
          color: Color(0xff1B1212),
          fontWeight: FontWeight.bold,
        ),),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios_new,color: Color(0xff1B1212),),
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(
               color:  Color(0xff1B1212),
                               backgroundColor: Colors.white,
            ),)
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : null,
                            child: _imageFile == null
                                ? const Icon(Icons.person, size: 40)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.add_a_photo),
                              onPressed: () async {
                                File? selectedImage = await _pickImage();
                                if (selectedImage != null) {
                                  setState(() {
                                    _imageFile = selectedImage;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: ElevatedButton.icon(
                          onPressed: _signUpWithGoogle,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Color(0xff1B1212),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          icon: const Icon(FontAwesomeIcons.google,
                              color: Colors.white),
                          label: const Text(
                            'Continue with Google',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              const Text('Teacher',style: TextStyle(
                                color: Color(0xff1B1212),
                              ),),
                              Checkbox(
                                activeColor: Color(0xff1B1212),
                                hoverColor: Color(0xff1B1212),
                                value: isChecked[0],
                                onChanged: (val) => toggleCheckbox(0),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Row(
                            children: [
                              const Text('Student',style: TextStyle(
                                color: Color(0xff1B1212),

                              ),),
                              Checkbox(
                                activeColor: Color(0xff1B1212),
                                hoverColor: Color(0xff1B1212),
                                value: isChecked[1],
                                onChanged: (val) => toggleCheckbox(1),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(signupFields.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 8),
                          child: TextFormField(
                            
                            controller: controllers[index],
                            obscureText: index == 3 ? _obscureText : false,
                            keyboardType: index == 4
                                ? TextInputType.phone
                                : TextInputType.text,
                            decoration: InputDecoration(
                              // focusedErrorBorder: OutlineInputBorder(
                              //   borderSide: BorderSide(
                              //     color: Colors.red,
                                  
                              //   ),
                              // ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0xff1B1212),
                                  width: 2,
                                ),
                              ),
                             // labelText: signupFields[index],
                              border: const OutlineInputBorder(),
                            hintText: signupFields[index],
                              suffixIcon: index == 3
                                  ? IconButton(
                                      icon: Icon(_obscureText
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () => setState(() {
                                        _obscureText = !_obscureText;
                                      }),
                                    )
                                  : null,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '${signupFields[index]} is required';
                              }
                              if (index == 2 && !value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              if (index == 3 && value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                        );
                      },),
                      Padding(
                        padding: const EdgeInsets.all(30),
                        child: ElevatedButton(
                          onPressed: _signUpWithEmail,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Color(0xff1B1212),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          text: 'Already have an account? ',
                          style: const TextStyle(color: Color(0xff1B1212),),
                          children: [
                            TextSpan(
                              text: 'Login',
                              style: const TextStyle(
                                  color: Color(0xff1B1212),
                                  fontWeight: FontWeight.bold),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const Login()),
                                  );
                                },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}



  // Future<void> _signUpWithEmail() async {
  //   if (!_formKey.currentState!.validate()) return;

  //   if (!isChecked.contains(true)) {
  //     _showSnackBar('Please select either Student or Teacher role.', Colors.red);
  //     return;
  //   }

  //   if (_nameController.text.trim().isEmpty ||
  //       _surnameController.text.trim().isEmpty ||
  //       _phoneController.text.trim().isEmpty ||
  //       _emailController.text.trim().isEmpty ||
  //       _passwordController.text.trim().isEmpty) {
  //     _showSnackBar('Please fill in all required fields.', Colors.red);
  //     return;
  //   }

  //   setState(() => isLoading = true);

  //   try {
  //     String role = isChecked[1] ? 'teacher' : 'student';

  //     final user = await _authServices.signUpWithEmailAndPassword(
  //       _nameController.text.trim(),
  //       _surnameController.text.trim(),
  //       _phoneController.text.trim(),
  //       _emailController.text.trim(),
  //       _passwordController.text.trim(),
  //       _imageFile,
  //     );

  //     if (user != null) {
  //       String? uploadedImage =
  //           _imageFile != null ? await _uploadImage(_imageFile!) : null;

  //       await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
  //         'name': _nameController.text.trim(),
  //         'surname': _surnameController.text.trim(),
  //         'email': _emailController.text.trim(),
  //         'phone': _phoneController.text.trim(),
  //         'role': role,
  //         'profileImage': uploadedImage,
  //         'isVerified': role == 'teacher' ? false : null,
  //         'createdAt': FieldValue.serverTimestamp(),
  //       });

  //       if (!mounted) return;
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(
  //           builder: (_) => role == 'teacher' ? VerfiedScreen() : const Navbar(),
  //         ),
  //       );
  //     }
  //   } on FirebaseAuthException catch (e) {
  //     String message = 'Signup failed. Try again.';
  //     if (e.code == 'email-already-in-use') {
  //       message = 'This email is already registered.';
  //     } else if (e.code == 'weak-password') {
  //       message = 'Password should be at least 6 characters.';
  //     }
  //     if (!mounted) return;
  //     _showSnackBar(message, Colors.red);
  //   } catch (e) {
  //     if (!mounted) return;
  //     _showSnackBar('Error: ${e.toString()}', Colors.red);
  //   } finally {
  //     if (mounted) setState(() => isLoading = false);
  //   }
  // }