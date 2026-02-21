import 'package:cloud_firestore/cloud_firestore.dart';

class RequestModel {
  final String id;
  final String studentId;
  final String studentName;
  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final List<String> availableTimes;
  final DateTime createdAt;
  final String status;
  final List<String> applicants;
  final String? selectedTutorId;

  // Maps tutorId → list of ISO time slots they proposed
  final Map<String, List<String>> applications;

  RequestModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.title,
    required this.description,
    required this.category,
    required this.tags,
    required this.availableTimes,
    required this.createdAt,
    required this.status,
    required this.applicants,
    this.selectedTutorId,
    this.applications = const {},
  });

  factory RequestModel.fromMap(Map<String, dynamic> map, String documentId) {
    // Parse applications map: {tutorId: [iso1, iso2, ...]}
    final rawApps = map['applications'] as Map<String, dynamic>? ?? {};
    final applications = rawApps.map(
      (key, value) => MapEntry(key, List<String>.from(value ?? [])),
    );

    return RequestModel(
      id: documentId,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? 'طالب',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      availableTimes: List<String>.from(map['availableTimes'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'OPEN',
      applicants: List<String>.from(map['applicants'] ?? []),
      selectedTutorId: map['selectedTutorId'],
      applications: applications,
    );
  }
}