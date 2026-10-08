import 'package:uuid/uuid.dart';

/// Client-side UUID generation. This is required (see design doc "Các
/// quyết định thiết kế quan trọng") so that records created offline on
/// different devices never collide when they're later synced to the
/// Spring Boot backend.
class IdGenerator {
  IdGenerator._();
  static const _uuid = Uuid();
  static String next() => _uuid.v4();
}
