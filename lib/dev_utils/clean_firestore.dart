import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Elimina todas las colecciones principales de Firestore (solo en debug)
Future<void> cleanFirestoreCollections() async {
  if (!kDebugMode) return;
  final firestore = FirebaseFirestore.instance;
  final batch = firestore.batch();
  final collections = ['users', 'circles'];
  for (final collection in collections) {
    final snapshot = await firestore.collection(collection).get();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
  }
  await batch.commit();
}
