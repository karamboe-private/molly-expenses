import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/account.dart';
import '../services/auth_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/logger_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final BiometricAuthService _biometricAuthService = BiometricAuthService();

  User? _user;
  UserProfile? _userProfile;
  Account? _account;
  List<AccountMember> _members = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _hasStoredBiometricCredentials = false;
  bool _biometricUnlocked = true;
  String _biometricLabel = 'Biometrics';

  User? get user => _user;
  UserProfile? get userProfile => _userProfile;
  Account? get account => _account;
  List<AccountMember> get members => _members;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isOwner => _userProfile?.isOwner ?? false;
  String? get accountId => _userProfile?.accountId;
  bool get biometricAvailable => _biometricAvailable;
  bool get biometricLoginEnabled => _biometricEnabled;
  bool get hasStoredBiometricCredentials => _hasStoredBiometricCredentials;
  bool get requiresBiometricUnlock =>
      isAuthenticated && _biometricEnabled && !_biometricUnlocked;
  String get biometricLabel => _biometricLabel;

  AuthProvider() {
    _loadBiometricState();
    _authService.authStateChanges.listen((user) async {
      _user = user;
      if (user != null) {
        await loadUserProfile();
        await _applyBiometricLockIfNeeded();
      } else {
        _userProfile = null;
        _account = null;
        _members = [];
        _biometricUnlocked = true;
      }
      notifyListeners();
    });
  }

  Future<void> _loadBiometricState() async {
    _biometricAvailable = await _biometricAuthService.isAvailable();
    _biometricEnabled = await _biometricAuthService.isEnabled();
    _hasStoredBiometricCredentials =
        await _biometricAuthService.hasStoredCredentials();
    if (_biometricAvailable) {
      _biometricLabel = await _biometricAuthService.biometricLabel();
    }
    notifyListeners();
  }

  Future<void> refreshBiometricState() => _loadBiometricState();

  Future<void> _applyBiometricLockIfNeeded() async {
    if (_biometricEnabled) {
      _biometricUnlocked = false;
    }
  }

  void lockApp() {
    if (_biometricEnabled && isAuthenticated) {
      _biometricUnlocked = false;
      notifyListeners();
    }
  }

  Future<bool> unlockWithBiometrics() async {
    if (!_biometricAvailable || !_biometricEnabled) {
      _biometricUnlocked = true;
      notifyListeners();
      return true;
    }

    _errorMessage = null;
    final success = await _biometricAuthService.authenticate(
      reason: 'Unlock Molly Expenses',
    );

    if (success) {
      _biometricUnlocked = true;
      notifyListeners();
      return true;
    }

    _errorMessage = '$_biometricLabel authentication failed';
    notifyListeners();
    return false;
  }

  Future<bool> signInWithBiometrics() async {
    if (!_biometricAvailable || !_hasStoredBiometricCredentials) {
      _errorMessage = '$_biometricLabel sign-in is not set up';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authenticated = await _biometricAuthService.authenticate(
        reason: 'Sign in to Molly Expenses',
      );
      if (!authenticated) {
        _isLoading = false;
        _errorMessage = '$_biometricLabel authentication cancelled';
        notifyListeners();
        return false;
      }

      final credentials = await _biometricAuthService.readCredentials();
      if (credentials == null) {
        _isLoading = false;
        _errorMessage = 'Saved sign-in details not found';
        notifyListeners();
        return false;
      }

      final user = await _authService.signInWithEmailPassword(
        credentials.email,
        credentials.password,
      );

      _isLoading = false;
      if (user != null) {
        _user = user;
        _biometricUnlocked = true;
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

  Future<bool> enableBiometricLogin({
    required String email,
    required String password,
  }) async {
    if (!_biometricAvailable) return false;

    await _biometricAuthService.saveCredentials(
      email: email,
      password: password,
    );
    await _loadBiometricState();
    _biometricUnlocked = true;
    return true;
  }

  Future<bool> enableBiometricAppLock() async {
    if (!_biometricAvailable) return false;

    final authenticated = await _biometricAuthService.authenticate(
      reason: 'Enable $_biometricLabel for Molly Expenses',
    );
    if (!authenticated) return false;

    await _biometricAuthService.enableAppLockOnly();
    await _loadBiometricState();
    _biometricUnlocked = true;
    notifyListeners();
    return true;
  }

  Future<void> disableBiometricLogin() async {
    await _biometricAuthService.disable();
    _biometricUnlocked = true;
    await _loadBiometricState();
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
    _biometricUnlocked = true;
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
