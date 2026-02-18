import 'package:cloud_firestore/cloud_firestore.dart';

class RequestModel {
  final String id;
  final String studentId;     // صاحب الطلب
  final String studentName;
  final String title;         // عنوان: شرح جافا
  final String category;      // القسم: برمجة
  final List<String> tags;    // وسوم: [Java, Arrays]
  final DateTime createdAt;
  final String status;        // OPEN, IN_PROGRESS, CLOSED
  
  // نظام InDrive
  final List<String> applicants; // قائمة الـ IDs للطلاب الذين عرضوا المساعدة
  final String? selectedTutorId; // المعلم الذي تم اختياره

  RequestModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.title,
    required this.category,
    required this.tags,
    required this.createdAt,
    required this.status,
    required this.applicants,
    this.selectedTutorId,
  });

  factory RequestModel.fromMap(Map<String, dynamic> map, String id) {
    return RequestModel(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? 'Unknown',
      title: map['title'] ?? '',
      category: map['category'] ?? 'General',
      tags: List<String>.from(map['tags'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'OPEN',
      applicants: List<String>.from(map['applicants'] ?? []),
      selectedTutorId: map['selectedTutorId'],
    );
  }
}