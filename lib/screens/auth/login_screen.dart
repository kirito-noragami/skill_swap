import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import 'signup_screen.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPhoneLogin = false;

  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  String _completePhoneNumber = "";
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // ── Email login ────────────────────────────────────────────────────────────
  void _loginWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إدخال البريد وكلمة المرور")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final String? error = await AuthService().signIn(email, password);

    if (!mounted) return;

    if (error != null) {
      // Login failed → show error and stop spinner
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    // Login succeeded → verify Firestore profile, then navigate directly.
    // Same pattern as phone login — don't rely on AuthWrapper stream timing.
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) throw Exception("UID is null after login");

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!mounted) return;

      if (doc.exists) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        // Auth exists but no Firestore profile → sign out and inform user
        await AuthService().signOut();
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("لم يتم العثور على بيانات حسابك. يرجى إنشاء حساب."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // ── Phone login ────────────────────────────────────────────────────────────
  void _sendPhoneCode() async {
    if (_completePhoneNumber.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إدخال رقم صحيح")),
      );
      return;
    }

    setState(() => _isLoading = true);

    await AuthService().verifyPhoneNumber(
      _completePhoneNumber,
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showPhoneOTPDialog(verificationId);
      },
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل: ${e.message}"), backgroundColor: Colors.red),
        );
      },
    );
  }

  void _showPhoneOTPDialog(String verificationId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _PhoneOTPLoginDialog(
          phoneNumber: _completePhoneNumber,
          verificationId: verificationId,
          onVerified: (uid) async {
            // Close dialog
            Navigator.pop(dialogContext);
            if (!mounted) return;
            setState(() => _isLoading = true);

            // Check if this phone number has a Firestore profile
            try {
              final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
              if (!mounted) return;

              if (doc.exists) {
                // Profile found → navigate to Home directly
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              } else {
                // No profile → this phone number was never registered
                await AuthService().signOut();
                if (!mounted) return;
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("هذا الرقم غير مسجل! يرجى إنشاء حساب أولاً."),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            } catch (e) {
              if (!mounted) return;
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red),
              );
            }
          },
          onError: (msg) {
            Navigator.pop(dialogContext);
            if (!mounted) return;
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.red),
            );
          },
          onCancel: () => Navigator.pop(dialogContext),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1A237E);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Container(
              height: 300,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school_outlined, size: 80, color: Colors.white),
                  const SizedBox(height: 15),
                  Text("Skill Swap",
                      style: GoogleFonts.poppins(
                          fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text("مرحباً بك مجدداً",
                      style: GoogleFonts.cairo(fontSize: 16, color: Colors.white70)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Tab switcher ──────────────────────────────────────────
                  Row(
                    children: [
                      _buildTab("البريد الإلكتروني", !_isPhoneLogin, primaryColor,
                          () => setState(() => _isPhoneLogin = false)),
                      _buildTab("رقم الهاتف", _isPhoneLogin, primaryColor,
                          () => setState(() => _isPhoneLogin = true)),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // ── Fields ────────────────────────────────────────────────
                  if (!_isPhoneLogin) ...[
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "البريد الجامعي",
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "كلمة المرور",
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ] else ...[
                    IntlPhoneField(
                      decoration: InputDecoration(
                        labelText: 'رقم الهاتف',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      initialCountryCode: 'MA',
                      languageCode: "ar",
                      onChanged: (phone) => _completePhoneNumber = phone.completeNumber,
                    ),
                  ],

                  const SizedBox(height: 30),

                  // ── Submit button ─────────────────────────────────────────
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isPhoneLogin ? _sendPhoneCode : _loginWithEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              "تسجيل الدخول",
                              style: GoogleFonts.cairo(
                                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("ليس لديك حساب؟ ", style: GoogleFonts.cairo(color: Colors.grey)),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignUpScreen()),
                        ),
                        child: Text(
                          "أنشئ حساباً الآن",
                          style: GoogleFonts.cairo(color: primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, bool isActive, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold, color: isActive ? color : Colors.grey)),
            const SizedBox(height: 8),
            Container(height: 3, color: isActive ? color : Colors.transparent),
          ],
        ),
      ),
    );
  }
}

/// Standalone StatefulWidget for the phone OTP dialog.
/// Own state prevents stale-closure bugs and shows its own loading indicator.
class _PhoneOTPLoginDialog extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final Future<void> Function(String uid) onVerified;
  final void Function(String error) onError;
  final VoidCallback onCancel;

  const _PhoneOTPLoginDialog({
    required this.phoneNumber,
    required this.verificationId,
    required this.onVerified,
    required this.onError,
    required this.onCancel,
  });

  @override
  State<_PhoneOTPLoginDialog> createState() => _PhoneOTPLoginDialogState();
}

class _PhoneOTPLoginDialogState extends State<_PhoneOTPLoginDialog> {
  final _otpController = TextEditingController();
  bool _loading = false;

  Future<void> _verify() async {
    final code = _otpController.text.trim();
    if (code.length < 6) return;

    setState(() => _loading = true);

    final String? error = await AuthService().signInWithOTP(widget.verificationId, code);

    if (error != null) {
      widget.onError("الكود خاطئ: $error");
      return;
    }

    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      widget.onError("حدث خطأ غير متوقع، حاول مرة أخرى");
      return;
    }

    await widget.onVerified(uid);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        "أدخل كود التحقق",
        textAlign: TextAlign.center,
        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "تم الإرسال إلى ${widget.phoneNumber}",
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const CircularProgressIndicator()
          else
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                counterText: "",
                hintText: "------",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
      actions: [
        if (!_loading) ...[
          TextButton(
            onPressed: widget.onCancel,
            child: Text("إلغاء", style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: _verify,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E)),
            child: Text("تأكيد", style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ],
    );
  }
}