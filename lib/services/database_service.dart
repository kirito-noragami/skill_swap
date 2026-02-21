import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/request_model.dart';
import '../models/session_model.dart';
import '../models/chat_message_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // USER
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> checkUserExists(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists;
  }

  Stream<UserModel> getUserData(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return UserModel(uid: uid, email: 'error', name: 'جاري التحميل...', major: '', skills: [], wallet: 0);
      }
      return UserModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  Future<UserModel?> getUserOnce(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REQUESTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> createRequest(String title, String description, String topic,
      List<String> times, UserModel user) async {
    await _db.collection('requests').add({
      'studentId': user.uid,
      'studentName': user.name,
      'title': title,
      'description': description,
      'category': topic,
      'tags': [topic],
      'availableTimes': times,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'OPEN',
      'applicants': [],
      'applications': {},
      'selectedTutorId': null,
    });
  }

  Future<void> applyToRequest(
      String requestId, String tutorId, List<String> selectedTimes) async {
    await _db.collection('requests').doc(requestId).update({
      'applicants': FieldValue.arrayUnion([tutorId]),
      'applications.$tutorId': selectedTimes,
    });
  }

  Stream<List<RequestModel>> getMyFeed(List<String> mySkills, String myUid) {
    return _db
        .collection('requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      var requests = snapshot.docs
          .map((doc) => RequestModel.fromMap(doc.data(), doc.id))
          .toList();
      return requests
          .where((req) => req.studentId != myUid && req.status == 'OPEN')
          .toList();
    });
  }

  Stream<List<RequestModel>> getMyRequests(String myUid) {
    return _db
        .collection('requests')
        .where('studentId', isEqualTo: myUid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => RequestModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SESSIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a session. Stores `participants` array so both users can query it.
  Future<String> createSession({
    required String requestId,
    required String requestTitle,
    required String requesterId,
    required String requesterName,
    required String helperId,
    required String helperName,
    required String confirmedTime,
    required int requesterCurrentSP,
  }) async {
    await _db.collection('requests').doc(requestId).update({
      'status': 'IN_PROGRESS',
      'selectedTutorId': helperId,
    });

    final sessionRef = await _db.collection('sessions').add({
      'requestId': requestId,
      'requestTitle': requestTitle,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'helperId': helperId,
      'helperName': helperName,
      'confirmedTime': confirmedTime,
      'status': 'BOOKED',
      // ✅ participants array — lets both users query their own sessions
      'participants': [requesterId, helperId],
      'startedAt': null,
      'endedAt': null,
      'minutesCompleted': 0,
      'requesterStartSP': requesterCurrentSP,
      'fraudDetected': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return sessionRef.id;
  }

  Stream<SessionModel?> getSession(String sessionId) {
    return _db.collection('sessions').doc(sessionId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return SessionModel.fromMap(snap.data()!, snap.id);
    });
  }

  /// ✅ Uses array-contains on `participants` — works for both requester & helper
  /// No composite index needed, no permission issues.
  Stream<List<SessionModel>> getMySessions(String uid) {
    return _db
        .collection('sessions')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SessionModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      return list;
    });
  }

  Future<void> activateSession(String sessionId) async {
    await _db.collection('sessions').doc(sessionId).update({
      'status': 'ACTIVE',
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Single end-of-session bulk transfer instead of per-minute transactions.
  /// This avoids Firestore permission errors from writing to another user's doc.
  /// Call this ONCE when session ends.
  /// 
  /// ⚠️  For this to work, update your Firestore rules to allow wallet updates:
  ///
  /// match /users/{uid} {
  ///   allow read: if request.auth != null;
  ///   allow write: if request.auth.uid == uid;
  ///   allow update: if request.auth != null &&
  ///     request.resource.data.diff(resource.data)
  ///       .affectedKeys().hasOnly(['wallet', 'coins', 'totalMinutesHelped', 'stats']);
  /// }
  Future<void> finalizeSession({
    required String sessionId,
    required String requesterId,
    required String helperId,
    required int minutesCompleted,
    required bool fraudDetected,
  }) async {
    // 1. Update session document
    await _db.collection('sessions').doc(sessionId).update({
      'status': 'COMPLETED',
      'endedAt': FieldValue.serverTimestamp(),
      'minutesCompleted': minutesCompleted,
      'fraudDetected': fraudDetected,
    });

    if (minutesCompleted <= 0) return;

    if (fraudDetected) {
      // No transfer — session was empty, nothing to move
      return;
    }

    // 2. Transfer SP: requester → helper (single transaction at end)
    try {
      await _db.runTransaction((tx) async {
        final requesterRef = _db.collection('users').doc(requesterId);
        final helperRef = _db.collection('users').doc(helperId);

        final rSnap = await tx.get(requesterRef);
        final hSnap = await tx.get(helperRef);

        final rWallet = (rSnap.data()?['wallet'] ?? 0) as int;
        final hWallet = (hSnap.data()?['wallet'] ?? 0) as int;

        // Only transfer what requester actually has
        final toTransfer = minutesCompleted.clamp(0, rWallet);

        tx.update(requesterRef, {
          'wallet': rWallet - toTransfer,
          'coins': rWallet - toTransfer,
        });
        tx.update(helperRef, {
          'wallet': hWallet + toTransfer,
          'coins': hWallet + toTransfer,
          'totalMinutesHelped': FieldValue.increment(minutesCompleted),
          'stats.totalMinutesHelped': FieldValue.increment(minutesCompleted),
        });
      });
    } catch (e) {
      // Log but don't crash — session is already marked completed
      // ignore: avoid_print
      print('SP transfer error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CHAT MESSAGES
  // ─────────────────────────────────────────────────────────────────────────

  Stream<List<ChatMessage>> getMessages(String sessionId) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ChatMessage.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> sendMessage(String sessionId, ChatMessage message) async {
    await _db
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .add(message.toMap());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RATING
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> rateHelper(String helperUid, int stars) async {
    await _db.runTransaction((tx) async {
      final ref = _db.collection('users').doc(helperUid);
      final snap = await tx.get(ref);
      final ratingSum = (snap.data()?['stats']?['ratingSum'] ??
          snap.data()?['ratingSum'] ?? 0) as int;
      final ratingCount = (snap.data()?['stats']?['ratingCount'] ??
          snap.data()?['ratingCount'] ?? 0) as int;
      tx.update(ref, {
        'stats.ratingSum': ratingSum + stars,
        'stats.ratingCount': ratingCount + 1,
        'ratingSum': ratingSum + stars,
        'ratingCount': ratingCount + 1,
      });
    });
  }
}