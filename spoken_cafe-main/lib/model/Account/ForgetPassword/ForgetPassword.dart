

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ForgetPassword extends ConsumerStatefulWidget {
  const ForgetPassword({super.key});

  @override
  ConsumerState<ForgetPassword> createState() => _ForgetPasswordState();
}

class _ForgetPasswordState extends ConsumerState<ForgetPassword> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isEmailEmpty = true;

  @override
  void initState() {
    super.initState();
    // Add a listener to track changes in the text field
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    // Remove the listener and dispose of the controller
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    // Update the button state based on email input
    setState(() {
      _isEmailEmpty = _emailController.text.trim().isEmpty;
    });
  }

  Future<void> forgetPassword() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      // Clear the email field after sending the reset link
      _emailController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.green,
          content: Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'Password reset link sent! Check your email',
            ),
          ),
        ),
      );

      // Update the button state
      setState(() {
        _isEmailEmpty = true;
      });
    } on FirebaseAuthException catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.red,
          content: Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              e.message ?? 'An error occurred',
              style: TextStyle(fontSize: 16),
            ),
          ),
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
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.arrow_back_ios_new,
          ),
        ),
        backgroundColor: Colors.white,
        title: Text(
          'Forget Password',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.all(20),
          children: [
            const SizedBox(height: 40),
            TextFormField(
              controller: _emailController, // Connect the controller
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                hintText: 'Enter your Email',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 45),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isEmailEmpty ? Colors.grey : Color(0xff1B1212), // Dynamic color
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isEmailEmpty
                  ? null
                  : forgetPassword, // Disable button if empty
              child: Text(
                'Send',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
