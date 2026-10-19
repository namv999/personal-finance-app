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

class AuthRepository {
  final DatabaseExecutor _db;
  AuthRepository(this._db);

  String _hash(String password) => sha256.convert(utf8.encode(password)).toString();
  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<AppUser> register({required String fullName, required String email, required String password}) async {
    final mail = _normalizeEmail(email);
    final name = fullName.trim();
    if (name.isEmpty) throw Exception('Họ tên không được để trống');
    final dup = await _db.query(Tables.users, columns: ['id'], where: 'email = ?', whereArgs: [mail], limit: 1);
    if (dup.isNotEmpty) throw Exception('Email đã được sử dụng');

    // TODO(backend): require online POST /auth/register {id, full_name, email, password}.
    final id = IdGenerator.next();
    final user = await _db.inTxn((e) async {
      final now = nowUtc();
      final u = AppUser(id: id, fullName: name, email: mail, passwordHash: _hash(password), createdAt: now, updatedAt: now);
      await e.insert(Tables.users, u.toMap());
      await PetRepository(e).createDefaultForUser(u.id);
      await SavingStreakRepository(e).createDefaultForUser(u.id);
      return u;
    });
    await _persistSession(user.id);
    return user;
  }

  Future<AppUser> login({required String email, required String password}) async {
    final mail = _normalizeEmail(email);
    // TODO(backend): online login first; on network failure allow a local hash.
    final rows = await _db.query(Tables.users, where: 'email = ? AND is_deleted = 0', whereArgs: [mail], limit: 1);
    if (rows.isEmpty || AppUser.fromMap(rows.first).passwordHash != _hash(password)) {
      throw Exception('Sai email hoặc mật khẩu');
    }
    final user = AppUser.fromMap(rows.first);
    await _persistSession(user.id);
    return user;
  }

  Future<void> _persistSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_id', userId);
  }

  Future<String?> getSessionUserId() async => (await SharedPreferences.getInstance()).getString('current_user_id');

  Future<AppUser?> getCurrentUser() async {
    final userId = await getSessionUserId();
    if (userId == null) return null;
    final rows = await _db.query(Tables.users, where: 'id = ? AND is_deleted = 0', whereArgs: [userId]);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    await ApiClient.instance.clearToken();
  }

  Future<void> updateProfile(AppUser user) async => _db.update(Tables.users, user.toMap(), where: 'id = ?', whereArgs: [user.id]);
}
