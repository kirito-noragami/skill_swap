import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago; // تأكد أنك أضفت المكتبة
import '../models/request_model.dart';

class PostCard extends StatelessWidget {
  final RequestModel request;
  final VoidCallback onTap;
  final VoidCallback onOfferHelp;

  const PostCard({
    super.key,
    required this.request,
    required this.onTap,
    required this.onOfferHelp,
  });

  @override
  Widget build(BuildContext context) {
    // تنسيق الوقت للعربية (مثلاً: منذ 5 دقائق)
    timeago.setLocaleMessages('ar', timeago.ArMessages());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. الرأس: الأيقونة واسم المادة والوقت
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.menu_book_rounded, color: Colors.indigo.shade800, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.category, // القسم (مثلاً: برمجة)
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade900,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          timeago.format(request.createdAt, locale: 'ar'), // منذ دقيقة
                          style: GoogleFonts.cairo(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // حالة الطلب (مفتوح/مغلق)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: request.status == 'OPEN' ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: request.status == 'OPEN' ? Colors.green.shade200 : Colors.red.shade200,
                        ),
                      ),
                      child: Text(
                        request.status == 'OPEN' ? 'مفتوح' : 'مغلق',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: request.status == 'OPEN' ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // 2. العنوان والتفاصيل
                Text(
                  request.title,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: request.tags.map((tag) {
                    return Chip(
                      label: Text(tag, style: GoogleFonts.cairo(fontSize: 12)),
                      backgroundColor: Colors.grey.shade100,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // 3. الفوتر: اسم الطالب وزر المساعدة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.person, size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          request.studentName,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: onOfferHelp,
                      icon: const Icon(Icons.handshake_outlined, size: 18),
                      label: Text("عرض المساعدة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}