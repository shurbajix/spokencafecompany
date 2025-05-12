import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final postsProvider =
    StateNotifierProvider<PostNotifier, List<Map<String, dynamic>>>((ref) {
  return PostNotifier(ref);
});

class PostNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  PostNotifier(this.ref) : super([]);

  final Ref ref;

  // Fetch posts from Firestore
  Future<void> fetchPosts() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .get();

    final posts = querySnapshot.docs.map((doc) {
      return {
        'text': doc['text'],
        'mediaUrls': List<String>.from(doc['mediaUrls'] ?? []),
        'createdAt': doc['timestamp'],
      };
    }).toList();

    state = posts; // Update the state with the fetched posts
  }

  // Add new post to Firestore and update the state
  Future<void> addPost(String text, List<String> mediaUrls) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc();
    await postRef.set({
      'text': text,
      'mediaUrls': mediaUrls,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Fetch posts again after adding a new one
    await fetchPosts();
  }
}
