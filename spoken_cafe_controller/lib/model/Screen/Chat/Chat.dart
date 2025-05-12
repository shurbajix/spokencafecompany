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
  String selectedChat = "Student Chat 0";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Function to build the chat list for both students and teachers
  Widget _buildChatList(String userType) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: StreamBuilder<QuerySnapshot>(
        stream:
            _firestore
                .collection('chats')
                .doc('${userType}Chats')
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .limit(1)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong!'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No messages yet for $userType.'));
          }

          var messageData =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          String message = messageData['message'] ?? '';
          Timestamp timestamp =
              messageData['timestamp'] ?? Timestamp.fromDate(DateTime.now());
          String formattedTimestamp = DateFormat(
            'yyyy-MM-dd – hh:mm a',
          ).format(timestamp.toDate());

          return ListTile(
            leading: const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.amber,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$userType User',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 5.0),
                  child: Text(
                    '$message\nSent at: $formattedTimestamp',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            onTap: () {
              setState(() {
                selectedChat = '$userType Chat 0';
              });
            },
          );
        },
      ),
    );
  }

  // Function to send a message
  void _sendMessage(String userType) {
    String message = _messageController.text.trim();
    if (message.isNotEmpty && currentUser != null) {
      final uid = currentUser!.uid;
      final email = currentUser!.email;

      final Map<String, dynamic> data = {
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'email': email,
        'role': userType,
      };

      // Add user UID according to role
      if (userType == 'student') {
        data['studentId'] = uid;
      } else {
        data['teacherId'] = uid;
      }

      // Debugging: Print out the data being added
      print('Sending message data: $data');

      _firestore
          .collection('chats')
          .doc('${userType}Chats')
          .collection('messages')
          .add(data)
          .then((value) {
            _messageController.clear();
          })
          .catchError((error) {
            print("Failed to send message: $error");
          });
    }
  }

  // Function to build the chat section where messages are displayed
  Widget _buildChatSection() {
    String chatType = selectedChat.contains("student") ? "student" : "teacher";

    return Column(
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 20, backgroundColor: Colors.amber),
            Text(
              ' Chat with ${chatType == "student" ? "Student" : "Teacher"}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Divider(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('chats')
                    .doc('${chatType}Chats')
                    .collection('messages')
                    .orderBy('timestamp')
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Something went wrong!'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No messages yet.'));
              }

              // Debugging: Print out the snapshot data
              print('Snapshot data: ${snapshot.data!.docs}');

              var messages = snapshot.data!.docs;
              return ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  var messageData =
                      messages[index].data() as Map<String, dynamic>;
                  String message = messageData['message'] ?? '';
                  Timestamp timestamp =
                      messageData['timestamp'] ??
                      Timestamp.fromDate(DateTime.now());
                  String formattedTimestamp = DateFormat(
                    'yyyy-MM-dd – hh:mm a',
                  ).format(timestamp.toDate());

                  return ListTile(
                    title: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(message),
                    ),
                    subtitle: Text(formattedTimestamp),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: "Type a message...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  _sendMessage(
                    selectedChat.contains("student") ? "student" : "teacher",
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [Tab(text: "Student"), Tab(text: "Teacher")],
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
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
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
