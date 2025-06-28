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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _chatSearchController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController(); // Add scroll controller for chat
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String selectedChat = 'student';
  String? _selectedUserId; // Selected user to chat with
  Map<String, String> _userNames = {}; // Cache for user names
  Map<String, bool> _unreadMessages = {}; // Track unread messages
  String _searchQuery = ''; // Search query for chat list
  String _chatSearchQuery = ''; // Search query for chat messages
  
  // Cache for user lists to reduce Firestore queries
  Map<String, List<QueryDocumentSnapshot>> _userListCache = {};
  Map<String, DateTime> _userListCacheTime = {};

  // Theme colors
  final Color studentColor = Colors.blueAccent;
  final Color teacherColor = Colors.green;
  final Color sentMessageColor = Colors.blue[100]!;
  final Color receivedMessageColor = Colors.grey[200]!;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _chatSearchController.addListener(() {
      setState(() {
        _chatSearchQuery = _chatSearchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _chatSearchController.dispose();
    _chatScrollController.dispose(); // Dispose chat scroll controller
    _messageController.dispose();
    super.dispose();
  }

  // Auto-scroll to bottom like WhatsApp
  void _scrollChatToBottom() {
    if (_chatScrollController.hasClients) {
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Auto-scroll to bottom after a short delay
  void _scrollChatToBottomDelayed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollChatToBottom();
      });
    });
  }

  // Fetch user name from Firebase
  Future<String> _getUserName(String userId) async {
    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final name = data['name']?.toString() ?? 'Unknown User';
        _userNames[userId] = name;
        return name;
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }
    
    _userNames[userId] = 'Unknown User';
    return 'Unknown User';
  }

  // Mark messages as read when chat is opened
  void _markAsRead(String userId) {
    setState(() {
      _unreadMessages[userId] = false;
    });
  }

  // Get cached user list or fetch from Firestore
  Stream<List<QueryDocumentSnapshot>> _getCachedUserList(String userType) {
    // Check if we have a recent cache (less than 30 seconds old)
    final cacheTime = _userListCacheTime[userType];
    final now = DateTime.now();
    
    if (cacheTime != null && 
        now.difference(cacheTime).inSeconds < 30 && 
        _userListCache[userType] != null) {
      // Return cached data as a stream
      return Stream.value(_userListCache[userType]!);
    }
    
    // Fetch fresh data and cache it
    return _firestore
        .collection('users')
        .where('role', isEqualTo: userType)
        .snapshots()
        .map((snapshot) {
      _userListCache[userType] = snapshot.docs;
      _userListCacheTime[userType] = now;
      return snapshot.docs;
    });
  }

  // Get all users of a specific type (student or teacher)
  Widget _buildChatList(String userType) {
    if (_currentUser == null) {
      return const Center(child: Text('Please log in to view chats.'));
    }

    return Column(
      children: [
        // Search TextField for chat list
        Container(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or message...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<QueryDocumentSnapshot>>(
            stream: _getCachedUserList(userType),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final docs = snap.data ?? [];
              if (docs.isEmpty) {
                return Center(child: Text('No ${userType}s found.'));
              }

              // Create a stream that combines all user message streams for real-time sorting
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getCombinedUserMessagesStream(docs, userType),
                builder: (context, sortedSnapshot) {
                  if (sortedSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final sortedUsers = sortedSnapshot.data ?? [];
                  
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    itemCount: sortedUsers.length,
                    itemBuilder: (ctx, i) {
                      final userInfo = sortedUsers[i];
                      final userId = userInfo['id'];
                      final userData = userInfo['data'] as Map<String, dynamic>;
                      final userName = userData['name']?.toString() ?? 'Unknown User';
                      final isSelected = _selectedUserId == userId && selectedChat == userType;

                      return StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('${userType}Chats')
                            .doc(userId)
                            .collection('messages')
                            .orderBy('timestamp', descending: true)
                            .limit(1)
                            .snapshots()
                            .distinct(), // Avoid duplicate emissions
                        builder: (msgCtx, msgSnap) {
                          String lastMessage = 'No messages yet';
                          String timeLabel = '';
                          String? lastMessageUserId;
                          bool isUnread = false;

                          if (msgSnap.hasData && msgSnap.data!.docs.isNotEmpty) {
                            final msgData = msgSnap.data!.docs.first.data() as Map<String, dynamic>;
                            lastMessage = msgData['content'] ?? lastMessage;
                            final ts = msgData['timestamp'] as Timestamp?;
                            lastMessageUserId = msgData['userId'];
                            
                            if (ts != null) {
                              timeLabel = DateFormat('HH:mm').format(ts.toDate());
                            }

                            // Check if this is an unread message (not from current user)
                            if (lastMessageUserId != _currentUser!.uid) {
                              isUnread = _unreadMessages[userId] != false; // Default to true if not explicitly marked as read
                            }
                          }

                          // Filter by search query - check both user name and last message
                          if (_searchQuery.isNotEmpty) {
                            final nameMatches = userName.toLowerCase().contains(_searchQuery);
                            final messageMatches = lastMessage.toLowerCase().contains(_searchQuery);
                            if (!nameMatches && !messageMatches) {
                              return const SizedBox.shrink();
                            }
                          }

                          // Highlight search terms in user name and last message
                          Widget userNameWidget;
                          Widget lastMessageWidget;

                          if (_searchQuery.isNotEmpty && userName.toLowerCase().contains(_searchQuery)) {
                            final lowerName = userName.toLowerCase();
                            final searchIndex = lowerName.indexOf(_searchQuery);
                            final beforeSearch = userName.substring(0, searchIndex);
                            final searchTerm = userName.substring(searchIndex, searchIndex + _searchQuery.length);
                            final afterSearch = userName.substring(searchIndex + _searchQuery.length);
                            
                            userNameWidget = RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 14,
                                  color: isUnread ? Colors.black : Colors.black87,
                                ),
                                children: [
                                  TextSpan(text: beforeSearch),
                                  TextSpan(
                                    text: searchTerm,
                                    style: TextStyle(
                                      backgroundColor: Colors.yellow,
                                      fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 14,
                                      color: isUnread ? Colors.black : Colors.black87,
                                    ),
                                  ),
                                  TextSpan(text: afterSearch),
                                ],
                              ),
                            );
                          } else {
                            userNameWidget = Text(
                              userName,
                              style: TextStyle(
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                fontSize: 14,
                                color: isUnread ? Colors.black : Colors.black87,
                              ),
                            );
                          }

                          if (_searchQuery.isNotEmpty && lastMessage.toLowerCase().contains(_searchQuery)) {
                            final lowerMessage = lastMessage.toLowerCase();
                            final searchIndex = lowerMessage.indexOf(_searchQuery);
                            final beforeSearch = lastMessage.substring(0, searchIndex);
                            final searchTerm = lastMessage.substring(searchIndex, searchIndex + _searchQuery.length);
                            final afterSearch = lastMessage.substring(searchIndex + _searchQuery.length);
                            
                            lastMessageWidget = RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isUnread ? Colors.black87 : Colors.grey[600],
                                  fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                                ),
                                children: [
                                  TextSpan(text: beforeSearch),
                                  TextSpan(
                                    text: searchTerm,
                                    style: TextStyle(
                                      backgroundColor: Colors.yellow,
                                      fontSize: 12,
                                      color: isUnread ? Colors.black87 : Colors.grey[600],
                                      fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                                    ),
                                  ),
                                  TextSpan(text: afterSearch),
                                ],
                              ),
                            );
                          } else {
                            lastMessageWidget = Text(
                              lastMessage,
                              style: TextStyle(
                                fontSize: 12,
                                color: isUnread ? Colors.black87 : Colors.grey[600],
                                fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          }

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            color: isSelected ? Colors.grey[100] : Colors.white,
                            child: ListTile(
                              dense: true,
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        userType == 'student' ? studentColor : teacherColor,
                                    child: Text(
                                      userName[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  if (isUnread)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: userNameWidget),
                                  if (timeLabel.isNotEmpty)
                                    Text(
                                      timeLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isUnread ? Colors.red : Colors.grey[600],
                                        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: lastMessageWidget,
                              onTap: () {
                                // Only update state if actually changing
                                if (selectedChat != userType || _selectedUserId != userId) {
                                  setState(() {
                                    selectedChat = userType;
                                    _selectedUserId = userId;
                                    // Mark as read immediately when tapped
                                    _unreadMessages[userId] = false;
                                  });
                                  // Clear chat search when switching chats
                                  _chatSearchController.clear();
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Create a combined stream that sorts users by their latest message timestamp in real-time
  Stream<List<Map<String, dynamic>>> _getCombinedUserMessagesStream(List<QueryDocumentSnapshot> docs, String userType) async* {
    // Cache for last message timestamps to avoid repeated queries
    Map<String, DateTime> lastMessageCache = {};
    
    // Initial load - get all users with their last message times
    List<Map<String, dynamic>> usersWithTimestamp = [];
    
    for (var doc in docs) {
      final userId = doc.id;
      final userData = doc.data() as Map<String, dynamic>;
      
      try {
        // Get the last message for this user
        final lastMessageQuery = await _firestore
            .collection('${userType}Chats')
            .doc(userId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
        
        DateTime lastMessageTime = DateTime.fromMillisecondsSinceEpoch(0);
        if (lastMessageQuery.docs.isNotEmpty) {
          final msgData = lastMessageQuery.docs.first.data();
          final timestamp = msgData['timestamp'] as Timestamp?;
          lastMessageTime = timestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        }
        
        lastMessageCache[userId] = lastMessageTime;
        usersWithTimestamp.add({
          'id': userId,
          'data': userData,
          'lastMessageTime': lastMessageTime,
        });
      } catch (e) {
        lastMessageCache[userId] = DateTime.fromMillisecondsSinceEpoch(0);
        usersWithTimestamp.add({
          'id': userId,
          'data': userData,
          'lastMessageTime': DateTime.fromMillisecondsSinceEpoch(0),
        });
      }
    }
    
    // Sort by last message time (most recent first)
    usersWithTimestamp.sort((a, b) {
      final timeA = a['lastMessageTime'] as DateTime;
      final timeB = b['lastMessageTime'] as DateTime;
      return timeB.compareTo(timeA);
    });
    
    // Yield initial result immediately
    yield usersWithTimestamp;
    
    // Listen to all message collections for real-time updates
    await for (final _ in Stream.periodic(Duration(milliseconds: 500))) {
      bool hasChanges = false;
      List<Map<String, dynamic>> updatedUsers = [];
      
      for (var doc in docs) {
        final userId = doc.id;
        final userData = doc.data() as Map<String, dynamic>;
        
        try {
          // Quick check for new messages
          final lastMessageQuery = await _firestore
              .collection('${userType}Chats')
              .doc(userId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();
          
          DateTime newLastMessageTime = DateTime.fromMillisecondsSinceEpoch(0);
          if (lastMessageQuery.docs.isNotEmpty) {
            final msgData = lastMessageQuery.docs.first.data();
            final timestamp = msgData['timestamp'] as Timestamp?;
            newLastMessageTime = timestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          }
          
          // Only update if timestamp changed
          if (lastMessageCache[userId] != newLastMessageTime) {
            lastMessageCache[userId] = newLastMessageTime;
            hasChanges = true;
          }
          
          updatedUsers.add({
            'id': userId,
            'data': userData,
            'lastMessageTime': newLastMessageTime,
          });
        } catch (e) {
          updatedUsers.add({
            'id': userId,
            'data': userData,
            'lastMessageTime': lastMessageCache[userId] ?? DateTime.fromMillisecondsSinceEpoch(0),
          });
        }
      }
      
      // Only yield if there are changes
      if (hasChanges) {
        updatedUsers.sort((a, b) {
          final timeA = a['lastMessageTime'] as DateTime;
          final timeB = b['lastMessageTime'] as DateTime;
          return timeB.compareTo(timeA);
        });
        yield updatedUsers;
      }
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUser == null || _selectedUserId == null) return;

    final uid = _currentUser!.uid;

    try {
      // Add message to the specific user's chat
      await _firestore
          .collection('${selectedChat}Chats')
          .doc(_selectedUserId)
          .collection('messages')
          .add({
        'userId': uid,
        'content': text,
        'timestamp': FieldValue.serverTimestamp(),
        'userType': 'admin', // Admin is sending the message
      });

      _messageController.clear();
      // Auto-scroll to bottom after sending message
      _scrollChatToBottomDelayed();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send failed: $e')),
      );
    }
  }

  Widget _buildChatSection() {
    if (_currentUser == null) {
      return const Center(child: Text('Please log in.'));
    }
    if (_selectedUserId == null) {
      return const Center(child: Text('Select a user to start chatting.'));
    }

    final uid = _currentUser!.uid;

    return FutureBuilder<String>(
      future: _getUserName(_selectedUserId!),
      builder: (context, nameSnapshot) {
        final userName = nameSnapshot.data ?? 'Loading...';
        
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Colors.grey[100],
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        selectedChat == 'student' ? studentColor : teacherColor,
                    child: Text(
                      userName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chat with $userName',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            // Chat Search TextField
            if (_selectedUserId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[50],
                child: TextField(
                  controller: _chatSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search in this chat...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _chatSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _chatSearchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('${selectedChat}Chats')
                    .doc(_selectedUserId)
                    .collection('messages')
                    .orderBy('timestamp')
                    .snapshots()
                    .distinct(), // Avoid duplicate emissions
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No messages yet.'));
                  }

                  // Auto-scroll to bottom when new messages arrive
                  _scrollChatToBottomDelayed();

                  // Filter messages based on search query
                  final filteredDocs = _chatSearchQuery.isEmpty
                      ? docs
                      : docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final content = data['content']?.toString().toLowerCase() ?? '';
                          return content.contains(_chatSearchQuery);
                        }).toList();

                  if (filteredDocs.isEmpty && _chatSearchQuery.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No messages found for "$_chatSearchQuery"',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _chatScrollController, // Add scroll controller
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredDocs.length,
                    itemBuilder: (ctx, i) {
                      final data = filteredDocs[i].data() as Map<String, dynamic>;
                      final isMe = data['userId'] == uid;
                      final content = data['content'] ?? '';
                      final ts = data['timestamp'] as Timestamp?;
                      final time = ts != null
                          ? DateFormat('HH:mm').format(ts.toDate())
                          : '';
                      
                      // Highlight search term in message content
                      Widget messageContent;
                      if (_chatSearchQuery.isNotEmpty && content.toLowerCase().contains(_chatSearchQuery)) {
                        final lowerContent = content.toLowerCase();
                        final searchIndex = lowerContent.indexOf(_chatSearchQuery);
                        final beforeSearch = content.substring(0, searchIndex);
                        final searchTerm = content.substring(searchIndex, searchIndex + _chatSearchQuery.length);
                        final afterSearch = content.substring(searchIndex + _chatSearchQuery.length);
                        
                        messageContent = RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black),
                            children: [
                              TextSpan(text: beforeSearch),
                              TextSpan(
                                text: searchTerm,
                                style: const TextStyle(
                                  backgroundColor: Colors.yellow,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(text: afterSearch),
                            ],
                          ),
                        );
                      } else {
                        messageContent = Text(content);
                      }
                      
                      return FutureBuilder<String>(
                        future: _getUserName(data['userId']),
                        builder: (context, nameSnapshot) {
                          final senderName = nameSnapshot.data ?? 'Loading...';
                          
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
                                color: isMe
                                    ? sentMessageColor
                                    : receivedMessageColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (!isMe) ...[
                                    Text(
                                      senderName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  messageContent,
                                  if (time.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        time,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
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
                    maxLines: null, // Allow multiple lines like WhatsApp
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (value) {
                      // Send message when Enter is pressed
                      if (value.trim().isNotEmpty) {
                        _sendMessage();
                      }
                    },
                  ),
                ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _sendMessage,
                    backgroundColor: selectedChat == 'student'
                        ? studentColor
                        : teacherColor,
                    mini: true,
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        body: Center(child: Text('Please log in to access chat.')),
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
