
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';

// class Chat extends StatefulWidget {
//   const Chat({Key? key}) : super(key: key);

//   @override
//   State<Chat> createState() => _ChatState();
// }

// class _ChatState extends State<Chat> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final TextEditingController _messageController = TextEditingController();
//   final User? _currentUser = FirebaseAuth.instance.currentUser;

//   String selectedChat = 'student';

//   // Theme colors
//   final Color studentColor = Colors.blueAccent;
//   final Color teacherColor = Colors.green;
//   final Color sentMessageColor = Colors.blue[100]!;
//   final Color receivedMessageColor = Colors.grey[200]!;

//   Widget _buildChatList(String userType) {
//     if (_currentUser == null) {
//       return const Center(child: Text('Please log in to view chats.'));
//     }
//     final uid = _currentUser!.uid;

//     return StreamBuilder<QuerySnapshot>(
//       stream: _firestore
//           .collection('${userType}Chats')
//           .doc(uid)
//           .collection('messages')
//           .orderBy('timestamp', descending: true)
//           .limit(1)
//           .snapshots(),
//       builder: (ctx, snap) {
//         if (snap.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
//         if (snap.hasError) {
//           return Center(child: Text('Error: ${snap.error}'));
//         }
//         final docs = snap.data?.docs ?? [];
//         String preview = docs.isNotEmpty
//             ? (docs.first.data() as Map<String, dynamic>)['content'] ?? ''
//             : 'No messages yet';
//         Timestamp? ts = docs.isNotEmpty
//             ? (docs.first.data() as Map<String, dynamic>)['timestamp']
//             : null;
//         String timeLabel = ts != null
//             ? DateFormat('HH:mm').format(ts.toDate())
//             : '';

//         return ListView(
//           padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//           children: [
//             Card(
//               elevation: 2,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12)),
//               color: selectedChat == userType
//                   ? Colors.grey[100]
//                   : Colors.white,
//               child: ListTile(
//                 dense: true,
//                 leading: CircleAvatar(
//                   backgroundColor:
//                       userType == 'student' ? studentColor : teacherColor,
//                   child: Text(
//                     userType[0].toUpperCase(),
//                     style: const TextStyle(color: Colors.white),
//                   ),
//                 ),
//                 title: Text(
//                   '${userType[0].toUpperCase()}${userType.substring(1)} Chat',
//                   style: const TextStyle(
//                       fontWeight: FontWeight.w600, fontSize: 14),
//                 ),
//                 subtitle: Text(
//                   '$preview\n$timeLabel',
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
//           ],
//         );
//       },
//     );
//   }

//   void _sendMessage() async {
//     final text = _messageController.text.trim();
//     if (text.isEmpty || _currentUser == null) return;

//     final uid = _currentUser!.uid;
//     final path = '${selectedChat}Chats';
//     final ref = _firestore
//         .collection(path)
//         .doc(uid)
//         .collection('messages');

//     try {
//       await ref.add({
//         'userId': uid,
//         'content': text,
//         'timestamp': FieldValue.serverTimestamp(),
//       });
//       _messageController.clear();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Send failed: $e')),
//       );
//     }
//   }

//   Widget _buildChatSection() {
//     if (_currentUser == null) {
//       return const Center(child: Text('Please log in.'));
//     }
//     final uid = _currentUser!.uid;
//     final path = '${selectedChat}Chats';

//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//           color: Colors.grey[100],
//           child: Row(
//             children: [
//               CircleAvatar(
//                 backgroundColor:
//                     selectedChat == 'student' ? studentColor : teacherColor,
//                 child: Text(
//                   selectedChat[0].toUpperCase(),
//                   style: const TextStyle(color: Colors.white),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Text(
//                 'Chat with ${selectedChat[0].toUpperCase()}${selectedChat.substring(1)}',
//                 style: const TextStyle(
//                     fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//         ),
//         const Divider(height: 1),
//         Expanded(
//           child: StreamBuilder<QuerySnapshot>(
//             stream: _firestore
//                 .collection(path)
//                 .doc(uid)
//                 .collection('messages')
//                 .orderBy('timestamp')
//                 .snapshots(),
//             builder: (ctx, snap) {
//               if (snap.connectionState == ConnectionState.waiting) {
//                 return const Center(child: CircularProgressIndicator());
//               }
//               if (snap.hasError) {
//                 return Center(child: Text('Error: ${snap.error}'));
//               }
//               final docs = snap.data?.docs ?? [];
//               if (docs.isEmpty) {
//                 return const Center(child: Text('No messages yet.'));
//               }
//               return ListView.builder(
//                 padding: const EdgeInsets.all(12),
//                 itemCount: docs.length,
//                 itemBuilder: (ctx, i) {
//                   final data = docs[i].data() as Map<String, dynamic>;
//                   final isMe = data['userId'] == uid;
//                   final content = data['content'] ?? '';
//                   final ts = data['timestamp'] as Timestamp?;
//                   final time = ts != null
//                       ? DateFormat('HH:mm').format(ts.toDate())
//                       : '';
//                   return Align(
//                     alignment:
//                         isMe ? Alignment.centerRight : Alignment.centerLeft,
//                     child: Container(
//                       margin: const EdgeInsets.symmetric(vertical: 4),
//                       padding: const EdgeInsets.all(12),
//                       constraints: BoxConstraints(
//                           maxWidth:
//                               MediaQuery.of(context).size.width * 0.6),
//                       decoration: BoxDecoration(
//                         color: isMe
//                             ? sentMessageColor
//                             : receivedMessageColor,
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: isMe
//                             ? CrossAxisAlignment.end
//                             : CrossAxisAlignment.start,
//                         children: [
//                           Text(content),
//                           if (time.isNotEmpty)
//                             Padding(
//                               padding: const EdgeInsets.only(top: 4),
//                               child: Text(
//                                 time,
//                                 style: const TextStyle(fontSize: 10),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               );
//             },
//           ),
//         ),
//         Container(
//           padding: const EdgeInsets.all(12),
//           color: Colors.white,
//           child: Row(
//             children: [
//               Expanded(
//                 child: TextField(
//                   controller: _messageController,
//                   decoration: InputDecoration(
//                     hintText: 'Type a message...',
//                     filled: true,
//                     fillColor: Colors.grey[100],
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(24),
//                       borderSide: BorderSide.none,
//                     ),
//                     contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 16, vertical: 12),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               FloatingActionButton(
//                 onPressed: _sendMessage,
//                 backgroundColor: selectedChat == 'student'
//                     ? studentColor
//                     : teacherColor,
//                 mini: true,
//                 child: const Icon(Icons.send, color: Colors.white, size: 20),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_currentUser == null) {
//       return Scaffold(
//         body: Center(child: Text('Please log in to access chat.')),
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Chat extends StatefulWidget {
  const Chat({Key? key}) : super(key: key);

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final _firestore = FirebaseFirestore.instance;
  final _messageController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // which tab is selected
  String selectedChat = 'student';
  // which user within that tab is selected
  String? _selectedPartnerId;

  // Theme colors
  final studentColor = Colors.blueAccent;
  final teacherColor = Colors.green;
  final sentMessageColor = Colors.blue[100]!;
  final receivedMessageColor = Colors.grey[200]!;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// Left pane: list all user-IDs under studentChats or teacherChats
  Widget _buildChatList(String userType) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('${userType}Chats').snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text('No $userType users.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final partnerId = docs[i].id;
            final isSelected =
                (selectedChat == userType && _selectedPartnerId == partnerId);

            // show the last message as a preview
            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('${userType}Chats')
                  .doc(partnerId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (pCtx, pSnap) {
                String preview = 'No messages';
                String timeLabel = '';
                if (pSnap.hasData && pSnap.data!.docs.isNotEmpty) {
                  final m = pSnap.data!.docs.first.data()!
                      as Map<String, dynamic>;
                  preview = m['content'] ?? preview;
                  final ts = m['timestamp'] as Timestamp?;
                  if (ts != null) {
                    timeLabel = DateFormat('HH:mm').format(ts.toDate());
                  }
                }

                return Card(
                  shadowColor: Colors.white,
                  color: isSelected ? Colors.grey[200] : Colors.white,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          userType == 'student' ? studentColor : teacherColor,
                      child: Text(
                        partnerId[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(partnerId,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(preview,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(timeLabel),
                    onTap: () {
                      setState(() {
                        selectedChat = userType;
                        _selectedPartnerId = partnerId;
                      });
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Send a message into the selected user’s subcollection
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _selectedPartnerId == null) return;

    final ref = _firestore
        .collection('${selectedChat}Chats')
        .doc(_selectedPartnerId)
        .collection('messages');

    await ref.add({
      'userId': _currentUser!.uid,
      'content': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  /// Right pane: conversation with the tapped user
  Widget _buildChatSection() {
    if (_selectedPartnerId == null) {
      return const Center(child: Text('Select a chat on the left.'));
    }

    return Column(
      children: [
        // header
        Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    selectedChat == 'student' ? studentColor : teacherColor,
                child: Text(
                  _selectedPartnerId![0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Chat with $_selectedPartnerId',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // message list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('${selectedChat}Chats')
                .doc(_selectedPartnerId)
                .collection('messages')
                .orderBy('timestamp')
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Center(child: Text('No messages yet.'));
              }
              final msgs = snap.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: msgs.length,
                itemBuilder: (ctx, i) {
                  final m = msgs[i].data()! as Map<String, dynamic>;
                  final isMe = m['userId'] == _currentUser!.uid;
                  final content = m['content'] ?? '';
                  final ts = m['timestamp'] as Timestamp?;
                  final time = ts == null
                      ? ''
                      : DateFormat('HH:mm').format(ts.toDate());

                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.6),
                      decoration: BoxDecoration(
                        color: isMe ? sentMessageColor : receivedMessageColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(content),
                          if (time.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(time,
                                  style: const TextStyle(fontSize: 10)),
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
        // input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration.collapsed(
                      hintText: 'Type a message'),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send,
                    color: selectedChat == 'student'
                        ? studentColor
                        : teacherColor),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        
          body: Center(child: Text('Please log in to access chat.')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Row(
          children: [
            // left pane
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.blueAccent,
                      onTap: (idx) {
                        setState(() {
                          selectedChat = idx == 0 ? 'student' : 'teacher';
                          _selectedPartnerId = null;
                        });
                      },
                      tabs: const [
                        Tab(text: "Student"),
                        Tab(text: "Teacher"),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildChatList('student'),
                          _buildChatList('teacher'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // right pane
            const VerticalDivider(width: 1),
            Expanded(flex: 6, child: _buildChatSection(),),
          ],
        ),
      ),
    );
  }
}
