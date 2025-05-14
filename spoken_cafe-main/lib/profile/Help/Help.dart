

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:spokencafe/model/NavBar/NavBar.dart';

// class Help extends ConsumerStatefulWidget {
//   const Help({super.key});

//   @override
//   ConsumerState<Help> createState() => _HelpState();
// }

// class _HelpState extends ConsumerState<Help> {
//   final TextEditingController _controller = TextEditingController();
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final currentUser = FirebaseAuth.instance.currentUser!;
//   String? userType;

//   @override
//   void initState() {
//     super.initState();
//     fetchUserType();
//   }

//   Future<void> fetchUserType() async {
//     final userRole = ref.read(userRoleProvider);
//     setState(() {
//       userType = userRole;
//     });
//   }

//   Future<void> sendHelpMessage(String message) async {
//     if (userType == null) return;

//     try {
//       String collectionPath =
//           userType == 'teacher' ? 'teacherChats' : 'studentChats';

//       var chatRef = _firestore
//           .collection('chats')
//           .doc(collectionPath)
//           .collection('messages');

//       await chatRef.add({
//         'userId': currentUser.uid,
//         'message': message,
//         'timestamp': FieldValue.serverTimestamp(),
//         'userType': userType,
//         'studentId': userType == 'student' ? currentUser.uid : null,
//         'teacherId': userType == 'teacher' ? currentUser.uid : null,
//       });

//       _controller.clear();
//     } catch (e) {
//       print("Error sending message: $e");
//     }
//   }

//   String getSafeField(DocumentSnapshot doc, String fieldName) {
//     final data = doc.data() as Map<String, dynamic>? ?? {};
//     return data[fieldName]?.toString() ?? 'Unknown';
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (userType == null) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text("Support"),
//           centerTitle: true,
//         ),
//         body: Center(child: CircularProgressIndicator(
//            color:  Color(0xff1B1212),
//             backgroundColor: Colors.white,
//         ),),
//       );
//     }

//     String collectionPath =
//         userType == 'teacher' ? 'teacherChats' : 'studentChats';

//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Support",style: TextStyle(
//           color: Color(0xff1B1212),
//           fontWeight: FontWeight.bold,
//         ),),
//         centerTitle: true,
//         backgroundColor: Colors.transparent,
//         leading: IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: Icon(Icons.arrow_back_ios_new,color: Color(0xff1B1212),),
//         ),
//       ),
//       backgroundColor: Colors.white,
//       body: Column(
//         children: [
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream: _firestore
//                   .collection('chats')
//                   .doc(collectionPath)
//                   .collection('messages')
//                   .where('userId',
//                       isEqualTo:
//                           currentUser.uid) // Only current user's messages
//                   .orderBy('timestamp')
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting)
//                   return Center(child: CircularProgressIndicator(
//                      color:  Color(0xff1B1212),
//                        backgroundColor: Colors.white,
//                   ));

//                 if (snapshot.hasError)
//                   return Center(child: Text('Error fetching messages'));

//                 if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
//                   return Center(child: Text('No messages yet.'));

//                 final messages = snapshot.data!.docs;

//                 return ListView.builder(
//                   itemCount: messages.length,
//                   itemBuilder: (context, index) {
//                     final msg = messages[index];
//                     return ListTile(
//                       title: Text(getSafeField(msg, 'message')),
//                       subtitle: Text(getSafeField(msg, 'userType')),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.symmetric(
//               horizontal: 20,
//               vertical: 30,
//             ),
//             child: TextFormField(
//               controller: _controller,
//               decoration: InputDecoration(
                
//                 hintText: 'Enter your problem here...',
//                 suffixIcon: IconButton(
//                   icon: Icon(Icons.send,color: Color(0xff1B1212),),
//                   onPressed: () {
//                     if (_controller.text.trim().isNotEmpty) {
//                       sendHelpMessage(_controller.text.trim());
//                     }
//                   },
//                 ),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//               ),
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Help extends ConsumerStatefulWidget {
  const Help({super.key});

  @override
  ConsumerState<Help> createState() => _HelpState();
}

class _HelpState extends ConsumerState<Help> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String? userType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserType();
  }

  Future<void> _fetchUserType() async {
    try {
      if (_currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please log in to access support')),
        );
        Navigator.pop(context);
        return;
      }

      final userRole = ref.read(userRoleProvider);

      if (userRole == null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            userType = userDoc.data()?['role']?.toString() ?? 'student';
            _isLoading = false;
          });
        } else {
          setState(() {
            userType = 'student';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          userType = userRole;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user type: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching user data: $e')),
      );
    }
  }

  Future<void> sendHelpMessage(String message) async {
    if (userType == null || _currentUser == null) return;

    try {
      String collectionPath =
          userType == 'teacher' ? 'teacherChats' : 'studentChats';

      // Use a fixed chatId (e.g., user UID or a general chat ID)
      String chatId = _currentUser.uid; // Adjust based on your app's chat structure

      await _firestore
          .collection(collectionPath)
          .doc(chatId)
          .collection('messages')
          .add({
        'userId': _currentUser.uid,
        'content': message, // Changed from 'message' to 'content' to match rules
        'timestamp': FieldValue.serverTimestamp(),
        'userType': userType,
        'studentId': userType == 'student' ? _currentUser.uid : null,
        'teacherId': userType == 'teacher' ? _currentUser.uid : null,
      });

      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message sent successfully')),
      );
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  String getSafeField(DocumentSnapshot doc, String fieldName) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return data[fieldName]?.toString() ?? 'Unknown';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || userType == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Support"),
          centerTitle: true,
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xff1B1212),
            backgroundColor: Colors.white,
          ),
        ),
      );
    }

    String collectionPath =
        userType == 'teacher' ? 'teacherChats' : 'studentChats';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Support",
          style: TextStyle(
            color: Color(0xff1B1212),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: Color(0xff1B1212)),
        ),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection(collectionPath)
                  .doc(_currentUser!.uid) // Use same chatId as in sendHelpMessage
                  .collection('messages')
                  .where('userId', isEqualTo: _currentUser!.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Color(0xff1B1212),
                      backgroundColor: Colors.white,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  print('Stream error: ${snapshot.error}');
                  return Center(
                    child: Text('Error fetching messages: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No messages yet.'));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return ListTile(
                      title: Text(
                        getSafeField(msg, 'content'), // Changed to 'content'
                        style: TextStyle(color: Color(0xff1B1212)),
                      ),
                      subtitle: Text(
                        getSafeField(msg, 'userType'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Text(
                        msg['timestamp'] != null
                            ? (msg['timestamp'] as Timestamp)
                                .toDate()
                                .toString()
                                .substring(0, 16)
                            : 'Pending',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: TextFormField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Enter your problem here...',
                suffixIcon: IconButton(
                  icon: Icon(Icons.send, color: Color(0xff1B1212)),
                  onPressed: () {
                    final message = _controller.text.trim();
                    if (message.isNotEmpty) {
                      sendHelpMessage(message);
                    }
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Color(0xff1B1212)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// Placeholder for Riverpod provider — define this properly in your app's providers
final userRoleProvider = Provider<String?>((ref) => null);