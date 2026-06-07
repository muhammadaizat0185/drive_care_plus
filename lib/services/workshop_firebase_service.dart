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

  /// Toggles the favorite status for [workshopId] under the currently
  /// authenticated user, returning the new favorite state.
  ///
  /// The redesigned `WorkshopCard` (Task 9.8) calls this with optimistic
  /// UI: the heart fill is flipped locally before this future resolves
  /// and reverted by the caller if this future throws.
  ///
  /// Stored under
  /// `users/{uid}/favorite_workshops/{workshopId}` so the favorite set
  /// scopes per-user without requiring a top-level subcollection.
  ///
  /// Throws [StateError] if no user is signed in. Callers must guard
  /// against this case before calling.
  ///
  /// TODO(figma-ui-redesign Task 9.8): the redesigned card surfaces a
  /// favorite toggle UI but the Firestore security rules and
  /// favorite-list query are not yet wired into a list/dashboard view.
  /// This method is the persistence half of Requirement 7.6 / 7.7;
  /// downstream "favorites only" filters are out of scope for this
  /// batch.
  Future<bool> toggleFavorite(String workshopId, String userId) async {
    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection('users')
        .doc(userId)
        .collection('favorite_workshops')
        .doc(workshopId);

    final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
      return false;
    }
    await ref.set(<String, Object>{
      'workshop_id': workshopId,
      'created_at': FieldValue.serverTimestamp(),
    });
    return true;
  }

  /// Returns whether [workshopId] is favorited by [userId]. Used by the
  /// Browse list to seed the heart fill state when a card mounts.
  Future<bool> isFavorite(String workshopId, String userId) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorite_workshops')
        .doc(workshopId)
        .get();
    return snap.exists;
  }

  /// Streams the bookings for [userId] ordered most-recent-first. Used by
  /// the redesigned My Bookings tab (Task 9.13) to render confirmed
  /// bookings or, when the stream resolves to an empty list, the
  /// `AppEmptyState` `Browse Workshops` CTA.
  Stream<List<Map<String, dynamic>>> watchUserBookings(String userId) {
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  <String, dynamic>{
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList(),
        );
  }
}
