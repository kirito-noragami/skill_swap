import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // المستخدم الحالي
  User? get currentUser => _auth.currentUser;

  // تسجيل حساب جديد
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    required String major,
    required List<String> skills,
  }) async {
    try {
      // 1. إنشاء الحساب
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. إنشاء بيانات المستخدم في Firestore
      UserModel newUser = UserModel(
        uid: result.user!.uid,
        email: email,
        name: name,
        major: major,
        skills: skills,
        wallet: 30, // بونص البداية: 30 دقيقة
      );

      await _db.collection('users').doc(newUser.uid).set(newUser.toMap());
      return null; // نجاح
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // تسجيل الدخول
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    await _auth.signOut();
  }
}