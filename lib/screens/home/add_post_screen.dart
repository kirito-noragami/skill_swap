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
  final _descController = TextEditingController(); // يمكن إضافته للمودل لاحقاً
  
  // قائمة المواد/الأقسام
  final List<String> _categories = ['برمجة (Java)', 'خوارزميات', 'رياضيات', 'لغات', 'تصميم'];
  String _selectedCategory = 'برمجة (Java)';
  bool _isLoading = false;

  void _submitPost() async {
    if (_titleController.text.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final db = Provider.of<DatabaseService>(context, listen: false);
      
      // نحتاج لجلب بيانات المستخدم الكاملة (مثل الاسم) لإضافتها للطلب
      // هنا سنفترض أننا نملك البيانات أو نجلبها بسرعة (للتبسيط سنستخدم الاسم من الذاكرة أو الايميل)
      // الأفضل: جلب المودل كاملاً. للسرعة الآن:
      
      // ملاحظة: في التطبيق الحقيقي يجب جلب الـ UserModel أولاً
      // سنقوم بجلب بيانات المستخدم الحالية بسرعة
      final userDoc = await db.getUserData(user!.uid).first;

      await db.createRequest(_titleController.text, _selectedCategory, userDoc);

      if (mounted) {
        Navigator.pop(context); // إغلاق الشاشة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم نشر طلبك بنجاح! انتظر العروض 🚀")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
      }
    }
    setState(() => _isLoading = false);
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
            Text("ما الذي تحتاج مساعدة فيه؟", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // العنوان
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "عنوان الطلب (مثلاً: شرح Loop)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 20),

            // القسم
            Text("المادة / التخصص", style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.cairo()))).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val!),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // زر النشر
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _submitPost,
                      icon: const Icon(Icons.cloud_upload),
                      label: Text("نشر الطلب", style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}