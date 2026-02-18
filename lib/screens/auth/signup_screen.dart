import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _nameController = TextEditingController();
  
  // القوائم
  final List<String> _majors = ['هندسة برمجيات', 'ذكاء اصطناعي', 'شبكات', 'رياضيات'];
  String _selectedMajor = 'هندسة برمجيات';
  
  bool _isLoading = false;

  void _signup() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    // المنطق الذكي: ملء المهارات تلقائياً
    List<String> initialSkills = [];
    if (_selectedMajor.contains('برمجيات')) initialSkills = ['Java', 'Flutter', 'UML'];
    if (_selectedMajor.contains('ذكاء')) initialSkills = ['Python', 'Machine Learning', 'Data'];
    if (_selectedMajor.contains('شبكات')) initialSkills = ['Cisco', 'Linux', 'Security'];

    String? error = await authService.signUp(
      email: _emailController.text.trim(),
      password: _passController.text.trim(),
      name: _nameController.text.trim(),
      major: _selectedMajor,
      skills: initialSkills,
    );

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    } else {
      if (mounted) Navigator.pop(context);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF1A237E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        title: Text(
          "حساب طالب جديد",
          style: GoogleFonts.cairo(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ابدأ رحلتك التعليمية",
              style: GoogleFonts.cairo(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              "املأ بياناتك وسيقوم النظام بتحديد مهاراتك تلقائياً",
              style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // حقل الاسم
            _buildTextField("الاسم الكامل", Icons.person_outline, _nameController),
            const SizedBox(height: 20),

            // حقل البريد
            _buildTextField("البريد الإلكتروني", Icons.email_outlined, _emailController),
            const SizedBox(height: 20),

            // حقل كلمة المرور
            _buildTextField("كلمة المرور", Icons.lock_outline, _passController, isPassword: true),
            const SizedBox(height: 20),

            // اختيار التخصص (Dropdown بتصميم مميز)
            Text("التخصص الدراسي", style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMajor,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                  items: _majors.map((m) => DropdownMenuItem(value: m, child: Text(m, style: GoogleFonts.cairo()))).toList(),
                  onChanged: (val) => setState(() => _selectedMajor = val.toString()),
                ),
              ),
            ),
            
            const SizedBox(height: 40),

            // زر التسجيل
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        "إنشاء الحساب",
                        style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لبناء الحقول بسرعة
  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(),
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}