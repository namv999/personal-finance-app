import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;
  AuthProvider(this._repo);

  AuthStatus status = AuthStatus.unknown;
  AppUser? currentUser;
  String? errorMessage;
  bool isLoading = false;

  Future<void> bootstrap() async {
    final user = await _repo.getCurrentUser();
    currentUser = user;
    status = user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> login(String email, String password) => _guard(() async {
        currentUser = await _repo.login(email: email, password: password);
        status = AuthStatus.authenticated;
      });

  Future<bool> register(String fullName, String email, String password) => _guard(() async {
        currentUser = await _repo.register(fullName: fullName, email: email, password: password);
        status = AuthStatus.authenticated;
      });

  Future<void> logout() async {
    await _repo.logout();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> updateProfile({String? fullName, int? monthlyIncome}) async {
    if (currentUser == null) return;
    final updated = currentUser!.copyWith(fullName: fullName, monthlyIncome: monthlyIncome);
    await _repo.updateProfile(updated);
    currentUser = updated;
    notifyListeners();
  }

  Future<bool> _guard(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
