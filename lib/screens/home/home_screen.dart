import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../widgets/post_card.dart';
import 'add_post_screen.dart'; // سننشئها لاحقاً
import '../auth/login_screen.dart';
import 'request_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      
      // الزر العائم لإضافة طلب جديد
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // الانتقال لشاشة الإضافة (سنضيفها الخطوة القادمة)
           Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPostScreen()));
        },
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text("طلب مساعدة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
      ),

      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 120,
              floating: true,
              pinned: true,
              backgroundColor: Colors.indigo,
              elevation: 0,
              title: Text("SkillSwap", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                     authService.signOut();
                     Navigator.of(context).pushAndRemoveUntil(
                       MaterialPageRoute(builder: (_) => const LoginScreen()),
                       (route) => false,
                     );
                  },
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                tabs: const [
                  Tab(text: "لك (For You)"),
                  Tab(text: "استكشف (Explore)"),
                ],
              ),
            ),
          ];
        },
        body: StreamBuilder<UserModel>(
          stream: dbService.getUserData(user!.uid),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());

            final mySkills = userSnapshot.data!.skills;

            return TabBarView(
              controller: _tabController,
              children: [
                // التبويب 1: الخوارزمية (طلبات تناسب مهاراتي)
                _buildRequestList(dbService, filterSkills: mySkills),

                // التبويب 2: استكشف (كل الطلبات)
                _buildRequestList(dbService, filterSkills: null),
              ],
            );
          },
        ),
      ),
    );
  }

  // دالة بناء القائمة لتجنب تكرار الكود
  Widget _buildRequestList(DatabaseService db, {List<String>? filterSkills}) {
    return StreamBuilder<List<RequestModel>>(
      stream: db.getMyFeed(filterSkills ?? []), // الدالة التي كتبناها في DatabaseService
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        // تصفية إضافية في الواجهة (لضمان الدقة)
        var requests = snapshot.data!;
        if (filterSkills != null) {
          requests = requests.where((req) {
            // هل أي من وسوم الطلب موجودة في مهاراتي؟
            return req.tags.any((tag) => filterSkills.contains(tag));
          }).toList();
        }

        if (requests.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.only(top: 10, bottom: 80),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            return PostCard(
              request: req,
              onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RequestDetailsScreen(request: req),
    ),
  );
},
              onOfferHelp: () {
                // منطق InDrive: تقديم عرض مساعدة
                final user = Provider.of<AuthService>(context, listen: false).currentUser;
                Provider.of<DatabaseService>(context, listen: false)
                    .applyToRequest(req.id, user!.uid);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("تم إرسال عرضك للمساعدة بـ ${req.title}")),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text(
            "لا توجد طلبات حالياً",
            style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}