import 'package:cloud_firestore/cloud_firestore.dart';

class Teacher {
  final String name;
  final String email;
  final String phoneNumber;
  final String docId;
  final String? profileImageUrl;
  final String? verificationVideo;
  final String? verificationDocument;
  final String? verificationDescription;
  final bool isVerified;

  Teacher({
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.docId,
    this.profileImageUrl,
    this.verificationVideo,
    this.verificationDocument,
    this.verificationDescription,
    required this.isVerified,
  });

  factory Teacher.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Teacher(
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phone'] ?? '',
      docId: doc.id,
      profileImageUrl: data['profileImage'] as String?,
      verificationVideo: data['verificationVideo'] as String?,
      verificationDocument: data['verificationDocument'] as String?,
      verificationDescription:
          data['verificationDescription'] as String?,
      isVerified: data['isVerified'] == true,
    );
  }
}
