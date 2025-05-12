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
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     String collectionPath =
//         userType == 'teacher' ? 'teacherChats' : 'studentChats';

//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Support"),
//         centerTitle: true,
//         backgroundColor: Colors.transparent,
//         leading: IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: Icon(Icons.arrow_back_ios_new),
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
//                   .orderBy('timestamp')
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting)
//                   return Center(child: CircularProgressIndicator());

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
//                   icon: Icon(Icons.send),
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
import 'package:spokencafe/model/NavBar/NavBar.dart';

class Help extends ConsumerStatefulWidget {
  const Help({super.key});

  @override
  ConsumerState<Help> createState() => _HelpState();
}

class _HelpState extends ConsumerState<Help> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser!;
  String? userType;

  @override
  void initState() {
    super.initState();
    fetchUserType();
  }

  Future<void> fetchUserType() async {
    final userRole = ref.read(userRoleProvider);
    setState(() {
      userType = userRole;
    });
  }

  Future<void> sendHelpMessage(String message) async {
    if (userType == null) return;

    try {
      String collectionPath =
          userType == 'teacher' ? 'teacherChats' : 'studentChats';

      var chatRef = _firestore
          .collection('chats')
          .doc(collectionPath)
          .collection('messages');

      await chatRef.add({
        'userId': currentUser.uid,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'userType': userType,
        'studentId': userType == 'student' ? currentUser.uid : null,
        'teacherId': userType == 'teacher' ? currentUser.uid : null,
      });

      _controller.clear();
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  String getSafeField(DocumentSnapshot doc, String fieldName) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return data[fieldName]?.toString() ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (userType == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Support"),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator(
           color:  Color(0xff1B1212),
            backgroundColor: Colors.white,
        ),),
      );
    }

    String collectionPath =
        userType == 'teacher' ? 'teacherChats' : 'studentChats';

    return Scaffold(
      appBar: AppBar(
        title: Text("Support",style: TextStyle(
          color: Color(0xff1B1212),
          fontWeight: FontWeight.bold,
        ),),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new,color: Color(0xff1B1212),),
        ),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(collectionPath)
                  .collection('messages')
                  .where('userId',
                      isEqualTo:
                          currentUser.uid) // Only current user's messages
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return Center(child: CircularProgressIndicator(
                     color:  Color(0xff1B1212),
                       backgroundColor: Colors.white,
                  ));

                if (snapshot.hasError)
                  return Center(child: Text('Error fetching messages'));

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return Center(child: Text('No messages yet.'));

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return ListTile(
                      title: Text(getSafeField(msg, 'message')),
                      subtitle: Text(getSafeField(msg, 'userType')),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 30,
            ),
            child: TextFormField(
              controller: _controller,
              decoration: InputDecoration(
                
                hintText: 'Enter your problem here...',
                suffixIcon: IconButton(
                  icon: Icon(Icons.send,color: Color(0xff1B1212),),
                  onPressed: () {
                    if (_controller.text.trim().isNotEmpty) {
                      sendHelpMessage(_controller.text.trim());
                    }
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
