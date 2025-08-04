import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('🗑️  Starting to clear test data from Firebase...');
  
  try {
    // Get all documents from the test_cities collection
    final querySnapshot = await FirebaseFirestore.instance
        .collection('test_cities')
        .get();

    if (querySnapshot.docs.isEmpty) {
      print('ℹ️  No documents found in test_cities collection');
      return;
    }

    print('📊 Found ${querySnapshot.docs.length} documents to delete');

    // Delete each document
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in querySnapshot.docs) {
      batch.delete(doc.reference);
      print('🗑️  Marking document ${doc.id} for deletion');
    }

    // Commit the batch
    await batch.commit();
    
    print('✅ Successfully cleared ${querySnapshot.docs.length} test documents from test_cities collection');
    print('🎉 Test data cleanup completed!');
    
  } catch (e) {
    print('❌ Error clearing test data: $e');
  }
  
  // Exit the program
  exit(0);
} 