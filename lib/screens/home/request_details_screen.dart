import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/request_model.dart';
import '../../services/auth_service.dart';

class RequestDetailsScreen extends StatelessWidget {
  final RequestModel request;

  const RequestDetailsScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    final bool isMyRequest = currentUser?.uid == request.studentId;

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
            // بطاقة المعلومات
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.title, style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 5),
                      Text("الطالب: ${request.studentName}", style: GoogleFonts.cairo(color: Colors.grey[700])),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text("الوصف:", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(request.description, style: GoogleFonts.cairo(fontSize: 15, height: 1.5)),
                  
                  const SizedBox(height: 20),
                  Text("الأوقات المناسبة:", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: request.availableTimes.map((time) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withOpacity(0.5))),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.green),
                          const SizedBox(width: 5),
                          Text(time, style: GoogleFonts.cairo(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )).toList(),
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),

            // عرض الأزرار حسب صاحب الطلب
            if (isMyRequest) ...[
              Text("المتقدمون للمساعدة:", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (request.applicants.isEmpty)
                Center(child: Text("لا توجد عروض حتى الآن.", style: GoogleFonts.cairo(color: Colors.grey)))
              else
                // هنا مستقبلاً ستصنع قائمة تعرض أسماء المتقدمين وأزرار لاختيارهم
                Center(child: Text("لديك ${request.applicants.length} عرض!", style: GoogleFonts.cairo(color: Colors.green, fontWeight: FontWeight.bold)))
            ] else ...[
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // تقديم المساعدة
                  },
                  icon: const Icon(Icons.handshake),
                  label: Text("تقديم عرض مساعدة", style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}