import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../models/user_profile.dart';
import '../models/account.dart';
import 'logger_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User?> registerOwner({
    required String email,
    required String password,
    required String displayName,
    String beneficiaryName = AppConstants.defaultBeneficiaryName,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;
      if (user == null) return null;

      await user.updateDisplayName(displayName);

      final accountId = _uuid.v4();
      final profile = UserProfile(
        uid: user.uid,
        email: email,
        displayName: displayName,
        accountId: accountId,
        role: AppConstants.roleOwner,
      );

      final account = Account(
        id: accountId,
        beneficiaryName: beneficiaryName,
        ownerId: user.uid,
        createdAt: DateTime.now(),
      );

      final member = AccountMember(
        userId: user.uid,
        role: AppConstants.roleOwner,
        email: email,
        displayName: displayName,
        invitedAt: DateTime.now(),
      );

      final batch = _firestore.batch();
      batch.set(
        _firestore.collection(AppConstants.usersCollection).doc(user.uid),
        profile.toMap(),
      );
      batch.set(
        _firestore.collection(AppConstants.accountsCollection).doc(accountId),
        account.toMap(),
      );
      batch.set(
        _firestore
            .collection(AppConstants.accountsCollection)
            .doc(accountId)
            .collection(AppConstants.membersSubcollection)
            .doc(user.uid),
        member.toMap(),
      );
      await batch.commit();

      return user;
    } on FirebaseAuthException catch (e) {
      LoggerService.error('Registration error: ${e.code}', e);
      rethrow;
    } catch (e) {
      LoggerService.error('Error registering owner', e);
      rethrow;
    }
  }

  Future<User?> registerAssistant({
    required String email,
    required String password,
    required String displayName,
    required String inviteCode,
  }) async {
    try {
      final codeDoc = await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .doc(inviteCode.toUpperCase())
          .get();

      if (!codeDoc.exists) {
        throw FirebaseAuthException(
          code: 'invalid-invite-code',
          message: 'Invalid invite code',
        );
      }

      final invite = InviteCode.fromMap(codeDoc.id, codeDoc.data()!);
      if (!invite.isValid) {
        throw FirebaseAuthException(
          code: 'expired-invite-code',
          message: 'Invite code has expired or been used',
        );
      }

      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;
      if (user == null) return null;

      await user.updateDisplayName(displayName);

      final profile = UserProfile(
        uid: user.uid,
        email: email,
        displayName: displayName,
        accountId: invite.accountId,
        role: AppConstants.roleAssistant,
      );

      final member = AccountMember(
        userId: user.uid,
        role: AppConstants.roleAssistant,
        email: email,
        displayName: displayName,
        invitedAt: DateTime.now(),
      );

      final batch = _firestore.batch();
      batch.set(
        _firestore.collection(AppConstants.usersCollection).doc(user.uid),
        profile.toMap(),
      );
      batch.set(
        _firestore
            .collection(AppConstants.accountsCollection)
            .doc(invite.accountId)
            .collection(AppConstants.membersSubcollection)
            .doc(user.uid),
        member.toMap(),
      );
      batch.update(
        _firestore.collection(AppConstants.inviteCodesCollection).doc(invite.code),
        {'used': true},
      );
      await batch.commit();

      return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      LoggerService.error('Error registering assistant', e);
      rethrow;
    }
  }

  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      LoggerService.error('Sign in error: ${e.code}', e);
      rethrow;
    }
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc =
          await _firestore.collection(AppConstants.usersCollection).doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      LoggerService.error('Error getting user profile', e);
      return null;
    }
  }

  Future<bool> updateUserProfile(UserProfile profile) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(profile.uid)
          .update(profile.copyWith().toMap());

      if (currentUser != null &&
          currentUser!.displayName != profile.displayName) {
        await currentUser!.updateDisplayName(profile.displayName);
      }
      return true;
    } catch (e) {
      LoggerService.error('Error updating user profile', e);
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<Account?> getAccount(String accountId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.accountsCollection)
          .doc(accountId)
          .get();
      if (doc.exists) {
        return Account.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      LoggerService.error('Error getting account', e);
      return null;
    }
  }

  Future<List<AccountMember>> getAccountMembers(String accountId) async {
    try {
      final snap = await _firestore
          .collection(AppConstants.accountsCollection)
          .doc(accountId)
          .collection(AppConstants.membersSubcollection)
          .get();
      return snap.docs
          .map((d) => AccountMember.fromMap(d.id, d.data()))
          .toList();
    } catch (e) {
      LoggerService.error('Error getting account members', e);
      return [];
    }
  }
}
