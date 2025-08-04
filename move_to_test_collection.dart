import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('🔄 Starting to move test data to test collection...');
  
  try {
    // Get all documents from the original cities collection
    final querySnapshot = await FirebaseFirestore.instance
        .collection('cities')
        .get();

    if (querySnapshot.docs.isEmpty) {
      print('ℹ️  No documents found in cities collection');
      return;
    }

    print('📊 Found ${querySnapshot.docs.length} documents to move');

    // Create batch for moving documents
    final batch = FirebaseFirestore.instance.batch();
    
    // Move each document to test_cities collection
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      
      // Create new document in test_cities collection
      final newDocRef = FirebaseFirestore.instance
          .collection('test_cities')
          .doc(doc.id);
      
      batch.set(newDocRef, data);
      
      // Delete from original collection
      batch.delete(doc.reference);
      
      print('🔄 Moving document ${doc.id} to test_cities collection');
    }

    // Commit the batch
    await batch.commit();
    
    print('✅ Successfully moved ${querySnapshot.docs.length} documents to test_cities collection');
    print('🎉 Test data migration completed!');
    print('💡 Now you can safely clear test data without affecting production!');
    
  } catch (e) {
    print('❌ Error moving test data: $e');
  }
  
  // Exit the program
  exit(0);
} 