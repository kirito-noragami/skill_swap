import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _topicController = TextEditingController();

  // ✅ Now stores ISO strings instead of free text
  List<String> _availableTimes = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  // ── Format ISO string to readable Arabic label ──────────────────────────
  String _formatSlot(String iso) {
    final dt = DateTime.parse(iso);
    const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    const months = ['', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'م' : 'ص';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday % 7]} ${dt.day} ${months[dt.month]}  $hour:$min $period';
  }

  // ── Date + Time picker (future only, max 7 days ahead) ──────────────────
  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 7));

    // Step 1: Pick date
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: maxDate,
      helpText: 'اختر اليوم',
      cancelText: 'إلغاء',
      confirmText: 'التالي',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.indigo),
        ),
        child: child!,
      ),
    );

    if (pickedDate == null || !mounted) return;

    // Step 2: Pick time
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      helpText: 'اختر الوقت',
      cancelText: 'إلغاء',
      confirmText: 'إضافة',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.indigo),
        ),
        child: child!,
      ),
    );

    if (pickedTime == null || !mounted) return;

    // Combine date + time
    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Must be strictly in the future
    if (combined.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يجب أن يكون الوقت في المستقبل"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _availableTimes.add(combined.toIso8601String()));
  }

  void _submitPost() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty ||
        _topicController.text.isEmpty || _availableTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى ملء جميع الحقول وإضافة وقت واحد على الأقل")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final db = Provider.of<DatabaseService>(context, listen: false);
      final userDoc = await db.getUserData(user!.uid).first;

      await db.createRequest(
        _titleController.text.trim(),
        _descController.text.trim(),
        _topicController.text.trim(),
        _availableTimes, // ISO strings
        userDoc,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم النشر بنجاح!")),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("طلب مساعدة جديد", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ───────────────────────────────────────────────────────
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "عنوان الطلب",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // ── Description ─────────────────────────────────────────────────
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "تفاصيل المشكلة...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // ── Topic ────────────────────────────────────────────────────────
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                labelText: "التقنية / المادة (مثال: Java, React, جبر)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // ── Time slots ───────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "الأوقات المناسبة لك:",
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  "خلال 7 أيام القادمة",
                  style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Add slot button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.add_circle_outline, color: Colors.indigo),
                label: Text(
                  "إضافة وقت",
                  style: GoogleFonts.cairo(color: Colors.indigo, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.indigo),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Chips showing selected slots
            if (_availableTimes.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTimes.map((iso) {
                  return Chip(
                    avatar: const Icon(Icons.access_time, size: 16, color: Colors.indigo),
                    label: Text(
                      _formatSlot(iso),
                      style: GoogleFonts.cairo(fontSize: 12),
                    ),
                    backgroundColor: Colors.indigo.shade50,
                    deleteIconColor: Colors.red,
                    onDeleted: () => setState(() => _availableTimes.remove(iso)),
                  );
                }).toList(),
              ),

            const SizedBox(height: 40),

            // ── Submit ───────────────────────────────────────────────────────
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _submitPost,
                      icon: const Icon(Icons.cloud_upload),
                      label: Text(
                        "نشر الطلب",
                        style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}