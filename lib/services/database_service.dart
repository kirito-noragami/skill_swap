import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/request_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. جلب بيانات المستخدم الحالي
  Stream<UserModel> getUserData(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      return UserModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  // 2. نشر طلب جديد
  Future<void> createRequest(String title, String category, UserModel user) async {
    await _db.collection('requests').add({
      'studentId': user.uid,
      'studentName': user.name,
      'title': title,
      'category': category, // هنا نستخدم التخصص كـ Category للسهولة
      'tags': [category],   // تبسيط للوقت
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'OPEN',
      'applicants': [],
      'selectedTutorId': null,
    });
  }

  // 3. (InDrive Logic) معلم يعرض المساعدة
  Future<void> applyToRequest(String requestId, String tutorId) async {
    await _db.collection('requests').doc(requestId).update({
      'applicants': FieldValue.arrayUnion([tutorId]) // إضافة الـ ID للقائمة
    });
  }

  // 4. (Selection Logic) الطالب يختار المعلم
  Future<void> selectTutor(String requestId, String tutorId) async {
    await _db.collection('requests').doc(requestId).update({
      'selectedTutorId': tutorId,
      'status': 'IN_PROGRESS', // تحويل حالة الطلب
    });
    // هنا يجب إنشاء غرفة شات (سنقوم بها لاحقاً)
  }

  // 5. جلب الطلبات المناسبة لمهاراتي (الخوارزمية)
  Stream<List<RequestModel>> getMyFeed(List<String> mySkills) {
    // هذه الكويري بسيطة: تجلب كل الطلبات المفتوحة
    // التصفية الدقيقة ستتم في الواجهة للسرعة
    return _db
        .collection('requests')
        .where('status', isEqualTo: 'OPEN')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => RequestModel.fromMap(doc.data(), doc.id)).toList();
    });
  }
}