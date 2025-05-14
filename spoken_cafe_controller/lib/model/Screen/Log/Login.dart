import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:spoken_cafe_controller/SidBar/SideBar.dart';
import 'package:spoken_cafe_controller/model/Screen/Home/Home.dart';
import 'package:spoken_cafe_controller/firebase_options.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  final _formKey = GlobalKey<FormState>();
  StreamSubscription<User?>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
  }

  // Navigate to Sidebar (desktop) or Home (mobile)
  void _navigateToMainScreen() {
    final isDesktop = Platform.isWindows || Platform.isMacOS;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => isDesktop ? const Sidebar() : const Home(),
      ),
    );
  }

  Future<void> signIn() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Sign in with Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Log login details in Firestore
      await FirebaseFirestore.instance.collection('admins').doc(userCredential.user!.uid).set({
        'email': email,
        'lastLogin': FieldValue.serverTimestamp(),
        'ip': 'N/A',
      }, SetOptions(merge: true));

      // Navigate to Sidebar (desktop) or Home (mobile)
      if (mounted) {
        _navigateToMainScreen();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = "No account found with this email.";
          break;
        case 'wrong-password':
          errorMessage = "Incorrect password.";
          break;
        case 'invalid-email':
          errorMessage = "Invalid email format.";
          break;
        case 'user-disabled':
          errorMessage = "This account has been disabled.";
          break;
        default:
          errorMessage = "Login failed. Please try again.";
      }
      if (mounted) {
        setState(() => _errorMessage = errorMessage);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "An unexpected error occurred.");
      }
      print("Login error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Firebase.apps.isEmpty
          ? Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
          : Future.value(Firebase.app('[DEFAULT]')),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Firebase Error: ${snapshot.error}')),
          );
        }

        // Initialize auth state listener after Firebase is ready
        if (_authStateSubscription == null) {
          _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
            if (user != null && mounted) {
              _navigateToMainScreen();
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Spoken Cafe Control',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25),
            ),
          ),
          body: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(50),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey[200],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/images/spken_cafe.png',
                          width: 100,
                          height: 100,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Admin Login',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Admin Email',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.email),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter email';
                            }
                            return null;
                          },
                          keyboardType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 20),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.lock),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Error Message
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 30),

                        // Login Button
                        SizedBox(
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'LOGIN',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
// import 'dart:async';
// import 'dart:io' show Platform;
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:spoken_cafe_controller/SidBar/SideBar.dart';
// import 'package:spoken_cafe_controller/model/Screen/Home/Home.dart';

// class Login extends StatefulWidget {
//   const Login({super.key});

//   @override
//   State<Login> createState() => _LoginState();
// }

// class _LoginState extends State<Login> {
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   bool _isLoading = false;
//   String? _errorMessage;
//   final _formKey = GlobalKey<FormState>();
//   StreamSubscription<User?>? _authStateSubscription;

//   FirebaseAuth _auth = FirebaseAuth.instance;
//   FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   @override
//   void initState() {
//     super.initState();
//     // Check if user is already logged in
//     _authStateSubscription = _auth.authStateChanges().listen((User? user) {
//       if (user != null && mounted) {
//         _navigateToMainScreen();
//       }
//     });
//   }

//   // Navigate to Sidebar (desktop) or Home (mobile)
//   void _navigateToMainScreen() {
//     final isDesktop = Platform.isMacOS || Platform.isWindows;
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(
//         builder: (context) => isDesktop ? const Sidebar() : const Home(),
//       ),
//     );
//   }

//   Future<void> signIn() async {
//     if (!_formKey.currentState!.validate()) return;

//     if (!mounted) return;

//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });

//     try {
//       final email = _emailController.text.trim();
//       final password = _passwordController.text.trim();

//       // Sign in with Firebase Authentication
//       UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );

//       // Log login details in Firestore
//       await _firestore.collection('admins').doc(userCredential.user!.uid).set({
//         'email': email,
//         'lastLogin': FieldValue.serverTimestamp(),
//         'ip': 'N/A',
//       }, SetOptions(merge: true));

//       // Navigate to Sidebar (desktop) or Home (mobile)
//       if (mounted) {
//         _navigateToMainScreen();
//       }
//     } on FirebaseAuthException catch (e) {
//       String errorMessage;
//       switch (e.code) {
//         case 'user-not-found':
//           errorMessage = "No account found with this email.";
//           break;
//         case 'wrong-password':
//           errorMessage = "Incorrect password.";
//           break;
//         case 'invalid-email':
//           errorMessage = "Invalid email format.";
//           break;
//         case 'user-disabled':
//           errorMessage = "This account has been disabled.";
//           break;
//         default:
//           errorMessage = "Login failed. Please try again.";
//       }
//       if (mounted) {
//         setState(() => _errorMessage = errorMessage);
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _errorMessage = "An unexpected error occurred.");
//       }
//       print("Login error: $e");
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Spoken Cafe Control',
//           textAlign: TextAlign.center,
//           style: TextStyle(fontSize: 25),
//         ),
//       ),
//       body: SingleChildScrollView(
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Container(
//                 margin: const EdgeInsets.all(20),
//                 padding: const EdgeInsets.all(50),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(10),
//                   color: Colors.grey[200],
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     Image.asset(
//                       'assets/images/spken_cafe.png',
//                       width: 100,
//                       height: 100,
//                     ),
//                     const SizedBox(height: 20),
//                     const Text(
//                       'Admin Login',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontSize: 30,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 30),

//                     // Email Field
//                     TextFormField(
//                       controller: _emailController,
//                       decoration: InputDecoration(
//                         labelText: 'Admin Email',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         prefixIcon: const Icon(Icons.email),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter email';
//                         }
//                         return null;
//                       },
//                       keyboardType: TextInputType.emailAddress,
//                     ),

//                     const SizedBox(height: 20),

//                     // Password Field
//                     TextFormField(
//                       controller: _passwordController,
//                       obscureText: true,
//                       decoration: InputDecoration(
//                         labelText: 'Password',
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         prefixIcon: const Icon(Icons.lock),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter password';
//                         }
//                         if (value.length < 6) {
//                           return 'Password must be at least 6 characters';
//                         }
//                         return null;
//                       },
//                     ),

//                     const SizedBox(height: 20),

//                     // Error Message
//                     if (_errorMessage != null)
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 20),
//                         child: Text(
//                           _errorMessage!,
//                           style: const TextStyle(
//                             color: Colors.red,
//                             fontSize: 16,
//                           ),
//                           textAlign: TextAlign.center,
//                         ),
//                       ),

//                     const SizedBox(height: 30),

//                     // Login Button
//                     SizedBox(
//                       height: 55,
//                       child: ElevatedButton(
//                         onPressed: _isLoading ? null : signIn,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.black,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           padding: const EdgeInsets.symmetric(vertical: 15),
//                         ),
//                         child: _isLoading
//                             ? const SizedBox(
//                                 width: 20,
//                                 height: 20,
//                                 child: CircularProgressIndicator(
//                                   color: Colors.white,
//                                   strokeWidth: 2,
//                                 ),
//                               )
//                             : const Text(
//                                 'LOGIN',
//                                 style: TextStyle(
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.bold,
//                                   letterSpacing: 1.2,
//                                 ),
//                               ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _authStateSubscription?.cancel();
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }
// }
// // this is password is very important
// //spoken@cafe.com
// //spoken@cafe@@22.. 
