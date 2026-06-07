/// Pure expiry-classification helper used by the document vault and other
/// screens that surface time-sensitive items.
///
/// [ExpiryStatus] describes how a stored item's `expiryDate` relates to the
/// current moment:
///
/// * [ExpiryStatus.noExpiry] — the item has no expiry date.
/// * [ExpiryStatus.error]    — the item expired more than 30 days ago.
/// * [ExpiryStatus.warning]  — the item is within 30 days of `now` in either
///   direction (upcoming within 30 days OR expired within the last 30 days).
/// * [ExpiryStatus.ok]       — the item expires more than 30 days in the
///   future.
enum ExpiryStatus { ok, warning, error, noExpiry }

/// Classifies an [expiry] date against the current time [now] using the
/// four-branch rule documented in the design (Document Vault section):
///
/// ```
/// if expiry == null              → ExpiryStatus.noExpiry
/// if (now - expiry).inDays > 30  → ExpiryStatus.error    (expired > 30 days)
/// if |expiry - now|.inDays <= 30 → ExpiryStatus.warning  (within 30 days
///                                                         either side)
/// else                            → ExpiryStatus.ok      (more than 30 days
///                                                         in future)
/// ```
///
/// Branches are evaluated in order, so an item that expired exactly 30 days
/// ago is classified as [ExpiryStatus.warning] (the error branch requires
/// `> 30`), and an item that expires exactly 30 days from now is also
/// [ExpiryStatus.warning].
///
/// Pure: no IO, no side effects, deterministic for any `(expiry, now)` pair.
///
/// See: figma-ui-redesign Requirements 10.4, 10.5.
ExpiryStatus expiryStatusOf(DateTime? expiry, DateTime now) {
  if (expiry == null) {
    return ExpiryStatus.noExpiry;
  }

  final Duration delta = now.difference(expiry);
  if (delta.inDays > 30) {
    return ExpiryStatus.error;
  }
  if (delta.abs().inDays <= 30) {
    return ExpiryStatus.warning;
  }
  return ExpiryStatus.ok;
}
