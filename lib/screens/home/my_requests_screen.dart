import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/request_model.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final db = Provider.of<DatabaseService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text("طلباتي", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: StreamBuilder<List<RequestModel>>(
        stream: db.getMyRequests(user!.uid), // استخدام الدالة الجديدة
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text("لم تقم بطلب أي مساعدة بعد", style: GoogleFonts.cairo(color: Colors.grey)),
            );
          }

          final requests = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(req.title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: req.status == 'OPEN' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              req.status == 'OPEN' ? "مفتوح" : "قيد التنفيذ",
                              style: GoogleFonts.cairo(
                                color: req.status == 'OPEN' ? Colors.green : Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("عدد المتقدمين: ${req.applicants.length}", style: GoogleFonts.cairo(color: Colors.grey[600])),
                      const Divider(),
                      if (req.applicants.isNotEmpty)
                        Text("انقر للتفاصيل واختيار معلم", style: GoogleFonts.cairo(color: Colors.indigo, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}