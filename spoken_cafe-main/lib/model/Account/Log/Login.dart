// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:spokencafe/Firebase/Firebase_Auth/Firebase_Auth_services.dart';
// import 'package:spokencafe/model/Account/ForgetPassword/ForgetPassword.dart';
// import 'package:spokencafe/model/Account/SingUp/SingUp.dart';
// import 'package:spokencafe/model/NavBar/NavBar.dart';

// // Constants
// List<String> buttonLogin = [
//   'Login',
//   'Create an Account',
// ];

// List<String> loginChoose = [
//   'Email',
//   'Password',
// ];

// class Login extends ConsumerStatefulWidget {
//   const Login({super.key});

//   @override
//   ConsumerState<Login> createState() => _LoginState();
// }

// class _LoginState extends ConsumerState<Login> {
//   final _formKey = GlobalKey<FormState>();
//   bool isLoading = false;
//   bool? _obscureText = true;

//   final FirebaseAuthServices _authServices = FirebaseAuthServices();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();

//   final GoogleSignIn _googleSignIn = GoogleSignIn();

//   void _toggle() {
//     setState(() {
//       _obscureText = !_obscureText!;
//     });
//   }

//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         centerTitle: true,
//         backgroundColor: Colors.white,
//         leading: IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: const Icon(Icons.arrow_back_ios_new),
//         ),
//         title: const Text(
//           'Welcome back!',
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             color: Colors.black,
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ),
//       body: Form(
//         key: _formKey,
//         child: ListView(
//           shrinkWrap: true,
//           children: [
//             const SizedBox(height: 40),
//             Column(
//               children: List.generate(
//                 loginChoose.length,
//                 (index) {
//                   return Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 40),
//                         child: Text(loginChoose[index]),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.symmetric(
//                           vertical: 10,
//                           horizontal: 40,
//                         ),
//                         child: TextFormField(
//                           obscureText: index == 1 ? _obscureText! : false,
//                           controller: index == 0
//                               ? _emailController
//                               : _passwordController,
//                           decoration: InputDecoration(
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                             hintText: loginChoose[index],
//                             suffixIcon: index == 1
//                                 ? IconButton(
//                                     onPressed: _toggle,
//                                     icon: _obscureText!
//                                         ? const Icon(Icons.visibility)
//                                         : const Icon(Icons.visibility_off),
//                                   )
//                                 : null,
//                           ),
//                           validator: (value) {
//                             if (value == null || value.isEmpty) {
//                               return 'Please enter ${loginChoose[index]}';
//                             }
//                             return null;
//                           },
//                         ),
//                       ),
//                     ],
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 20),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: List.generate(
//                 2,
//                 (index) {
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 40,
//                       vertical: 10,
//                     ),
//                     child: SizedBox(
//                       height: 55,
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           backgroundColor:
//                               index == 0 ? Colors.blue : Colors.white,
//                         ),
//                         onPressed: () {
//                           if (index == 0) {
//                             _signInWithRole();
//                           } else {
//                             Navigator.push(
//                               context,
//                               PageRouteBuilder(
//                                 pageBuilder:
//                                     (context, animation, secondaryAnimation) =>
//                                         const Signup(),
//                                 transitionsBuilder: (context, animation,
//                                     secondaryAnimation, child) {
//                                   const begin = Offset(1.0, 0.0);
//                                   const end = Offset.zero;
//                                   const curve = Curves.easeInOut;

//                                   final tween = Tween(begin: begin, end: end)
//                                       .chain(CurveTween(curve: curve));

//                                   return SlideTransition(
//                                     position: animation.drive(tween),
//                                     child: child,
//                                   );
//                                 },
//                               ),
//                             );
//                           }
//                         },
//                         child: index == 0
//                             ? isLoading
//                                 ? const CircularProgressIndicator(
//                                     color: Colors.white,
//                                   )
//                                 : Text(
//                                     buttonLogin[index],
//                                     style: const TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 16,
//                                     ),
//                                   )
//                             : Text(
//                                 buttonLogin[index],
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontSize: 16,
//                                 ),
//                               ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.only(right: 40),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   const ForgetPassword(),
//                           transitionsBuilder:
//                               (context, animation, secondaryAnimation, child) {
//                             const begin = Offset(1.0, 0.0);
//                             const end = Offset.zero;
//                             const curve = Curves.easeInOut;

//                             final tween = Tween(begin: begin, end: end)
//                                 .chain(CurveTween(curve: curve));

//                             return SlideTransition(
//                               position: animation.drive(tween),
//                               child: child,
//                             );
//                           },
//                         ),
//                       );
//                     },
//                     child: const Text(
//                       'Forget Password',
//                       style: TextStyle(color: Colors.black),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 20),
//             const Text(
//               'Login with Google',
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 16,
//                 color: Colors.grey,
//               ),
//             ),
//             const SizedBox(height: 20),
//             Padding(
//               padding: const EdgeInsets.symmetric(
//                 horizontal: 30,
//                 vertical: 10,
//               ),
//               child: SizedBox(
//                 height: 55,
//                 child: ElevatedButton.icon(
//                   style: ElevatedButton.styleFrom(
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     backgroundColor: Colors.blue,
//                   ),
//                   onPressed: () {
//                     _signInWithGoogle();
//                   },
//                   label: const Text(
//                     'Google',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 20,
//                     ),
//                   ),
//                   icon: const Icon(
//                     FontAwesomeIcons.google,
//                     color: Colors.white,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _signInWithRole() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => isLoading = true);

//     try {
//       final user = await _authServices.signInWithEmailAndPassword(
//         _emailController.text.trim(),
//         _passwordController.text.trim(),
//       );

//       if (user != null && mounted) {
//         final userDoc = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .get();

//         if (userDoc.exists) {
//           final role = userDoc.data()?['role'];

//           if (role == 'student' || role == 'teacher' || role == 'admin') {
//             final prefs = await SharedPreferences.getInstance();
//             await prefs.setString('role', role);

//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(
//                 builder: (_) => const Navbar(),
//               ),
//             );
//           } else {
//             _showSnackBar('Invalid or missing role');
//           }
//         } else {
//           _showSnackBar('User document not found');
//         }
//       }
//     } on FirebaseAuthException catch (e) {
//       String message = 'Login failed. Email or password is incorrect.';
//       if (e.code == 'user-not-found') {
//         message = 'No user found with this email.';
//       } else if (e.code == 'wrong-password') {
//         message = 'Incorrect password.';
//       }
//       _showSnackBar(message);
//     } catch (e) {
//       _showSnackBar('Error: ${e.toString()}');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   Future<void> _signInWithGoogle() async {
//     try {
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

//       if (googleUser == null) {
//         // The user canceled the sign-in
//         return;
//       }

//       final GoogleSignInAuthentication googleAuth =
//           await googleUser.authentication;

//       final AuthCredential credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );

//       final UserCredential userCredential =
//           await FirebaseAuth.instance.signInWithCredential(credential);
//       final user = userCredential.user;

//       if (user != null) {
//         final userDoc = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .get();

//         if (userDoc.exists) {
//           final role = userDoc.data()?['role'];

//           if (role == 'student' || role == 'teacher' || role == 'admin') {
//             final prefs = await SharedPreferences.getInstance();
//             await prefs.setString('role', role);

//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (_) => const Navbar()),
//             );
//           } else {
//             _showSnackBar('Invalid or missing role');
//           }
//         } else {
//           _showSnackBar('User document not found');
//         }
//       }
//     } on FirebaseAuthException catch (e) {
//       _showSnackBar('Google sign-in failed: ${e.message}');
//     } catch (e) {
//       _showSnackBar('Error: ${e.toString()}');
//     }
//   }

//   void _showSnackBar(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         backgroundColor: Colors.red,
//         margin: const EdgeInsets.all(10),
//         behavior: SnackBarBehavior.floating,
//         content: Text(message),
//       ),
//     );
//   }
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spokencafe/Firebase/Firebase_Auth/Firebase_Auth_services.dart';
import 'package:spokencafe/model/Account/ForgetPassword/ForgetPassword.dart';
import 'package:spokencafe/model/Account/SingUp/SingUp.dart';
import 'package:spokencafe/model/NavBar/NavBar.dart';
import 'package:spokencafe/model/teacher/Verfied_Screen/Verfied_Screen.dart';


// Constants
List<String> buttonLogin = [
  'Login',
  'Create an Account',
];

List<String> loginChoose = [
  'Email',
  'Password',
];

class Login extends ConsumerStatefulWidget {
  const Login({super.key});

  @override
  ConsumerState<Login> createState() => _LoginState();
}

class _LoginState extends ConsumerState<Login> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool _obscureText = true;

  final FirebaseAuthServices _authServices = FirebaseAuthServices();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  void _toggle() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithRole() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final user = await _authServices.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null && mounted) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final role = userDoc.data()?['role'] ?? 'student';
          final isVerified = userDoc.data()?['isVerified'] ?? true; // Default to true for students

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('role', role);

          if (mounted) {
            if (role == 'teacher' && !isVerified) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const VerfiedScreen()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const Navbar()),
              );
            }
          }
        } else {
          _showSnackBar('User document not found');
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Email or password is incorrect.';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      }
      _showSnackBar(message);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => isLoading = false);
        return; // User canceled sign-in
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null && mounted) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final role = userDoc.data()?['role'] ?? 'student';
          final isVerified = userDoc.data()?['isVerified'] ?? true; // Default to true for students

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('role', role);

          if (mounted) {
            if (role == 'teacher' && !isVerified) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const VerfiedScreen()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const Navbar()),
              );
            }
          }
        } else {
          _showSnackBar('User document not found');
        }
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Google sign-in failed: ${e.message}');
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        margin: const EdgeInsets.all(10),
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
        title: const Text(
          'Welcome back!',
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
          children: [
            const SizedBox(height: 40),
            Column(
              children: List.generate(
                loginChoose.length,
                (index) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(loginChoose[index]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 40,
                        ),
                        child: TextFormField(
                          obscureText: index == 1 ? _obscureText : false,
                          controller: index == 0
                              ? _emailController
                              : _passwordController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            hintText: loginChoose[index],
                            suffixIcon: index == 1
                                ? IconButton(
                                    onPressed: _toggle,
                                    icon: Icon(
                                      _obscureText
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.black,
                                    ),
                                  )
                                : null,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter ${loginChoose[index]}';
                            }
                            if (index == 0 && !value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            if (index == 1 && value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(
                2,
                (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 10,
                    ),
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: Color(0xff1B1212),
                        ),
                        onPressed: () {
                          if (index == 0) {
                            _signInWithRole();
                          } else {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const Signup(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeInOut;

                                  final tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));

                                  return SlideTransition(
                                    position: animation.drive(tween),
                                    child: child,
                                  );
                                },
                              ),
                            );
                          }
                        },
                        child: index == 0 && isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                backgroundColor: Color(0xff1B1212),
                              )
                            : Text(
                                buttonLogin[index],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const ForgetPassword(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            const begin = Offset(1.0, 0.0);
                            const end = Offset.zero;
                            const curve = Curves.easeInOut;

                            final tween = Tween(begin: begin, end: end)
                                .chain(CurveTween(curve: curve));

                            return SlideTransition(
                              position: animation.drive(tween),
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                    child: const Text(
                      'Forget Password',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Login with Google',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 10,
              ),
              child: SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Color(0xff1B1212),
                  ),
                  onPressed: _signInWithGoogle,
                  label: const Text(
                    'Google',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  icon: const Icon(
                    FontAwesomeIcons.google,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:spokencafe/Firebase/Firebase_Auth/Firebase_Auth_services.dart';
// import 'package:spokencafe/model/Account/ForgetPassword/ForgetPassword.dart';
// import 'package:spokencafe/model/Account/SingUp/SingUp.dart';
// import 'package:spokencafe/model/NavBar/NavBar.dart';

// import 'package:spokencafe/model/teacher/Verfied_Screen/Verfied_Screen.dart'; // Make sure to import your VerifiedScreen

// // Constants
// List<String> buttonLogin = [
//   'Login',
//   'Create an Account',
// ];

// List<String> loginChoose = [
//   'Email',
//   'Password',
// ];

// class Login extends ConsumerStatefulWidget {
//   const Login({super.key});

//   @override
//   ConsumerState<Login> createState() => _LoginState();
// }

// class _LoginState extends ConsumerState<Login> {
//   final _formKey = GlobalKey<FormState>();
//   bool isLoading = false;
//   bool? _obscureText = true;

//   final FirebaseAuthServices _authServices = FirebaseAuthServices();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();

//   final GoogleSignIn _googleSignIn = GoogleSignIn();

//   void _toggle() {
//     setState(() {
//       _obscureText = !_obscureText!;
//     });
//   }

//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         centerTitle: true,
//         backgroundColor: Colors.white,
//         leading: IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: const Icon(Icons.arrow_back_ios_new),
//         ),
//         title: const Text(
//           'Welcome back!',
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             color: Colors.black,
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ),
//       body: Form(
//         key: _formKey,
//         child: ListView(
//           shrinkWrap: true,
//           children: [
//             const SizedBox(height: 40),
//             Column(
//               children: List.generate(
//                 loginChoose.length,
//                 (index) {
//                   return Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 40),
//                         child: Text(loginChoose[index]),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.symmetric(
//                           vertical: 10,
//                           horizontal: 40,
//                         ),
//                         child: TextFormField(
//                           obscureText: index == 1 ? _obscureText! : false,
//                           controller: index == 0
//                               ? _emailController
//                               : _passwordController,
//                           decoration: InputDecoration(
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                             hintText: loginChoose[index],
//                             suffixIcon: index == 1
//                                 ? IconButton(
//                                     onPressed: _toggle,
//                                     icon: _obscureText!
//                                         ? const Icon(Icons.visibility,)
//                                         : const Icon(Icons.visibility_off,),
//                                   )
//                                 : null,
//                           ),
//                           validator: (value) {
//                             if (value == null || value.isEmpty) {
//                               return 'Please enter ${loginChoose[index]}';
//                             }
//                             return null;
//                           },
//                         ),
//                       ),
//                     ],
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 20),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: List.generate(
//                 2,
//                 (index) {
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 40,
//                       vertical: 10,
//                     ),
//                     child: SizedBox(
//                       height: 55,
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(10),
//                           ),
//                           backgroundColor:
//                               index == 0 ? Color(0xff1B1212) : Color(0xff1B1212),
//                         ),
//                         onPressed: () {
//                           if (index == 0) {
//                             _signInWithRole();
//                           } else {
//                             Navigator.push(
//                               context,
//                               PageRouteBuilder(
//                                 pageBuilder:
//                                     (context, animation, secondaryAnimation) =>
//                                         const Signup(),
//                                 transitionsBuilder: (context, animation,
//                                     secondaryAnimation, child) {
//                                   const begin = Offset(1.0, 0.0);
//                                   const end = Offset.zero;
//                                   const curve = Curves.easeInOut;

//                                   final tween = Tween(begin: begin, end: end)
//                                       .chain(CurveTween(curve: curve));

//                                   return SlideTransition(
//                                     position: animation.drive(tween),
//                                     child: child,
//                                   );
//                                 },
//                               ),
//                             );
//                           }
//                         },
//                         child: index == 0
//                             ? isLoading
//                                 ? const CircularProgressIndicator(
//                                      color:  Color(0xff1B1212),
//                                backgroundColor: Colors.white,
//                                   )
//                                 : Text(
//                                     buttonLogin[index],
//                                     style: const TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 16,
//                                     ),
//                                   )
//                             : Text(
//                                 buttonLogin[index],
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 16,
//                                 ),
//                               ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.only(right: 40),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         PageRouteBuilder(
//                           pageBuilder:
//                               (context, animation, secondaryAnimation) =>
//                                   const ForgetPassword(),
//                           transitionsBuilder:
//                               (context, animation, secondaryAnimation, child) {
//                             const begin = Offset(1.0, 0.0);
//                             const end = Offset.zero;
//                             const curve = Curves.easeInOut;

//                             final tween = Tween(begin: begin, end: end)
//                                 .chain(CurveTween(curve: curve));

//                             return SlideTransition(
//                               position: animation.drive(tween),
//                               child: child,
//                             );
//                           },
//                         ),
//                       );
//                     },
//                     child: const Text(
//                       'Forget Password',
//                       style: TextStyle(color: Colors.black),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 20),
//             const Text(
//               'Login with Google',
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 16,
//                 color: Colors.grey,
//               ),
//             ),
//             const SizedBox(height: 20),
//             Padding(
//               padding: const EdgeInsets.symmetric(
//                 horizontal: 30,
//                 vertical: 10,
//               ),
//               child: SizedBox(
//                 height: 55,
//                 child: ElevatedButton.icon(
//                   style: ElevatedButton.styleFrom(
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     backgroundColor: Color(0xff1B1212),
//                   ),
//                   onPressed: () {
//                     _signInWithGoogle();
//                   },
//                   label: const Text(
//                     'Google',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 20,
//                     ),
//                   ),
//                   icon: const Icon(
//                     FontAwesomeIcons.google,
//                     color: Colors.white,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _signInWithRole() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => isLoading = true);

//     try {
//       final user = await _authServices.signInWithEmailAndPassword(
//         _emailController.text.trim(),
//         _passwordController.text.trim(),
//       );

//       if (user != null && mounted) {
//         final userDoc = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .get();

//         if (userDoc.exists) {
//           final role = userDoc.data()?['role'];
//           final isVerified = userDoc.data()?['isVerified'] ?? false;

//           if (role == 'student' || role == 'teacher' || role == 'admin') {
//             final prefs = await SharedPreferences.getInstance();
//             await prefs.setString('role', role);

//             if (role == 'teacher' && !isVerified) {
//                  Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (_) =>  VerfiedScreen(),),
//               );
//               // First time login for teacher - go to verification screen
//               // Navigator.pushReplacement(
//               //   context,
//               //   MaterialPageRoute(builder: (_) => VerfiedScreen()),
//               // );
//             } else {
//               // Normal login flow for all roles or verified teachers
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (_) => const Navbar(),),
//               );
//             }
//           } else {
//             _showSnackBar('Invalid or missing role');
//           }
//         } else {
//           _showSnackBar('User document not found');
//         }
//       }
//     } on FirebaseAuthException catch (e) {
//       String message = 'Login failed. Email or password is incorrect.';
//       if (e.code == 'user-not-found') {
//         message = 'No user found with this email.';
//       } else if (e.code == 'wrong-password') {
//         message = 'Incorrect password.';
//       }
//       _showSnackBar(message);
//     } catch (e) {
//       _showSnackBar('Error: ${e.toString()}');
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   Future<void> _signInWithGoogle() async {
//     try {
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

//       if (googleUser == null) {
//         // The user canceled the sign-in
//         return;
//       }

//       final GoogleSignInAuthentication googleAuth =
//           await googleUser.authentication;

//       final AuthCredential credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );

//       final UserCredential userCredential =
//           await FirebaseAuth.instance.signInWithCredential(credential);
//       final user = userCredential.user;

//       if (user != null) {
//         final userDoc = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .get();

//         if (userDoc.exists) {
//           final role = userDoc.data()?['role'];
//           final isVerified = userDoc.data()?['isVerified'] ?? false;

//           if (role == 'student' || role == 'teacher' || role == 'admin') {
//             final prefs = await SharedPreferences.getInstance();
//             await prefs.setString('role', role);

//             if (role == 'teacher' && !isVerified) {
//               // First time login for teacher - go to verification screen
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (_) =>  VerfiedScreen()),
//               );
//             } else {
//               // Normal login flow
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (_) => const Navbar()),
//               );
//             }
//           } else {
//             _showSnackBar('Invalid or missing role');
//           }
//         } else {
//           _showSnackBar('User document not found');
//         }
//       }
//     } on FirebaseAuthException catch (e) {
//       _showSnackBar('Google sign-in failed: ${e.message}');
//     } catch (e) {
//       _showSnackBar('Error: ${e.toString()}');
//     }
//   }

//   void _showSnackBar(String message) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         backgroundColor: Colors.red,
//         margin: const EdgeInsets.all(10),
//         behavior: SnackBarBehavior.floating,
//         content: Text(message),
//       ),
//     );
//   }
// }