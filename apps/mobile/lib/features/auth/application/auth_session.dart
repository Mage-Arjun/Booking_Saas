import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/auth_repository.dart';
import '../data/models/user.dart';

final authSessionProvider = ChangeNotifierProvider<AuthSessionController>((ref) {
  final controller = AuthSessionController(repository: ref.watch(authRepositoryProvider));

  // NOTE: ChangeNotifierProvider already disposes the controller when the
  // provider is disposed. Registering another dispose callback here would
  // dispose the ChangeNotifier twice and throw in debug mode.

  /// Start session restoration as soon as the provider is first used. This
  /// keeps startup behavior out of widget build methods.
  Future<void>.microtask(controller.restore);
  return controller;
});

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Owns the application's authentication state and lifecycle.
class AuthSessionController extends ChangeNotifier {
  AuthSessionController({required this.repository});

  final AuthRepository repository;
  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  Object? _error;
  bool _busy = false;

  AuthStatus get status => _status;
  User? get user => _user;
  Object? get error => _error;
  bool get isBusy => _busy;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> restore() async {
    if (_status != AuthStatus.unknown) return;
    _busy = true;
    notifyListeners();
    try {
      final access = await repository.secureStorage.getAccessToken();
      final refresh = await repository.secureStorage.getRefreshToken();
      if ((access == null || access.isEmpty) && (refresh == null || refresh.isEmpty)) {
        _status = AuthStatus.unauthenticated;
        return;
      }
      _user = await repository.getCurrentUser();
      _status = AuthStatus.authenticated;
    } catch (error) {
      await repository.secureStorage.clearTokens();
      _user = null;
      _status = AuthStatus.unauthenticated;
      _error = mapDioException(error);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    await _run(() async {
      await repository.login(email: email, password: password);
      _user = await repository.getCurrentUser();
      _status = AuthStatus.authenticated;
    });
  }

  Future<void> register({required String email, required String password, required UserRole role}) async {
    await _run(() async {
      await repository.register(email: email, password: password, role: role.toJson());
      _user = await repository.getCurrentUser();
      _status = AuthStatus.authenticated;
    });
  }

  Future<void> logout() async {
    _busy = true;
    notifyListeners();
    try {
      await repository.logout();
    } finally {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _error = mapDioException(error);
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
