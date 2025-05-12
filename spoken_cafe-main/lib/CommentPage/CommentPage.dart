import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommentPage extends ConsumerStatefulWidget {
  final String postId;
  final Function(int)? onCommentAdded;
  final Map<String, dynamic> comments;

  const CommentPage({
    super.key,
    this.onCommentAdded,
    required this.postId,
    required this.comments,
  });

  @override
  ConsumerState<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends ConsumerState<CommentPage> {
  final TextEditingController _commentController = TextEditingController();
  late Stream<QuerySnapshot> _commentsStream;
  bool _isAddingComment = false;

  @override
  void initState() {
    super.initState();
    _commentsStream = FirebaseFirestore.instance
        .collection('User posts')
        .doc(widget.postId)
        .collection('Comments')
        .orderBy('CommentTime', descending: true)
        .snapshots();
  }

  Future<void> _addComment() async {
    if (_isAddingComment || widget.postId.isEmpty) return;
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    setState(() => _isAddingComment = true);

    try {
      await FirebaseFirestore.instance
          .collection('User posts')
          .doc(widget.postId)
          .collection('Comments')
          .add({
        'CommentText': commentText,
        'CommentTime': Timestamp.now(),
        'isFavorite': false,
        'favoriteCount': 0,
      });
      _commentController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to post comment'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingComment = false);
        FocusScope.of(context).unfocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Comments',
          style: TextStyle(
            color: Color(0xff1B1212),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xff1B1212)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
             child: StreamBuilder<QuerySnapshot>(
              stream: _commentsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(
                    color: Color(0xff1B1212),
                     
                               backgroundColor: Colors.white,
                    strokeWidth: 20,
                  ),);
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No comments yet'));
                }
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.amber,
                      ),
                      title: Text(doc['CommentText']),
                      subtitle: Text(_formatDate(doc['CommentTime'].toDate())),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(doc['favoriteCount'].toString()),
                          IconButton(
                            icon: Icon(
                              doc['isFavorite'] ? Icons.favorite : Icons.favorite_border,
                              color: Colors.red,
                            ),
                            onPressed: () => _toggleFavorite(doc.id, doc['isFavorite']),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextFormField(
              controller: _commentController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: Color(0xff1B1212),
                    width: 2,
                  ),
                ),
                hintText: 'Write a comment...',
                suffixIcon: _isAddingComment
                    ? SizedBox( 
                      height: 10.0,
                       width: 10.0,
                      child: CircularProgressIndicator(
                       color: Color(0xff1B1212),
                               backgroundColor: Colors.white,
                      strokeWidth: 1,
                      
                    ))
                    : IconButton(
                        icon: const Icon(Icons.send, color: Color(0xff1B1212)),
                        onPressed: _addComment,
                      ),
              ),
              onFieldSubmitted: (_) => _addComment(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(String commentId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('User posts')
          .doc(widget.postId)
          .collection('Comments')
          .doc(commentId)
          .update({
        'isFavorite': !currentStatus,
        'favoriteCount': FieldValue.increment(currentStatus ? -1 : 1),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Failed to update favorite'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
