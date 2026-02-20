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
  final _topicController = TextEditingController(); // ✅ حقل الموضوع/التقنية
  
  final _timeController = TextEditingController();
  List<String> _availableTimes = [];
  bool _isLoading = false;

  void _addTime() {
    if (_timeController.text.trim().isNotEmpty) {
      setState(() {
        _availableTimes.add(_timeController.text.trim());
        _timeController.clear();
      });
    }
  }

  void _submitPost() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty || _topicController.text.isEmpty || _availableTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى ملء جميع الحقول وإضافة وقت واحد على الأقل")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final db = Provider.of<DatabaseService>(context, listen: false);
      final userDoc = await db.getUserData(user!.uid).first;

      // نرسل الـ Topic بدلاً من الـ Category
      await db.createRequest(_titleController.text.trim(), _descController.text.trim(), _topicController.text.trim(), _availableTimes, userDoc);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم النشر بنجاح!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("طلب مساعدة جديد", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _titleController, decoration: InputDecoration(labelText: "عنوان الطلب", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 20),
            TextField(controller: _descController, maxLines: 3, decoration: InputDecoration(labelText: "تفاصيل المشكلة...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 20),
            
            // ✅ حقل التقنية (بدون قوائم مزعجة)
            TextField(controller: _topicController, decoration: InputDecoration(labelText: "التقنية / المادة (مثال: Java, React, جبر)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 20),

            Text("الأوقات المناسبة لك:", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: _timeController, decoration: InputDecoration(hintText: "مثال: الجمعة مساءً", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                const SizedBox(width: 10),
                IconButton(icon: const Icon(Icons.add_circle, color: Colors.indigo, size: 40), onPressed: _addTime)
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _availableTimes.map((time) => Chip(label: Text(time), onDeleted: () => setState(() => _availableTimes.remove(time)), deleteIconColor: Colors.red)).toList(),
            ),
            
            const SizedBox(height: 40),
            _isLoading ? const Center(child: CircularProgressIndicator()) : SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: _submitPost, icon: const Icon(Icons.cloud_upload),
                label: Text("نشر الطلب", style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}