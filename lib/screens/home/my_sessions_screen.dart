import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/session_model.dart';
import '../../screens/chat/chat_screen.dart';

class MySessionsScreen extends StatelessWidget {
  const MySessionsScreen({super.key});

  String _formatSlot(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const days = ['الأحد','الإثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];
      const months = ['','يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final p = dt.hour >= 12 ? 'م' : 'ص';
      return '${days[dt.weekday % 7]} ${dt.day} ${months[dt.month]}  $h:${dt.minute.toString().padLeft(2, '0')} $p';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: Text("جلساتي", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
        body: Center(child: Text("غير مسجل الدخول", style: GoogleFonts.cairo())),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text("جلساتي", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // ✅ Direct Firestore query — uses participants array-contains
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .where('participants', arrayContains: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text("خطأ:\n${snapshot.error}",
                      style: GoogleFonts.cairo(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("لا توجد جلسات حتى الآن", style: GoogleFonts.cairo(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text("ستظهر هنا الجلسات التي أنت طرف فيها", style: GoogleFonts.cairo(color: Colors.grey.shade400, fontSize: 13)),
                ],
              ),
            );
          }

          // Parse and sort by scheduled time
          final sessions = docs
              .map((doc) => SessionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList()
            ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

          // Separate active/booked from completed
          final upcoming = sessions.where((s) => s.status != 'COMPLETED' && s.status != 'CANCELLED').toList();
          final past = sessions.where((s) => s.status == 'COMPLETED' || s.status == 'CANCELLED').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (upcoming.isNotEmpty) ...[
                _sectionHeader("📅 الجلسات القادمة"),
                const SizedBox(height: 10),
                ...upcoming.map((s) => _sessionCard(context, s, uid)),
                const SizedBox(height: 20),
              ],
              if (past.isNotEmpty) ...[
                _sectionHeader("✅ الجلسات المنتهية"),
                const SizedBox(height: 10),
                ...past.map((s) => _sessionCard(context, s, uid)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title, style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo));
  }

  Widget _sessionCard(BuildContext context, SessionModel session, String uid) {
    final isRequester = session.requesterId == uid;
    final otherName = isRequester ? session.helperName : session.requesterName;
    final role = isRequester ? "طالب" : "معلم";
    final roleColor = isRequester ? Colors.blue : Colors.green;

    final now = DateTime.now();
    final isUnlocked = session.isChatUnlocked;
    final isCompleted = session.status == 'COMPLETED';
    final isBooked = session.status == 'BOOKED' || session.status == 'ACTIVE';

    // Decide what the action button does
    String btnLabel;
    Color btnColor;
    bool btnEnabled;

    if (isCompleted) {
      btnLabel = "منتهية";
      btnColor = Colors.grey;
      btnEnabled = false;
    } else if (!isUnlocked) {
      final diff = session.unlockTime.difference(now);
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      btnLabel = h > 0 ? "تفتح بعد ${h}س ${m}د" : "تفتح بعد ${m}د";
      btnColor = Colors.orange;
      btnEnabled = false;
    } else {
      btnLabel = "دخول الغرفة 🔓";
      btnColor = Colors.indigo;
      btnEnabled = true;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isUnlocked && isBooked
            ? Border.all(color: Colors.indigo.shade300, width: 2)
            : null,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title row
          Row(children: [
            Expanded(
              child: Text(session.requestTitle,
                  style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(role, style: GoogleFonts.cairo(color: roleColor, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 8),

          // Other user
          Row(children: [
            const Icon(Icons.person_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text(otherName, style: GoogleFonts.cairo(color: Colors.grey.shade700, fontSize: 13)),
          ]),
          const SizedBox(height: 6),

          // Time
          Row(children: [
            const Icon(Icons.access_time, size: 16, color: Colors.indigo),
            const SizedBox(width: 6),
            Text(_formatSlot(session.confirmedTime),
                style: GoogleFonts.cairo(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 13)),
          ]),

          if (isCompleted) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text("مدة الجلسة: ${session.minutesCompleted} دقيقة",
                  style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13)),
            ]),
          ],

          const SizedBox(height: 14),

          // Action button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: btnEnabled
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            session: session,
                            isRequester: isRequester,
                          ),
                        ),
                      )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                disabledBackgroundColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(btnLabel,
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      color: btnEnabled ? Colors.white : Colors.grey,
                      fontSize: 14)),
            ),
          ),
        ]),
      ),
    );
  }
}