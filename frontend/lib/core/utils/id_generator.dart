import 'package:uuid/uuid.dart';

/// Client-side UUID generation. This is required (see design doc "Các
/// quyết định thiết kế quan trọng") so that records created offline on
/// different devices never collide when they're later synced to the
/// Spring Boot backend.
class IdGenerator {
  IdGenerator._();
  static const _uuid = Uuid();
  static String next() => _uuid.v4();
  // Keep this namespace stable: all devices must derive the same occurrence ID.
  static const _occurrenceNs = 'b3a1f6d2-5c4e-4f0a-9a31-7d2e8c1f0a55';
  static String forOccurrence(String scheduledId, String date) =>
      _uuid.v5(_occurrenceNs, '$scheduledId|$date');
}
