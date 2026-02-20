import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/request_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // التحقق هل المستخدم يملك حساباً
  Future<bool> checkUserExists(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists;
  }

  // جلب بيانات المستخدم (✅ تم إضافة حماية ضد الانهيار Null Check)
  Stream<UserModel> getUserData(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        // إذا لم يجد البيانات، يعطي بيانات افتراضية لمنع الشاشة الحمراء
        return UserModel(uid: uid, email: 'error', name: 'جاري التحميل...', major: '', skills: [], wallet: 0);
      }
      return UserModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  // نشر طلب جديد
  Future<void> createRequest(String title, String description, String topic, List<String> times, UserModel user) async {
    await _db.collection('requests').add({
      'studentId': user.uid,
      'studentName': user.name,
      'title': title,
      'description': description,
      'category': topic, // نستخدم الموضوع هنا
      'tags': [topic], 
      'availableTimes': times,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'OPEN',
      'applicants': [],
      'selectedTutorId': null,
    });
  }

  // عرض المساعدة
  Future<void> applyToRequest(String requestId, String tutorId) async {
    await _db.collection('requests').doc(requestId).update({
      'applicants': FieldValue.arrayUnion([tutorId])
    });
  }

  // اختيار المعلم
  Future<void> selectTutor(String requestId, String tutorId) async {
    await _db.collection('requests').doc(requestId).update({
      'selectedTutorId': tutorId,
      'status': 'IN_PROGRESS',
    });
  }

  // جلب الطلبات (للرئيسية)
  Stream<List<RequestModel>> getMyFeed(List<String> mySkills, String myUid) {
    return _db.collection('requests').orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      var requests = snapshot.docs.map((doc) => RequestModel.fromMap(doc.data(), doc.id)).toList();
      return requests.where((req) => req.studentId != myUid && req.status == 'OPEN').toList();
    });
  }

  // جلب طلباتي فقط
  Stream<List<RequestModel>> getMyRequests(String myUid) {
    return _db.collection('requests').where('studentId', isEqualTo: myUid).snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => RequestModel.fromMap(doc.data(), doc.id)).toList();
      // Sort client-side to avoid requiring a Firestore composite index
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}