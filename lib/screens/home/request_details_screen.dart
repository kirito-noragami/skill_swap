import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/request_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'applicants_screen.dart';

class RequestDetailsScreen extends StatefulWidget {
  final RequestModel request;

  const RequestDetailsScreen({super.key, required this.request});

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  // Tutor's selected time slots (up to 3)
  final Set<String> _selectedSlots = {};
  bool _isApplying = false;

  // ── Format ISO string to readable Arabic label ───────────────────────────
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
      // Fallback: old free-text slots that aren't ISO format
      return iso;
    }
  }

  void _toggleSlot(String iso) {
    setState(() {
      if (_selectedSlots.contains(iso)) {
        _selectedSlots.remove(iso);
      } else {
        if (_selectedSlots.length >= 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("يمكنك اختيار 3 أوقات كحد أقصى"), backgroundColor: Colors.orange),
          );
          return;
        }
        _selectedSlots.add(iso);
      }
    });
  }

  void _applyToRequest() async {
    if (_selectedSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى اختيار وقت واحد على الأقل"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isApplying = true);

    try {
      final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
      final db = Provider.of<DatabaseService>(context, listen: false);

      await db.applyToRequest(
        widget.request.id,
        currentUser!.uid,
        _selectedSlots.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم تقديم عرضك بنجاح!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _isApplying = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    final bool isMyRequest = currentUser?.uid == widget.request.studentId;
    final bool alreadyApplied = widget.request.applicants.contains(currentUser?.uid);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text("تفاصيل الطلب", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info card ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.request.title,
                    style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 5),
                      Text("الطالب: ${widget.request.studentName}", style: GoogleFonts.cairo(color: Colors.grey[700])),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text("الوصف:", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(widget.request.description, style: GoogleFonts.cairo(fontSize: 15, height: 1.5)),

                  const SizedBox(height: 20),

                  // ── Time slots ─────────────────────────────────────────────
                  Row(
                    children: [
                      Text("الأوقات المتاحة:", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      if (!isMyRequest && !alreadyApplied)
                        Text(
                          "(اختر ما يناسبك — حد أقصى 3)",
                          style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.request.availableTimes.map((iso) {
                      final isSelected = _selectedSlots.contains(iso);

                      // Owner just sees them as labels (not selectable)
                      if (isMyRequest || alreadyApplied) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time, size: 14, color: Colors.green),
                              const SizedBox(width: 5),
                              Text(_formatSlot(iso), style: GoogleFonts.cairo(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        );
                      }

                      // Tutor sees selectable chips
                      return GestureDetector(
                        onTap: () => _toggleSlot(iso),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.indigo : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? Colors.indigo : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle : Icons.access_time,
                                size: 14,
                                color: isSelected ? Colors.white : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatSlot(iso),
                                style: GoogleFonts.cairo(
                                  color: isSelected ? Colors.white : Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // ── Bottom section ───────────────────────────────────────────────
            if (isMyRequest) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("المتقدمون للمساعدة:", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (widget.request.applicants.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.amber.shade700, borderRadius: BorderRadius.circular(20)),
                      child: Text("${widget.request.applicants.length} عروض", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.request.applicants.isEmpty)
                Center(child: Text("لا توجد عروض حتى الآن.", style: GoogleFonts.cairo(color: Colors.grey)))
              else
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Fetch real SP before navigating
                      final db = Provider.of<DatabaseService>(context, listen: false);
                      final auth = Provider.of<AuthService>(context, listen: false);
                      final userData = await db.getUserOnce(auth.currentUser!.uid);
                      final sp = userData?.wallet ?? 0;
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ApplicantsScreen(
                            request: widget.request,
                            requesterCurrentSP: sp,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.people_alt),
                    label: Text("عرض المتقدمين واختيار معلم", style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ] else if (alreadyApplied) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text("لقد قدمت عرضك بالفعل", style: GoogleFonts.cairo(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ] else ...[
              // Selection counter
              if (_selectedSlots.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    "اخترت ${_selectedSlots.length} وقت",
                    style: GoogleFonts.cairo(color: Colors.indigo, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: _isApplying
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _applyToRequest,
                        icon: const Icon(Icons.handshake),
                        label: Text(
                          "تقديم عرض مساعدة",
                          style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedSlots.isNotEmpty ? Colors.indigo : Colors.grey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}