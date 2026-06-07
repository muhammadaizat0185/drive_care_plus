import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workshop.dart';
import 'api_tracker_service.dart';

class WorkshopFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get localized reviews for a specific workshop (place_id)
  Stream<List<WorkshopReview>> getInternalReviews(String placeId) {
    ApiTracker.instance.trackCall('Cloud Firestore');
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
    ApiTracker.instance.trackCall('Cloud Firestore');
    await _firestore.collection('workshop_reviews').add({
      'place_id': placeId,
      ...review.toMap(),
    });
  }

  // Create a new booking and return the created document ID
  Future<String> createBooking(Map<String, dynamic> bookingData) async {
    ApiTracker.instance.trackCall('Cloud Firestore');
    final DocumentReference<Map<String, dynamic>> ref = await _firestore.collection('bookings').add({
      ...bookingData,
      'created_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Updates a booking's fields in Firestore.
  Future<void> updateBooking(String bookingId, Map<String, dynamic> updates) async {
    ApiTracker.instance.trackCall('Cloud Firestore');
    await _firestore.collection('bookings').doc(bookingId).update(updates);
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

    ApiTracker.instance.trackCall('Cloud Firestore');
    final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
    ApiTracker.instance.trackCall('Cloud Firestore');
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
    ApiTracker.instance.trackCall('Cloud Firestore');
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
    ApiTracker.instance.trackCall('Cloud Firestore');
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
  /// Cancels a booking by setting its status to 'Cancelled'.
  Future<void> cancelBooking(String bookingId) async {
    ApiTracker.instance.trackCall('Cloud Firestore');
    await _firestore.collection('bookings').doc(bookingId).update(<String, Object>{
      'status': 'Cancelled',
    });
  }

  /// Reschedules a booking with a new date and time and resets its status to 'Pending'.
  Future<void> rescheduleBooking(String bookingId, String isoDate, String timeString) async {
    ApiTracker.instance.trackCall('Cloud Firestore');
    await _firestore.collection('bookings').doc(bookingId).update(<String, Object>{
      'date': isoDate,
      'time': timeString,
      'status': 'Pending',
    });
  }
}
