import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationsController {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of admin notifications
  static Stream<QuerySnapshot> getAdminNotificationsStream() {
    return _firestore
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore
        .collection('admin_notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Delete notification
  static Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection('admin_notifications')
        .doc(notificationId)
        .delete();
  }

  // Get unread notifications count
  static Stream<int> getUnreadNotificationsCount() {
    return _firestore
        .collection('admin_notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Handle post report action
  static Future<void> handlePostReport(String reportId, String action) async {
    try {
      // Get the report data
      final reportDoc = await _firestore.collection('reports').doc(reportId).get();
      if (!reportDoc.exists) return;

      final reportData = reportDoc.data() as Map<String, dynamic>;
      final postId = reportData['postId'] as String?;
      final reportedUserId = reportData['reportedUserId'] as String?;

      switch (action) {
        case 'delete_post':
          // Delete the reported post
          if (postId != null) {
            await _firestore.collection('posts').doc(postId).delete();
          }
          break;
        
        case 'warn_user':
          // Add warning to user
          if (reportedUserId != null) {
            await _firestore
                .collection('user_warnings')
                .doc(reportedUserId)
                .collection('warnings')
                .add({
              'reason': reportData['reason'],
              'reportedAt': reportData['reportedAt'],
              'warningAt': FieldValue.serverTimestamp(),
              'postId': postId,
            });
          }
          break;
        
        case 'restrict_user':
          // Restrict user from posting
          if (reportedUserId != null) {
            await _firestore
                .collection('restricted_users')
                .doc(reportedUserId)
                .set({
              'isRestricted': true,
              'restrictedAt': FieldValue.serverTimestamp(),
              'reason': reportData['reason'],
              'restrictedBy': 'admin',
            });
          }
          break;
        
        case 'ignore':
          // Just mark as reviewed, no action
          break;
      }

      // Update report status
      await _firestore.collection('reports').doc(reportId).update({
        'status': 'reviewed',
        'action': action,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      // Mark notification as read
      final notificationQuery = await _firestore
          .collection('admin_notifications')
          .where('type', isEqualTo: 'post_report')
          .where('data.postId', isEqualTo: postId)
          .get();
      
      for (var doc in notificationQuery.docs) {
        await doc.reference.update({'isRead': true});
      }

    } catch (e) {
      print('Error handling post report: $e');
    }
  }
}

class NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback? onTap;

  const NotificationCard({
    Key? key,
    required this.notification,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isRead = notification['isRead'] ?? false;
    final type = notification['type'] ?? '';
    final title = notification['title'] ?? '';
    final message = notification['message'] ?? '';
    final createdAt = notification['createdAt'] as Timestamp?;
    final priority = notification['priority'] ?? 'normal';

    Color priorityColor;
    IconData priorityIcon;
    
    switch (priority) {
      case 'high':
        priorityColor = Colors.red;
        priorityIcon = Icons.priority_high;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        priorityIcon = Icons.warning;
        break;
      default:
        priorityColor = Colors.blue;
        priorityIcon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isRead ? 1 : 3,
      color: isRead ? Colors.grey[50] : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Priority indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  type == 'post_report' ? Icons.flag : priorityIcon,
                  color: priorityColor,
                  size: 20,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              color: isRead ? Colors.grey[600] : Colors.black,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    if (createdAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formatTimestamp(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
} 