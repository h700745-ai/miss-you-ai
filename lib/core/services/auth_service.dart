import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/user_model.dart';
import '../models/couple_model.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    final model = UserModel(
      uid: uid,
      name: name,
      email: email,
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(uid).set(model.toMap());
    await cred.user!.updateDisplayName(name);
    return model;
  }

  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return getUser(cred.user!.uid);
  }

  Future<void> signOut() => _auth.signOut();

  Future<UserModel> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw Exception('User profile not found.');
    }
    return UserModel.fromMap(doc.data()!, uid);
  }

  Stream<UserModel> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
          (doc) => UserModel.fromMap(doc.data()!, uid),
        );
  }

  Future<String> createInvite(String uid) async {
    final code = _generateCode();
    final coupleRef = _db.collection('couples').doc();
    final couple = CoupleModel(
      coupleId: coupleRef.id,
      memberUids: [uid],
      inviteCode: code,
      createdAt: DateTime.now(),
    );
    await coupleRef.set(couple.toMap());
    await _db.collection('invites').doc(code).set({
      'coupleId': coupleRef.id,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<CoupleModel> joinWithInvite({
    required String uid,
    required String code,
  }) async {
    final inviteDoc = await _db.collection('invites').doc(code).get();
    if (!inviteDoc.exists) {
      throw Exception('Invalid invite code. Double-check with your partner.');
    }
    final coupleId = inviteDoc.data()!['coupleId'] as String;
    final creatorUid = inviteDoc.data()!['createdBy'] as String;

    if (creatorUid == uid) {
      throw Exception('You can\'t pair with yourself 😄');
    }

    final coupleRef = _db.collection('couples').doc(coupleId);

    return _db.runTransaction<CoupleModel>((tx) async {
      final coupleSnap = await tx.get(coupleRef);
      final couple = CoupleModel.fromMap(coupleSnap.data()!, coupleId);

      if (couple.memberUids.length >= 2) {
        throw Exception('This invite has already been used.');
      }

      final updatedMembers = [...couple.memberUids, uid];
      tx.update(coupleRef, {'memberUids': updatedMembers});

      // Only write to our OWN user doc — never the partner's.
      tx.update(_db.collection('users').doc(uid), {
        'coupleId': coupleId,
        'partnerUid': creatorUid,
      });

      return CoupleModel.fromMap(
        {...coupleSnap.data()!, 'memberUids': updatedMembers},
        coupleId,
      );
    });
  }

  /// Watches for a couple document that contains this user with exactly
  /// 2 members — this is how we detect "fully paired" without ever
  /// needing to write to the partner's own user document.
  Stream<CoupleModel?> watchCoupleForUser(String uid) {
    return _db
        .collection('couples')
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .map((snap) {
      for (final doc in snap.docs) {
        final couple = CoupleModel.fromMap(doc.data(), doc.id);
        if (couple.memberUids.length == 2) return couple;
      }
      return null;
    });
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
