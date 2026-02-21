import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../models/session_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../screens/chat/chat_screen.dart';


class ApplicantsScreen extends StatefulWidget {
  final RequestModel request;
  final int requesterCurrentSP;

  const ApplicantsScreen({
    super.key,
    required this.request,
    required this.requesterCurrentSP,
  });

  @override
  State<ApplicantsScreen> createState() => _ApplicantsScreenState();
}

class _ApplicantsScreenState extends State<ApplicantsScreen> {
  List<UserModel> _applicants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadApplicants();
  }

  Future<void> _loadApplicants() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final results = await Future.wait(
      widget.request.applicants.map((uid) => db.getUserOnce(uid)),
    );
    setState(() {
      _applicants = results.whereType<UserModel>().toList();
      _loading = false;
    });
  }

  String _formatSlot(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
      const months = ['', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final period = dt.hour >= 12 ? 'م' : 'ص';
      final min = dt.minute.toString().padLeft(2, '0');
      return '${days[dt.weekday % 7]} ${dt.day} ${months[dt.month]}  $hour:$min $period';
    } catch (_) {
      return iso;
    }
  }

  void _selectHelper(UserModel helper) {
    final applicantTimes = widget.request.applications[helper.uid] ?? [];
    if (applicantTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("هذا المعلم لم يحدد أوقاتاً"), backgroundColor: Colors.orange),
      );
      return;
    }
    _showTimeSelectionSheet(helper, applicantTimes);
  }

  void _showTimeSelectionSheet(UserModel helper, List<String> times) {
    String? selected;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "اختر وقت الجلسة مع ${helper.name}",
                    style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "رصيدك الحالي: ${widget.requesterCurrentSP} SP — الجلسة ستستمر حتى نفاد الرصيد",
                    style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ...times.map((iso) {
                    final isSelected = selected == iso;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selected = iso),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.indigo : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.indigo : Colors.grey.shade200,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.access_time,
                              color: isSelected ? Colors.white : Colors.indigo,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formatSlot(iso),
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: selected == null
                          ? null
                          : () {
                              Navigator.pop(sheetCtx);
                              _confirmSession(helper, selected!);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        disabledBackgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        "تأكيد الجلسة",
                        style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmSession(UserModel helper, String confirmedTime) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final me = auth.currentUser!;

    // Get requester's name
    final meData = await db.getUserOnce(me.uid);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final sessionId = await db.createSession(
        requestId: widget.request.id,
        requestTitle: widget.request.title,
        requesterId: me.uid,
        requesterName: meData?.name ?? 'طالب',
        helperId: helper.uid,
        helperName: helper.name,
        confirmedTime: confirmedTime,
        requesterCurrentSP: widget.requesterCurrentSP,
      );

      // Schedule local notifications — wrapped separately so a failure
      // never blocks session creation or navigation
      try {
        await NotificationService().scheduleSessionNotifications(
          sessionId: sessionId,
          helperName: helper.name,
          requestTitle: widget.request.title,
          sessionTime: DateTime.parse(confirmedTime),
        );
      } catch (notifError) {
        // Notification failed (ProGuard/permissions) — session continues fine
        debugPrint('Notification error (non-fatal): \$notifError');
      }

      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      final session = SessionModel(
        id: sessionId,
        requestId: widget.request.id,
        requestTitle: widget.request.title,
        requesterId: me.uid,
        requesterName: meData?.name ?? 'طالب',
        helperId: helper.uid,
        helperName: helper.name,
        confirmedTime: confirmedTime,
        status: 'BOOKED',
        requesterStartSP: widget.requesterCurrentSP,
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(session: session, isRequester: true)),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text("اختر معلمك", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            color: Colors.indigo.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.request.title,
                    style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: Colors.amber.shade700, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    "${widget.request.applicants.length} عروض",
                    style: GoogleFonts.cairo(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _applicants.isEmpty
              ? Center(child: Text("لا توجد عروض بعد", style: GoogleFonts.cairo(color: Colors.grey, fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _applicants.length,
                  itemBuilder: (context, index) {
                    final helper = _applicants[index];
                    final rating = helper.rating;
                    final minutes = helper.totalMinutesHelped;
                    final hours = (minutes / 60).floor();
                    final remainingMin = minutes % 60;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Header row ──────────────────────────────────
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.indigo.shade50,
                                  child: Text(
                                    helper.name.isNotEmpty ? helper.name[0].toUpperCase() : '?',
                                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        helper.name,
                                        style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        helper.major.isNotEmpty ? helper.major : 'طالب',
                                        style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 14),

                            // ── Stats row ────────────────────────────────────
                            Row(
                              children: [
                                _statBadge(
                                  icon: Icons.star_rounded,
                                  color: Colors.amber,
                                  label: rating == 0 ? "جديد" : rating.toStringAsFixed(1),
                                  sublabel: "التقييم",
                                ),
                                const SizedBox(width: 12),
                                _statBadge(
                                  icon: Icons.access_time_filled,
                                  color: Colors.green,
                                  label: hours > 0 ? "${hours}س ${remainingMin}د" : "${minutes}د",
                                  sublabel: "خبرة تدريس",
                                ),
                                const SizedBox(width: 12),
                                _statBadge(
                                  icon: Icons.people,
                                  color: Colors.blue,
                                  label: "${helper.ratingCount}",
                                  sublabel: "طلاب ساعدهم",
                                ),
                              ],
                            ),

                            // ── Skills ────────────────────────────────────────
                            if (helper.skills.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6, runSpacing: 4,
                                children: helper.skills.take(5).map((skill) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(skill, style: GoogleFonts.cairo(fontSize: 11, color: Colors.indigo.shade800, fontWeight: FontWeight.bold)),
                                )).toList(),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // ── Select button ─────────────────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: () => _selectHelper(helper),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(
                                  "اختيار هذا المعلم",
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _statBadge({required IconData icon, required Color color, required String label, required String sublabel}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(sublabel, style: GoogleFonts.cairo(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}