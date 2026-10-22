import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/database/txn_ext.dart';
import '../core/network/api_client.dart';
import '../core/utils/clock.dart';
import '../core/utils/id_generator.dart';
import '../models/user.dart';
import 'pet_repository.dart';
import 'saving_streak_repository.dart';
import '../core/network/api_endpoints.dart';

class AuthRepository {
  final DatabaseExecutor _db;
  AuthRepository(this._db);

  String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();
  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<AppUser> register(
      {required String fullName,
      required String email,
      required String password}) async {
    final mail = _normalizeEmail(email);
    final name = fullName.trim();
    if (name.isEmpty) throw Exception('Họ tên không được để trống');
    final dup = await _db.query(Tables.users,
        columns: ['id'], where: 'email = ?', whereArgs: [mail], limit: 1);
    if (dup.isNotEmpty) throw Exception('Email đã được sử dụng');

    final id = IdGenerator.next();
    final Map<String, dynamic> res;
    try {
      res = await ApiClient.instance.post(ApiEndpoints.register, body: {
        'id': id,
        'full_name': name,
        'email': mail,
        'password': password,
      }) as Map<String, dynamic>;
    } on NetworkException {
      throw Exception('Cần kết nối mạng để đăng ký lần đầu');
    } on ApiException catch (e) {
      if (e.code == 'EMAIL_ALREADY_EXISTS') {
        throw Exception('Email đã được sử dụng');
      }
      throw Exception(e.message);
    }

    final user = await _db.inTxn((e) => _createLocalUser(
        e, id: id, fullName: name, email: mail, password: password));
    await ApiClient.instance.saveToken(res['token'] as String);
    await _persistSession(user.id);
    return user;
  }

  Future<AppUser> login(
      {required String email, required String password}) async {
    final mail = _normalizeEmail(email);
    try {
      final res = await ApiClient.instance.post(ApiEndpoints.login, body: {
        'email': mail,
        'password': password,
      }) as Map<String, dynamic>;
      final su = res['user'] as Map<String, dynamic>;
      final user = await _upsertLocalUser(
        id: su['id'] as String,
        fullName: su['full_name'] as String,
        email: mail,
        password: password,
      );
      await ApiClient.instance.saveToken(res['token'] as String);
      await _persistSession(user.id);
      return user;
    } on NetworkException {
      return _loginOffline(mail, password);
    } on ApiException catch (e) {
      if (e.code == 'INVALID_CREDENTIALS') {
        throw Exception('Sai email hoặc mật khẩu');
      }
      throw Exception(e.message);
    }
  }

  Future<AppUser> _createLocalUser(DatabaseExecutor e,
      {required String id,
      required String fullName,
      required String email,
      required String password}) async {
    final now = nowUtc();
    final u = AppUser(
        id: id,
        fullName: fullName,
        email: email,
        passwordHash: _hash(password),
        createdAt: now,
        updatedAt: now);
    await e.insert(Tables.users, u.toMap());
    await PetRepository(e).createDefaultForUser(u.id);
    await SavingStreakRepository(e).createDefaultForUser(u.id);
    return u;
  }

  Future<AppUser> _upsertLocalUser(
      {required String id,
      required String fullName,
      required String email,
      required String password}) async {
    final rows = await _db.query(Tables.users,
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) {
      return _db.inTxn((e) => _createLocalUser(e,
          id: id, fullName: fullName, email: email, password: password));
    }
    final newHash = _hash(password);
    await _db.update(
        Tables.users,
        {'password_hash': newHash, 'full_name': fullName, 'is_deleted': 0},
        where: 'id = ?',
        whereArgs: [id]);
    return AppUser.fromMap({
      ...rows.first,
      'password_hash': newHash,
      'full_name': fullName,
      'is_deleted': 0
    });
  }

  Future<AppUser> _loginOffline(String mail, String password) async {
    final rows = await _db.query(Tables.users,
        where: 'email = ? AND is_deleted = 0', whereArgs: [mail], limit: 1);
    if (rows.isEmpty || AppUser.fromMap(rows.first).passwordHash != _hash(password)) {
      throw Exception('Sai email hoặc mật khẩu');
    }
    final user = AppUser.fromMap(rows.first);
    await ApiClient.instance.clearToken();
    await _persistSession(user.id);
    return user;
  }

  Future<void> _persistSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_id', userId);
  }

  Future<String?> getSessionUserId() async =>
      (await SharedPreferences.getInstance()).getString('current_user_id');

  Future<AppUser?> getCurrentUser() async {
    final userId = await getSessionUserId();
    if (userId == null) return null;
    final rows = await _db.query(Tables.users,
        where: 'id = ? AND is_deleted = 0', whereArgs: [userId]);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    await ApiClient.instance.clearToken();
  }

  Future<void> updateProfile(AppUser user) async =>
      _db.update(Tables.users, user.toMap(),
          where: 'id = ?', whereArgs: [user.id]);
}
