import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> uploadQRImage(String base64Image, String fileName) async {
    try {
      final bytes = base64Decode(base64Image);
      final ref = FirebaseStorage.instance.ref().child('qr_proofs/$fileName.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await ref.getDownloadURL();
      print('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  Future<String> saveCheckIn({
    required String studentId,
    required String previousTopic,
    required String expectedTopic,
    required int moodScore,
    required double lat,
    required double lng,
    String? qrImageBase64,
  }) async {
    try {
      String? imageUrl;
      if (qrImageBase64 != null) {
        final fileName = '${studentId}_${DateTime.now().millisecondsSinceEpoch}';
        imageUrl = await uploadQRImage(qrImageBase64, fileName);
      }

      DocumentReference docRef = await _firestore.collection('attendance_logs').add({
        'student_id': studentId,
        'previous_topic': previousTopic,
        'expected_topic': expectedTopic,
        'mood_score': moodScore,
        'check_in_lat': lat,
        'check_in_lng': lng,
        'qr_image_url': imageUrl,
        'check_in_time': FieldValue.serverTimestamp(),
        'check_out_time': null,
        'check_out_lat': null,
        'check_out_lng': null,
        'learned_topic': null,
        'feedback': null,
      });
      print('Check-in data saved successfully for student: $studentId, document: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error saving check-in data: $e');
      rethrow;
    }
  }

  Future<void> saveCheckOut({
    required String documentId,
    required String learnedTopic,
    required String feedback,
    required double checkoutLat,
    required double checkoutLng,
  }) async {
    try {
      await _firestore.collection('attendance_logs').doc(documentId).update({
        'check_out_time': FieldValue.serverTimestamp(),
        'check_out_lat': checkoutLat,
        'check_out_lng': checkoutLng,
        'learned_topic': learnedTopic,
        'feedback': feedback,
      });
      print('Check-out data updated successfully for document: $documentId');
    } catch (e) {
      print('Error updating check-out data: $e');
      rethrow;
    }
  }
}