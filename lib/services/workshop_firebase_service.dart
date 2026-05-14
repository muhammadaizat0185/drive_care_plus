import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workshop.dart';

class WorkshopFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get localized reviews for a specific workshop (place_id)
  Stream<List<WorkshopReview>> getInternalReviews(String placeId) {
    return _firestore
        .collection('workshop_reviews')
        .where('place_id', isEqualTo: placeId)
        .snapshots()
        .map((snapshot) {
      final reviews = snapshot.docs.map((doc) => WorkshopReview.fromMap(doc.data())).toList();
      // Sort locally to avoid needing a composite index in Firestore
      reviews.sort((a, b) {
        final dateA = a.timestamp ?? DateTime(0);
        final dateB = b.timestamp ?? DateTime(0);
        return dateB.compareTo(dateA);
      });
      return reviews;
    });
  }

  // Submit a new review to Firestore
  Future<void> submitReview(String placeId, WorkshopReview review) async {
    await _firestore.collection('workshop_reviews').add({
      'place_id': placeId,
      ...review.toMap(),
    });
  }

  // Create a new booking
  Future<void> createBooking(Map<String, dynamic> bookingData) async {
    await _firestore.collection('bookings').add({
      ...bookingData,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
