/// Pure file-size formatting helper used by the document vault and other
/// screens that surface raw byte counts to the user.
///
/// Formats [bytes] as a one-decimal-place numeric value followed by a unit
/// (`B`, `KB`, or `MB`) selected by power-of-1024 thresholds:
///
/// * `bytes < 1024`            → `"<bytes>.0 B"`
/// * `bytes < 1024 * 1024`     → `"<bytes / 1024 to 1dp> KB"`
/// * `bytes >= 1024 * 1024`    → `"<bytes / (1024 * 1024) to 1dp> MB"`
///
/// The numeric portion is always rendered with exactly one decimal place via
/// [num.toStringAsFixed], and the value and unit are separated by a single
/// space.
///
/// Pure: no IO, no side effects, deterministic for any [bytes] input.
///
/// See: figma-ui-redesign Requirement 10.3.
String formatBytes(int bytes) {
  const int kb = 1024;
  const int mb = 1024 * 1024;

  if (bytes < kb) {
    return '${bytes.toDouble().toStringAsFixed(1)} B';
  }
  if (bytes < mb) {
    return '${(bytes / kb).toStringAsFixed(1)} KB';
  }
  return '${(bytes / mb).toStringAsFixed(1)} MB';
}
