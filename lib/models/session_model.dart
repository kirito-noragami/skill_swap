import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String id;
  final String requestId;
  final String requestTitle;
  final String requesterId;
  final String helperId;
  final String helperName;
  final String requesterName;
  final String confirmedTime; // ISO string
  final String status;        // BOOKED | ACTIVE | COMPLETED | CANCELLED
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int minutesCompleted;
  final int requesterStartSP;  // SP requester had when session started
  final bool fraudDetected;

  SessionModel({
    required this.id,
    required this.requestId,
    required this.requestTitle,
    required this.requesterId,
    required this.helperId,
    required this.helperName,
    required this.requesterName,
    required this.confirmedTime,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.minutesCompleted = 0,
    this.requesterStartSP = 0,
    this.fraudDetected = false,
  });

  /// The scheduled session start time
  DateTime get scheduledTime => DateTime.parse(confirmedTime);

  /// Chat unlocks 5 minutes before the session
  DateTime get unlockTime => scheduledTime.subtract(const Duration(minutes: 5));

  /// Notification fires 10 minutes before
  DateTime get notifyTime => scheduledTime.subtract(const Duration(minutes: 10));

  bool get isChatUnlocked => DateTime.now().isAfter(unlockTime);

  factory SessionModel.fromMap(Map<String, dynamic> map, String id) {
    return SessionModel(
      id: id,
      requestId: map['requestId'] ?? '',
      requestTitle: map['requestTitle'] ?? '',
      requesterId: map['requesterId'] ?? '',
      helperId: map['helperId'] ?? '',
      helperName: map['helperName'] ?? '',
      requesterName: map['requesterName'] ?? '',
      confirmedTime: map['confirmedTime'] ?? DateTime.now().toIso8601String(),
      status: map['status'] ?? 'BOOKED',
      startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
      endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
      minutesCompleted: map['minutesCompleted'] ?? 0,
      requesterStartSP: map['requesterStartSP'] ?? 0,
      fraudDetected: map['fraudDetected'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'requestTitle': requestTitle,
      'requesterId': requesterId,
      'helperId': helperId,
      'helperName': helperName,
      'requesterName': requesterName,
      'confirmedTime': confirmedTime,
      'status': status,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'minutesCompleted': minutesCompleted,
      'requesterStartSP': requesterStartSP,
      'fraudDetected': fraudDetected,
    };
  }
}