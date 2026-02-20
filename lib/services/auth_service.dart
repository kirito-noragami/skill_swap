import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Current user ─────────────────────────────────────────
  User? get currentUser => _auth.currentUser;

  // ── Auth state stream ─────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Phone Auth ────────────────────────────────────────────
  Future<void> verifyPhoneNumber(
    String phoneNumber, {
    required Function(String, int?) codeSent,
    required Function(FirebaseAuthException) verificationFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification on Android (e.g. SMS auto-fill)
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<String?> signInWithOTP(String verificationId, String smsCode) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _auth.signInWithCredential(credential);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // ── Email & Password ──────────────────────────────────────
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  /// Creates a new user with email/password and saves their profile.
  /// ✅ FIX: Saves BOTH 'wallet' and 'coins' + proper 'stats' sub-map
  /// so UserModel.fromMap() reads them without issues.
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'name': name,
          'major': 'General',
          'skills': [],
          'role': 'student',
          'wallet': 10,  // ✅ matches UserModel.fromMap primary key
          'coins': 10,   // ✅ backup field
          'stats': {
            'totalMinutesHelped': 0,
            'ratingSum': 0,
            'ratingCount': 0,
          },
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Sign out ──────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }
}