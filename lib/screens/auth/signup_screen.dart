import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pinput/pinput.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _nameController = TextEditingController();
  String _completePhoneNumber = "";
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _processSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || _completePhoneNumber.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى ملء جميع الحقول")),
      );
      return;
    }

    setState(() => _isLoading = true);

    await AuthService().verifyPhoneNumber(
      _completePhoneNumber,
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showOTPDialog(verificationId);
      },
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل الإرسال: ${e.message}"), backgroundColor: Colors.red),
        );
      },
    );
  }

  void _showOTPDialog(String verificationId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _OTPDialog(
          phoneNumber: _completePhoneNumber,
          verificationId: verificationId,
          onSuccess: (pin) async {
            // Close the dialog
            Navigator.pop(dialogContext);

            if (!mounted) return;
            setState(() => _isLoading = true);

            try {
              // Step 1: Sign in with phone
              final phoneCred = PhoneAuthProvider.credential(
                verificationId: verificationId,
                smsCode: pin,
              );
              final userCred = await FirebaseAuth.instance.signInWithCredential(phoneCred);
              final uid = userCred.user!.uid;

              // Step 2: Link email+password to the same UID
              // If this fails (already linked or email exists), we continue anyway
              try {
                final emailCred = EmailAuthProvider.credential(
                  email: _emailController.text.trim(),
                  password: _passController.text.trim(),
                );
                await userCred.user!.linkWithCredential(emailCred);
              } catch (linkError) {
                debugPrint("Email link skipped: $linkError");
              }

              // Step 3: Save Firestore profile
              await FirebaseFirestore.instance.collection('users').doc(uid).set({
                'uid': uid,
                'email': _emailController.text.trim(),
                'name': _nameController.text.trim(),
                'phone': _completePhoneNumber,
                'major': 'General',
                'skills': [],
                'wallet': 10,
                'coins': 10,
                'role': 'student',
                'stats': {
                  'totalMinutesHelped': 0,
                  'ratingSum': 0,
                  'ratingCount': 0,
                },
                'createdAt': FieldValue.serverTimestamp(),
              });

              // Step 4: Navigate DIRECTLY to HomeScreen.
              // Do NOT rely on popUntil + AuthWrapper stream — there's a race
              // condition where the stream hasn't fired yet and LoginScreen shows.
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              }
            } catch (e) {
              debugPrint("Signup error: $e");
              if (mounted) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red),
                );
              }
            }
          },
          onCancel: () => Navigator.pop(dialogContext),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "حساب جديد",
          style: GoogleFonts.cairo(color: Colors.indigo, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.indigo),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildTextField("الاسم الكامل", Icons.person_outline, _nameController),
            const SizedBox(height: 20),
            _buildTextField("البريد الإلكتروني", Icons.email_outlined, _emailController),
            const SizedBox(height: 20),
            IntlPhoneField(
              decoration: InputDecoration(
                labelText: 'رقم الهاتف',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              initialCountryCode: 'MA',
              languageCode: "ar",
              onChanged: (phone) => _completePhoneNumber = phone.completeNumber,
            ),
            const SizedBox(height: 10),
            _buildTextField("كلمة المرور", Icons.lock_outline, _passController, isPassword: true),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _processSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        "إنشاء الحساب",
                        style: GoogleFonts.cairo(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller,
      {bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(),
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Extracted as a StatefulWidget so it has its own state for the loading indicator.
/// This avoids the parent's setState not rebuilding the dialog content.
class _OTPDialog extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final Future<void> Function(String pin) onSuccess;
  final VoidCallback onCancel;

  const _OTPDialog({
    required this.phoneNumber,
    required this.verificationId,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<_OTPDialog> createState() => _OTPDialogState();
}

class _OTPDialogState extends State<_OTPDialog> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        "تحقق من رقم هاتفك",
        textAlign: TextAlign.center,
        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "أرسلنا كود إلى ${widget.phoneNumber}",
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const CircularProgressIndicator()
          else
            Pinput(
              length: 6,
              onCompleted: (pin) async {
                setState(() => _loading = true);
                await widget.onSuccess(pin);
              },
            ),
        ],
      ),
      actions: [
        if (!_loading)
          TextButton(
            onPressed: widget.onCancel,
            child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.red)),
          ),
      ],
    );
  }
}