import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/account.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  UserProfile? _userProfile;
  Account? _account;
  List<AccountMember> _members = [];
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  UserProfile? get userProfile => _userProfile;
  Account? get account => _account;
  List<AccountMember> get members => _members;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isOwner => _userProfile?.isOwner ?? false;
  String? get accountId => _userProfile?.accountId;

  AuthProvider() {
    _authService.authStateChanges.listen((user) async {
      _user = user;
      if (user != null) {
        await loadUserProfile();
      } else {
        _userProfile = null;
        _account = null;
        _members = [];
      }
      notifyListeners();
    });
  }

  Future<void> loadUserProfile() async {
    if (_user == null) return;

    try {
      _userProfile = await _authService.getUserProfile(_user!.uid);
      if (_userProfile?.accountId != null) {
        _account = await _authService.getAccount(_userProfile!.accountId!);
        _members =
            await _authService.getAccountMembers(_userProfile!.accountId!);
      }
      notifyListeners();
    } catch (e) {
      LoggerService.error('Error loading user profile', e);
    }
  }

  Future<bool> registerOwner({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.registerOwner(
        email: email,
        password: password,
        displayName: displayName,
      );

      _isLoading = false;
      if (user != null) {
        _user = user;
        await loadUserProfile();
        notifyListeners();
        return true;
      }

      _errorMessage = 'Registration failed';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerAssistant({
    required String email,
    required String password,
    required String displayName,
    required String inviteCode,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.registerAssistant(
        email: email,
        password: password,
        displayName: displayName,
        inviteCode: inviteCode,
      );

      _isLoading = false;
      if (user != null) {
        _user = user;
        await loadUserProfile();
        notifyListeners();
        return true;
      }

      _errorMessage = 'Registration failed';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user =
          await _authService.signInWithEmailPassword(email, password);

      _isLoading = false;
      if (user != null) {
        _user = user;
        await loadUserProfile();
        notifyListeners();
        return true;
      }

      _errorMessage = 'Sign in failed';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({String? displayName}) async {
    if (_userProfile == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final updated = _userProfile!.copyWith(displayName: displayName);
      final success = await _authService.updateUserProfile(updated);
      _isLoading = false;
      if (success) {
        _userProfile = updated;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Failed to update profile';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to update profile';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    _userProfile = null;
    _account = null;
    _members = [];
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String getMemberName(String userId) {
    final member = _members.where((m) => m.userId == userId).firstOrNull;
    return member?.displayName ?? userId;
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak (min 6 characters)';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'invalid-invite-code':
        return 'Invalid invite code';
      case 'expired-invite-code':
        return 'Invite code has expired or already been used';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return 'An error occurred. Please try again';
    }
  }
}
