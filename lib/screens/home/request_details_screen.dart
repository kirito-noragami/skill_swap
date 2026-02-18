import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/request_model.dart';
import '../../services/database_service.dart';
// import '../chat/chat_screen.dart'; // سننشئها لاحقاً

class RequestDetailsScreen extends StatelessWidget {
  final RequestModel request;

  const RequestDetailsScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: Text("تفاصيل الطلب", style: GoogleFonts.cairo())),
      body: Column(
        children: [
          // تفاصيل الطلب
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.title, style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Chip(label: Text(request.category), backgroundColor: Colors.indigo.shade50),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text("المتقدمون للمساعدة (InDrive List)", style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          
          // قائمة المتقدمين
          Expanded(
            child: request.applicants.isEmpty
            ? Center(child: Text("لا يوجد عروض حتى الآن", style: GoogleFonts.cairo()))
            : ListView.builder(
                itemCount: request.applicants.length,
                itemBuilder: (context, index) {
                  final tutorId = request.applicants[index];
                  // هنا نحتاج لجلب بيانات المعلم (الاسم والتقييم)
                  // للسهولة الآن سنعرض الـ ID، وفي التطوير القادم سنجلب الاسم
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(tutorId).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const ListTile(title: Text("جاري التحميل..."));
                      
                      final tutorData = snapshot.data!.data() as Map<String, dynamic>;
                      final stats = tutorData['stats'] ?? {};
                      final rating = stats['ratingSum'] ?? 0; // تبسيط للعرض

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(tutorData['name'] ?? 'معلم', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                          subtitle: Text("⭐ تقييم: $rating | 🕒 ساعد: ${stats['totalMinutesHelped']} دقيقة"),
                          trailing: ElevatedButton(
                            onPressed: () {
                              // قبول المعلم
                              db.selectTutor(request.id, tutorId);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم قبول المعلم! سيتم فتح الشات...")));
                              // Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(...)));
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            child: const Text("قبول"),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ),
        ],
      ),
    );
  }
}