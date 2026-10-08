import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/utils/id_generator.dart';
import '../models/user.dart';
import 'pet_repository.dart';
import 'saving_streak_repository.dart';

/// Handles registration/login. Local-first: users are created in SQLite
/// immediately so the app is usable offline; [ApiEndpoints.login] /
/// [ApiEndpoints.register] are ready for when the Spring Boot backend
/// (with real password hashing + JWT) is wired in.
class AuthRepository {
  final Database _db;
  AuthRepository(this._db);

  String _hash(String password) => sha256.convert(utf8.encode(password)).toString();

  Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final existing = await _db.query(Tables.users, where: 'email = ?', whereArgs: [email]);
    if (existing.isNotEmpty) {
      throw Exception('Email đã được sử dụng');
    }

    final user = AppUser(
      id: IdGenerator.next(),
      fullName: fullName,
      email: email,
      passwordHash: _hash(password),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _db.insert(Tables.users, user.toMap());

    // New users start with a pet + a streak row (per ERD: 1-to-1).
    await PetRepository(_db).createDefaultForUser(user.id);
    await SavingStreakRepository(_db).createDefaultForUser(user.id);

    // TODO(backend): await ApiClient.instance.post(ApiEndpoints.register, body: {...});
    await _persistSession(user.id);
    return user;
  }

  Future<AppUser> login({required String email, required String password}) async {
    final rows = await _db.query(Tables.users, where: 'email = ?', whereArgs: [email]);
    if (rows.isEmpty) throw Exception('Tài khoản không tồn tại');
    final user = AppUser.fromMap(rows.first);
    if (user.passwordHash != _hash(password)) {
      throw Exception('Sai mật khẩu');
    }
    // TODO(backend): await ApiClient.instance.post(ApiEndpoints.login, body: {...});
    await _persistSession(user.id);
    return user;
  }

  Future<void> _persistSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_id', userId);
  }

  Future<String?> getSessionUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_user_id');
  }

  Future<AppUser?> getCurrentUser() async {
    final userId = await getSessionUserId();
    if (userId == null) return null;
    final rows = await _db.query(Tables.users, where: 'id = ?', whereArgs: [userId]);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    await ApiClient.instance.clearToken();
  }

  Future<void> updateProfile(AppUser user) async {
    await _db.update(Tables.users, user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }
}
