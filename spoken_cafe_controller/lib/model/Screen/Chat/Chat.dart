

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';

// class Chat extends StatefulWidget {
//   const Chat({super.key});

//   @override
//   State<Chat> createState() => _ChatState();
// }

// class _ChatState extends State<Chat> {
//   String selectedChat = "Student Chat 0";
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final TextEditingController _messageController = TextEditingController();
//   final User? currentUser = FirebaseAuth.instance.currentUser;

//   // Theme colors
//   final Color studentColor = Colors.blueAccent;
//   final Color teacherColor = Colors.green;
//   final Color sentMessageColor = Colors.blue[100]!;
//   final Color receivedMessageColor = Colors.grey[200]!;

//   // Function to build the chat list for both students and teachers
//   Widget _buildChatList(String userType) {
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//       child: StreamBuilder<QuerySnapshot>(
//         stream: _firestore
//             .collection('chats')
//             .doc('${userType}Chats')
//             .collection('messages')
//             .orderBy('timestamp', descending: true)
//             .limit(1)
//             .snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           if (snapshot.hasError) {
//             return const Center(child: Text('Something went wrong!'));
//           }
//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return Center(child: Text('No messages yet for $userType.'));
//           }

//           var messageData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
//           String message = messageData['message'] ?? '';
//           Timestamp timestamp = messageData['timestamp'] ?? Timestamp.fromDate(DateTime.now());
//           String formattedTimestamp = DateFormat('yyyy-MM-dd – hh:mm a').format(timestamp.toDate());

//           return Card(
//   elevation: 2,
//   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//   color: selectedChat.contains(userType) ? Colors.grey[100] : Colors.white,
//   child: ConstrainedBox(
//     constraints: const BoxConstraints(
//       maxHeight: 70, // Set a smaller max height for the card
//     ),
//     child: ListTile(
//       dense: true, // Reduces vertical padding
//       visualDensity: const VisualDensity(vertical: -2), // Further compacts the ListTile
//       minLeadingWidth: 30, // Reduces the width of the leading widget (CircleAvatar)
//       leading: CircleAvatar(
//         radius: 15, // Smaller avatar size
//         backgroundColor: userType == 'student' ? studentColor : teacherColor,
//         child: Text(
//           userType[0].toUpperCase(),
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 14, // Smaller font size for avatar text
//           ),
//         ),
//       ),
//       title: Text(
//         '$userType User',
//         style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), // Smaller font size
//       ),
//       subtitle: Text(
//         '$message\n$formattedTimestamp',
//         style: TextStyle(fontSize: 12, color: Colors.grey[600]), // Smaller subtitle font
//         maxLines: 2,
//         overflow: TextOverflow.ellipsis,
//       ),
//       onTap: () {
//         setState(() {
//           selectedChat = '$userType Chat 0';
//         });
//       },
//     ),
//   ),
// );
//         },
//       ),
//     );
//   }

//   // Function to send a message
//   void _sendMessage(String userType) {
//     String message = _messageController.text.trim();
//     if (message.isNotEmpty && currentUser != null) {
//       final uid = currentUser!.uid;
//       final email = currentUser!.email;

//       final Map<String, dynamic> data = {
//         'message': message,
//         'timestamp': FieldValue.serverTimestamp(),
//         'email': email,
//         'role': userType,
//       };

//       if (userType == 'student') {
//         data['studentId'] = uid;
//       } else {
//         data['teacherId'] = uid;
//       }

//       _firestore
//           .collection('chats')
//           .doc('${userType}Chats')
//           .collection('messages')
//           .add(data)
//           .then((value) {
//             _messageController.clear();
//           })
//           .catchError((error) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text('Failed to send message: $error')),
//             );
//           });
//     }
//   }

//   // Function to build the chat section where messages are displayed
//   Widget _buildChatSection() {
//     String chatType = selectedChat.contains("student") ? "student" : "teacher";

//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//           color: Colors.grey[100],
//           child: Row(
//             children: [
//               CircleAvatar(
//                 radius: 20,
//                 backgroundColor: chatType == 'student' ? studentColor : teacherColor,
//                 child: Text(
//                   chatType[0].toUpperCase(),
//                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Text(
//                 'Chat with ${chatType == "student" ? "Student" : "Teacher"}',
//                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//         ),
//         const Divider(height: 1),
//         Expanded(
//           child: StreamBuilder<QuerySnapshot>(
//             stream: _firestore
//                 .collection('chats')
//                 .doc('${chatType}Chats')
//                 .collection('messages')
//                 .orderBy('timestamp')
//                 .snapshots(),
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(child: CircularProgressIndicator());
//               }
//               if (snapshot.hasError) {
//                 return const Center(child: Text('Something went wrong!'));
//               }
//               if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                 return const Center(child: Text('No messages yet.'));
//               }

//               var messages = snapshot.data!.docs;
//               return ListView.builder(
//                 itemCount: messages.length,
//                 itemBuilder: (context, index) {
//                   var messageData = messages[index].data() as Map<String, dynamic>;
//                   String message = messageData['message'] ?? '';
//                   String role = messageData['role'] ?? chatType;
//                   bool isSentByCurrentUser = messageData['email'] == currentUser?.email;
//                   Timestamp timestamp = messageData['timestamp'] ?? Timestamp.fromDate(DateTime.now());
//                   String formattedTimestamp = DateFormat('hh:mm a').format(timestamp.toDate());

//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
//                     child: Align(
//                       alignment: isSentByCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
//                       child: Container(
//                         constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
//                         padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                         decoration: BoxDecoration(
//                           color: isSentByCurrentUser ? sentMessageColor : receivedMessageColor,
//                           borderRadius: BorderRadius.circular(12),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.1),
//                               blurRadius: 4,
//                               offset: const Offset(0, 2),
//                             ),
//                           ],
//                         ),
//                         child: Column(
//                           crossAxisAlignment: isSentByCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               message,
//                               style: const TextStyle(fontSize: 16),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               formattedTimestamp,
//                               style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               );
//             },
//           ),
//         ),
//         Padding(
//           padding: const EdgeInsets.all(12.0),
//           child: Row(
//             children: [
//               Expanded(
//                 child: TextFormField(
//                   controller: _messageController,
//                   decoration: InputDecoration(
//                     hintText: "Type a message...",
//                     filled: true,
//                     fillColor: Colors.white,
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(20),
//                       borderSide: BorderSide.none,
//                     ),
//                     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               FloatingActionButton(
//                 onPressed: () {
//                   _sendMessage(chatType);
//                 },
//                 backgroundColor: chatType == 'student' ? studentColor : teacherColor,
//                 mini: true,
//                 child: const Icon(Icons.send, color: Colors.white),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         backgroundColor: Colors.grey[100],
//         body: Row(
//           children: [
//             Expanded(
//               flex: 3,
//               child: Container(
//                 color: Colors.white,
//                 child: Column(
//                   children: [
//                     const TabBar(
//                       labelColor: Colors.black,
//                       unselectedLabelColor: Colors.grey,
//                       indicatorColor: Colors.blueAccent,
//                       tabs: [
//                         Tab(text: "Student"),
//                         Tab(text: "Teacher"),
//                       ],
//                     ),
//                     Expanded(
//                       child: TabBarView(
//                         children: [
//                           _buildChatList("student"),
//                           _buildChatList("teacher"),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             Expanded(
//               flex: 6,
//               child: Container(
//                 margin: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.1),
//                       blurRadius: 8,
//                       offset: const Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 child: _buildChatSection(),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  String selectedChat = "student";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Theme colors
  final Color studentColor = Colors.blueAccent;
  final Color teacherColor = Colors.green;
  final Color sentMessageColor = Colors.blue[100]!;
  final Color receivedMessageColor = Colors.grey[200]!;

  @override
  void initState() {
    super.initState();
    _checkFirestoreData(); // Debug method to check data
  }

  // Debug method to print Firestore data
  void _checkFirestoreData() async {
    if (currentUser == null) return;
    
    print("Checking Firestore data for user: ${currentUser!.uid}");
    
    // Check student chats
    var studentSnapshot = await _firestore
        .collection('studentChats')
        .doc(currentUser!.uid)
        .collection('messages')
        .get();
    print("Student messages count: ${studentSnapshot.docs.length}");
    studentSnapshot.docs.forEach((doc) => print(doc.data()));

    // Check teacher chats
    var teacherSnapshot = await _firestore
        .collection('teacherChats')
        .doc(currentUser!.uid)
        .collection('messages')
        .get();
    print("Teacher messages count: ${teacherSnapshot.docs.length}");
    teacherSnapshot.docs.forEach((doc) => print(doc.data()));
  }

  Widget _buildChatList(String userType) {
    if (currentUser == null) {
      return const Center(child: Text('Please log in to view chats.'));
    }

    String chatId = currentUser!.uid;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('${userType}Chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("Error in ${userType}Chats stream: ${snapshot.error}");
            return const Center(child: Text('Error loading messages'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No messages yet for $userType Support.'));
          }

          var messageData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          String content = messageData['content'] ?? '';
          Timestamp? timestamp = messageData['timestamp'] as Timestamp?;
          String formattedTimestamp = timestamp != null 
              ? DateFormat('yyyy-MM-dd – hh:mm a').format(timestamp.toDate())
              : 'No timestamp';

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: selectedChat == userType ? Colors.grey[100] : Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 70),
              child: ListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -2),
                minLeadingWidth: 30,
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: userType == 'student' ? studentColor : teacherColor,
                  child: Text(
                    userType[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                title: Text(
                  '$userType Support',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  '$content\n$formattedTimestamp',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  setState(() {
                    selectedChat = userType;
                  });
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _sendMessage(String userType) async {
    String message = _messageController.text.trim();
    if (message.isNotEmpty && currentUser != null) {
      final uid = currentUser!.uid;
      final chatId = uid;

      try {
        await _firestore
            .collection('${userType}Chats')
            .doc(chatId)
            .collection('messages')
            .add({
              'userId': uid,
              'content': message,
              'timestamp': FieldValue.serverTimestamp(),
              'userType': userType,
            });
        _messageController.clear();
      } catch (error) {
        print("Error sending message: $error");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $error')),
        );
      }
    }
  }

  Widget _buildChatSection() {
    String chatType = selectedChat;
    String chatId = currentUser?.uid ?? 'default';

    print('Building chat section for $chatType with ID: $chatId');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: Colors.grey[100],
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: chatType == 'student' ? studentColor : teacherColor,
                child: Text(
                  chatType[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Chat with ${chatType == "student" ? "Student" : "Teacher"} Support',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('${chatType}Chats')
                .doc(chatId)
                .collection('messages')
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              print('Snapshot state: ${snapshot.connectionState}');
              
              if (snapshot.hasError) {
                print('Stream error: ${snapshot.error}');
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              switch (snapshot.connectionState) {
                case ConnectionState.waiting:
                  return const Center(child: CircularProgressIndicator());
                default:
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No messages yet. Start the conversation!'),
                    );
                  }

                  var messages = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      var messageData = messages[index].data() as Map<String, dynamic>;
                      String content = messageData['content'] ?? '';
                      bool isSentByCurrentUser = messageData['userId'] == currentUser?.uid;
                      Timestamp? timestamp = messageData['timestamp'] as Timestamp?;
                      String formattedTimestamp = timestamp != null
                          ? DateFormat('hh:mm a').format(timestamp.toDate())
                          : '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                        child: Align(
                          alignment: isSentByCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isSentByCurrentUser ? sentMessageColor : receivedMessageColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: isSentByCurrentUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(content, style: const TextStyle(fontSize: 16)),
                                if (formattedTimestamp.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      formattedTimestamp,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600]),
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
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: "Type a message...",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed: () => _sendMessage(chatType),
                backgroundColor: chatType == 'student' ? studentColor : teacherColor,
                mini: true,
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        body: Center(child: Text('Please log in to access support chat.')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.blueAccent,
                      tabs: [
                        Tab(text: "Student"),
                        Tab(text: "Teacher"),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildChatList("student"),
                          _buildChatList("teacher"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildChatSection(),
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
// import 'package:intl/intl.dart';

// class Chat extends StatefulWidget {
//   const Chat({super.key});

//   @override
//   State<Chat> createState() => _ChatState();
// }

// class _ChatState extends State<Chat> {
//   String selectedChat = "student"; // Default to student chat
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final TextEditingController _messageController = TextEditingController();
//   final User? currentUser = FirebaseAuth.instance.currentUser;

//   // Theme colors
//   final Color studentColor = Colors.blueAccent;
//   final Color teacherColor = Colors.green;
//   final Color sentMessageColor = Colors.blue[100]!;
//   final Color receivedMessageColor = Colors.grey[200]!;

//   // Function to get user type (student or teacher)
//   Future<String> _getUserType() async {
//     if (currentUser == null) return 'student';
//     try {
//       final userDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
//       return userDoc.exists ? userDoc.data() != null?['role']?.toString() ?? 'student' : 'student':'';
//     } catch (e) {
//       print('Error fetching user type: $e');
//       return 'student';
//     }
//   }

//   // Function to build the chat list for both students and teachers
//   Widget _buildChatList(String userType) {
//     if (currentUser == null) {
//       return const Center(child: Text('Please log in to view chats.'));
//     }

//     String chatId = currentUser!.uid; // Use user UID as chatId

//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//       child: StreamBuilder<QuerySnapshot>(
//         stream: _firestore
//             .collection('${userType}Chats')
//             .doc(chatId)
//             .collection('messages')
//             .orderBy('timestamp', descending: true)
//             .limit(1)
//             .snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           if (snapshot.hasError) {
//             return const Center(child: Text('Something went wrong!'));
//           }
//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return Center(child: Text('No messages yet for $userType Support.'));
//           }

//           var messageData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
//           String content = messageData['content'] ?? '';
//           Timestamp timestamp = messageData['timestamp'] ?? Timestamp.fromDate(DateTime.now());
//           String formattedTimestamp = DateFormat('yyyy-MM-dd – hh:mm a').format(timestamp.toDate());

//           return Card(
//             elevation: 2,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             color: selectedChat == userType ? Colors.grey[100] : Colors.white,
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(
//                 maxHeight: 70,
//               ),
//               child: ListTile(
//                 dense: true,
//                 visualDensity: const VisualDensity(vertical: -2),
//                 minLeadingWidth: 30,
//                 leading: CircleAvatar(
//                   radius: 15,
//                   backgroundColor: userType == 'student' ? studentColor : teacherColor,
//                   child: Text(
//                     userType[0].toUpperCase(),
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 14,
//                     ),
//                   ),
//                 ),
//                 title: Text(
//                   '$userType Support',
//                   style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
//                 ),
//                 subtitle: Text(
//                   '$content\n$formattedTimestamp',
//                   style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 onTap: () {
//                   setState(() {
//                     selectedChat = userType;
//                   });
//                 },
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   // Function to send a message
//   void _sendMessage(String userType) async {
//     String message = _messageController.text.trim();
//     if (message.isNotEmpty && currentUser != null) {
//       final uid = currentUser!.uid;
//       final email = currentUser!.email;
//       final chatId = uid; // Use user UID as chatId

//       final Map<String, dynamic> data = {
//         'userId': uid,
//         'content': message,
//         'timestamp': FieldValue.serverTimestamp(),
//         'userType': userType,
//       };

//       if (userType == 'student') {
//         data['studentId'] = uid;
//       } else {
//         data['teacherId'] = uid;
//       }

//       try {
//         await _firestore
//             .collection('${userType}Chats')
//             .doc(chatId)
//             .collection('messages')
//             .add(data);
//         _messageController.clear();
//       } catch (error) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to send message: $error')),
//         );
//       }
//     }
//   }

//   // Function to build the chat section where messages are displayed
//   Widget _buildChatSection() {
//     String chatType = selectedChat == "student" ? "student" : "teacher";
//     String chatId = currentUser?.uid ?? 'default';

//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//           color: Colors.grey[100],
//           child: Row(
//             children: [
//               CircleAvatar(
//                 radius: 20,
//                 backgroundColor: chatType == 'student' ? studentColor : teacherColor,
//                 child: Text(
//                   chatType[0].toUpperCase(),
//                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Text(
//                 'Chat with ${chatType == "student" ? "Student" : "Teacher"} Support',
//                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//         ),
//         const Divider(height: 1),
//         Expanded(
//           child: StreamBuilder<QuerySnapshot>(
//             stream: _firestore
//                 .collection('${chatType}Chats')
//                 .doc(chatId)
//                 .collection('messages')
//                 .orderBy('timestamp')
//                 .snapshots(),
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(child: CircularProgressIndicator());
//               }
//               if (snapshot.hasError) {
//                 return Center(child: Text('Error: ${snapshot.error}'));
//               }
//               if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                 return const Center(child: Text('No messages yet.'));
//               }

//               var messages = snapshot.data!.docs;
//               return ListView.builder(
//                 itemCount: messages.length,
//                 itemBuilder: (context, index) {
//                   var messageData = messages[index].data() as Map<String, dynamic>;
//                   String content = messageData['content'] ?? '';
//                   String role = messageData['userType'] ?? chatType;
//                   bool isSentByCurrentUser = messageData['userId'] == currentUser?.uid;
//                   Timestamp timestamp = messageData['timestamp'] ?? Timestamp.fromDate(DateTime.now());
//                   String formattedTimestamp = DateFormat('hh:mm a').format(timestamp.toDate());

//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
//                     child: Align(
//                       alignment: isSentByCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
//                       child: Container(
//                         constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
//                         padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                         decoration: BoxDecoration(
//                           color: isSentByCurrentUser ? sentMessageColor : receivedMessageColor,
//                           borderRadius: BorderRadius.circular(12),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.1),
//                               blurRadius: 4,
//                               offset: const Offset(0, 2),
//                             ),
//                           ],
//                         ),
//                         child: Column(
//                           crossAxisAlignment: isSentByCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               content,
//                               style: const TextStyle(fontSize: 16),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               formattedTimestamp,
//                               style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               );
//             },
//           ),
//         ),
//         Padding(
//           padding: const EdgeInsets.all(12.0),
//           child: Row(
//             children: [
//               Expanded(
//                 child: TextFormField(
//                   controller: _messageController,
//                   decoration: InputDecoration(
//                     hintText: "Type a message...",
//                     filled: true,
//                     fillColor: Colors.white,
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(20),
//                       borderSide: BorderSide.none,
//                     ),
//                     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               FloatingActionButton(
//                 onPressed: () {
//                   _sendMessage(chatType);
//                 },
//                 backgroundColor: chatType == 'student' ? studentColor : teacherColor,
//                 mini: true,
//                 child: const Icon(Icons.send, color: Colors.white),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (currentUser == null) {
//       return Scaffold(
//         body: Center(child: Text('Please log in to access support chat.')),
//       );
//     }

//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         backgroundColor: Colors.grey[100],
//         body: Row(
//           children: [
//             Expanded(
//               flex: 3,
//               child: Container(
//                 color: Colors.white,
//                 child: Column(
//                   children: [
//                     const TabBar(
//                       labelColor: Colors.black,
//                       unselectedLabelColor: Colors.grey,
//                       indicatorColor: Colors.blueAccent,
//                       tabs: [
//                         Tab(text: "Student"),
//                         Tab(text: "Teacher"),
//                       ],
//                     ),
//                     Expanded(
//                       child: TabBarView(
//                         children: [
//                           _buildChatList("student"),
//                           _buildChatList("teacher"),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             Expanded(
//               flex: 6,
//               child: Container(
//                 margin: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.1),
//                       blurRadius: 8,
//                       offset: const Offset(0, 4),
//                     ),
//                   ],
//                 ),
//                 child: _buildChatSection(),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }