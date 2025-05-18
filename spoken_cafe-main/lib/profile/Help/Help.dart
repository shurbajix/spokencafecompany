


// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// class Help extends ConsumerStatefulWidget {
//   const Help({super.key});

//   @override
//   ConsumerState<Help> createState() => _HelpState();
// }

// class _HelpState extends ConsumerState<Help> {
//   final TextEditingController _controller = TextEditingController();
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final User? _currentUser = FirebaseAuth.instance.currentUser;
//   String? userType;
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _fetchUserType();
//   }

//   Future<void> _fetchUserType() async {
//     try {
//       if (_currentUser == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Please log in to access support')),
//         );
//         Navigator.pop(context);
//         return;
//       }

//       final userRole = ref.read(userRoleProvider);

//       if (userRole == null) {
//         final userDoc = await _firestore
//             .collection('users')
//             .doc(_currentUser!.uid)
//             .get();

//         if (userDoc.exists) {
//           setState(() {
//             userType = userDoc.data()?['role']?.toString() ?? 'student';
//             _isLoading = false;
//           });
//         } else {
//           setState(() {
//             userType = 'student';
//             _isLoading = false;
//           });
//         }
//       } else {
//         setState(() {
//           userType = userRole;
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       print('Error fetching user type: $e');
//       setState(() => _isLoading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error fetching user data: $e')),
//       );
//     }
//   }

//   Future<void> sendHelpMessage(String message) async {
//     if (userType == null || _currentUser == null) return;

//     try {
//       String collectionPath =
//           userType == 'teacher' ? 'teacherChats' : 'studentChats';

//       // Use a fixed chatId (e.g., user UID or a general chat ID)
//       String chatId = _currentUser.uid; // Adjust based on your app's chat structure

//       await _firestore
//           .collection(collectionPath)
//           .doc(chatId)
//           .collection('messages')
//           .add({
//         'userId': _currentUser.uid,
//         'content': message, // Changed from 'message' to 'content' to match rules
//         'timestamp': FieldValue.serverTimestamp(),
//         'userType': userType,
//         'studentId': userType == 'student' ? _currentUser.uid : null,
//         'teacherId': userType == 'teacher' ? _currentUser.uid : null,
//       });

//       _controller.clear();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Message sent successfully')),
//       );
//     } catch (e) {
//       print('Error sending message: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error sending message: $e')),
//       );
//     }
//   }

//   String getSafeField(DocumentSnapshot doc, String fieldName) {
//     final data = doc.data() as Map<String, dynamic>? ?? {};
//     return data[fieldName]?.toString() ?? 'Unknown';
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading || userType == null) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text("Support"),
//           centerTitle: true,
//         ),
//         body: Center(
//           child: CircularProgressIndicator(
//             color: Color(0xff1B1212),
//             backgroundColor: Colors.white,
//           ),
//         ),
//       );
//     }

//     String collectionPath =
//         userType == 'teacher' ? 'teacherChats' : 'studentChats';

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           "Support",
//           style: TextStyle(
//             color: Color(0xff1B1212),
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         centerTitle: true,
//         backgroundColor: Colors.transparent,
//         leading: IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: Icon(Icons.arrow_back_ios_new, color: Color(0xff1B1212)),
//         ),
//       ),
//       backgroundColor: Colors.white,
//       body: Column(
//         children: [
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream: _firestore
//                   .collection(collectionPath)
//                   .doc(_currentUser!.uid) // Use same chatId as in sendHelpMessage
//                   .collection('messages')
//                   .where('userId', isEqualTo: _currentUser!.uid)
//                   .orderBy('timestamp', descending: true)
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return Center(
//                     child: CircularProgressIndicator(
//                       color: Color(0xff1B1212),
//                       backgroundColor: Colors.white,
//                     ),
//                   );
//                 }

//                 if (snapshot.hasError) {
//                   print('Stream error: ${snapshot.error}');
//                   return Center(
//                     child: Text('Error fetching messages: ${snapshot.error}'),
//                   );
//                 }

//                 if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                   return Center(child: Text('No messages yet.'));
//                 }

//                 final messages = snapshot.data!.docs;

//                 return ListView.builder(
//                   reverse: true,
//                   itemCount: messages.length,
//                   itemBuilder: (context, index) {
//                     final msg = messages[index];
//                     return ListTile(
//                       title: Text(
//                         getSafeField(msg, 'content'), // Changed to 'content'
//                         style: TextStyle(color: Color(0xff1B1212)),
//                       ),
//                       subtitle: Text(
//                         getSafeField(msg, 'userType'),
//                         style: TextStyle(color: Colors.grey[600]),
//                       ),
//                       trailing: Text(
//                         msg['timestamp'] != null
//                             ? (msg['timestamp'] as Timestamp)
//                                 .toDate()
//                                 .toString()
//                                 .substring(0, 16)
//                             : 'Pending',
//                         style: TextStyle(color: Colors.grey[600]),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
//             child: TextFormField(
//               controller: _controller,
//               decoration: InputDecoration(
//                 hintText: 'Enter your problem here...',
//                 suffixIcon: IconButton(
//                   icon: Icon(Icons.send, color: Color(0xff1B1212)),
//                   onPressed: () {
//                     final message = _controller.text.trim();
//                     if (message.isNotEmpty) {
//                       sendHelpMessage(message);
//                     }
//                   },
//                 ),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide: BorderSide(color: Color(0xff1B1212)),
//                 ),
//               ),
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }

// // Placeholder for Riverpod provider — define this properly in your app's providers
// final userRoleProvider = Provider<String?>((ref) => null);
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// Your Riverpod provider setup, if any:
final userRoleProvider = Provider<String?>((ref) => null);

class Help extends ConsumerStatefulWidget {
  const Help({Key? key}) : super(key: key);

  @override
  ConsumerState<Help> createState() => _HelpState();
}

class _HelpState extends ConsumerState<Help> {
  final _controller = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _currentUser = FirebaseAuth.instance.currentUser;

  String? userType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserType();
  }

  Future<void> _fetchUserType() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to access support')),
      );
      Navigator.pop(context);
      return;
    }
    final stored = ref.read(userRoleProvider);
    if (stored != null) {
      userType = stored;
    } else {
      final doc =
          await _firestore.collection('users').doc(_currentUser!.uid).get();
      userType = (doc.data()?['role'] as String?) ?? 'student';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _sendHelpMessage(String message) async {
    final path = userType == 'teacher' ? 'teacherChats' : 'studentChats';
    await _firestore
        .collection(path)
        .doc(_currentUser!.uid)
        .collection('messages')
        .add({
      'userId': _currentUser!.uid,
      'userType': userType,
      'content': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || userType == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Support'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final path = userType == 'teacher' ? 'teacherChats' : 'studentChats';
    final chatStream = _firestore
        .collection(path)
        .doc(_currentUser!.uid)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Support'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: BackButton(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatStream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }
                final docs = snap.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final m = docs[i].data() as Map<String, dynamic>;
                    final isMe = m['userId'] == _currentUser!.uid;
                    final text = m['content'] as String? ?? '';
                    final ts = m['timestamp'] as Timestamp?;
                    final time = ts == null
                        ? ''
                        : DateFormat('HH:mm').format(ts.toDate());

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin:
                            const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.7),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.blue[100]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(text),
                            if (time.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 4),
                                child:
                                    Text(time, style: const TextStyle(fontSize: 10)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Describe your problem…',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    final msg = _controller.text.trim();
                    if (msg.isNotEmpty) _sendHelpMessage(msg);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
