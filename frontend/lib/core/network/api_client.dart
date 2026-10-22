import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_endpoints.dart';

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
    ));
    // Gắn token cho mọi request nếu có
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      final t = _authToken;
      if (t != null) o.headers['Authorization'] = 'Bearer $t';
      h.next(o);
    }));
  }
  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;
  String? _authToken;

  /// Gọi khi server trả 401 UNAUTHORIZED (token thiếu/hết hạn).
  /// UI/Provider gán callback này để báo "cần đăng nhập lại để đồng bộ".
  void Function()? onUnauthorized;

  bool get hasToken => _authToken != null;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
  }

  Future<void> saveToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      _send(() => _dio.post(path, data: body));

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) =>
      _send(() => _dio.put(path, data: body));

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final data = res.data;
      return (data is String && data.isEmpty) ? null : data;
    } on DioException catch (e) {
      throw await _mapError(e);
    }
  }

  Future<Exception> _mapError(DioException e) async {
    final res = e.response;
    // Không có response = mất mạng, timeout, không tới được server
    if (res == null) {
      return NetworkException('Không kết nối được máy chủ');
    }
    final status = res.statusCode ?? 0;
    String? code;
    var message = 'Lỗi máy chủ ($status)';
    final data = res.data;
    if (data is Map) {
      code = data['code']?.toString();
      message = data['message']?.toString() ?? message;
    }
    // Chỉ UNAUTHORIZED mới là token hỏng. INVALID_CREDENTIALS (sai mật khẩu) cũng 401 nhưng KHÔNG xóa token
    if (status == 401 && code == 'UNAUTHORIZED') {
      await clearToken();
      onUnauthorized?.call();
    }
    return ApiException(status, message, code: code);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String?
      code; // code của backend: EMAIL_ALREADY_EXISTS, INVALID_CREDENTIALS...
  ApiException(this.statusCode, this.message, {this.code});

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Lỗi tầng mạng, dùng để quyết định fallback offline
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
