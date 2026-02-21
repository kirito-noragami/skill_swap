import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../widgets/post_card.dart';
import 'add_post_screen.dart';
import '../auth/login_screen.dart';
import 'request_details_screen.dart';
import 'my_requests_screen.dart';
import 'my_sessions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // ✅ متغير لتخزين كلمة البحث
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final user = authService.currentUser;

    return StreamBuilder<UserModel>(
      stream: dbService.getUserData(user!.uid),
      builder: (context, userSnapshot) {
        String name = "Loading...";
        String email = user.email ?? "";
        int coins = 0;

        if (userSnapshot.hasData) {
          final userData = userSnapshot.data!;
          name = userData.name;
          email = userData.email;
          coins = userData.coins;
        }

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFFF5F6FA),
          
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(decoration: const BoxDecoration(color: Colors.indigo), accountName: Text(name, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)), accountEmail: Text(email, style: GoogleFonts.cairo()), currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 40, color: Colors.indigo))),
                ListTile(leading: const Icon(Icons.list_alt, color: Colors.indigo), title: Text("طلباتي الخاصة", style: GoogleFonts.cairo()), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRequestsScreen())); }),
                ListTile(leading: const Icon(Icons.video_call_outlined, color: Colors.indigo), title: Text("جلساتي", style: GoogleFonts.cairo()), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const MySessionsScreen())); }),
                ListTile(leading: const Icon(Icons.monetization_on_outlined, color: Colors.amber), title: Text("رصيد النقاط: $coins SP", style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
                const Divider(),
                ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: Text("تسجيل الخروج", style: GoogleFonts.cairo(color: Colors.red)), onTap: () { authService.signOut(); Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false); }),
              ],
            ),
          ),

          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPostScreen())),
            backgroundColor: Colors.indigo,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text("طلب مساعدة", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
          ),

          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 140, // مساحة إضافية لشريط البحث
                  floating: true,
                  pinned: true,
                  backgroundColor: Colors.indigo,
                  elevation: 0,
                  title: Text("SkillSwap", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  actions: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber.withOpacity(0.5))),
                      child: Row(children: [const Icon(Icons.monetization_on, color: Colors.amber, size: 20), const SizedBox(width: 8), Text("$coins SP", style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14))]),
                    ),
                  ],
                  // ✅ شريط البحث السحري
                  flexibleSpace: FlexibleSpaceBar(
                    background: Padding(
                      padding: const EdgeInsets.only(top: 90, left: 16, right: 16),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                        decoration: InputDecoration(
                          hintText: "ابحث عن جافا، فلاتر، تصميم...",
                          hintStyle: GoogleFonts.cairo(color: Colors.grey),
                          prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            },
            
            // ✅ Feed واحد يحتوي على الفلتر المحلي
            body: StreamBuilder<List<RequestModel>>(
              stream: dbService.getMyFeed([], user.uid), 
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty) return _buildEmptyState();

                var requests = snapshot.data!;
                
                // ✅ فلتر البحث الفوري (يبحث في العنوان والمادة والوصف)
                if (_searchQuery.isNotEmpty) {
                  requests = requests.where((req) {
                    return req.title.toLowerCase().contains(_searchQuery) ||
                           req.category.toLowerCase().contains(_searchQuery) ||
                           req.description.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (requests.isEmpty) {
                  return Center(child: Text("لا توجد نتائج مطابقة لبحثك", style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 10, bottom: 80),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return PostCard(
                      request: req,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailsScreen(request: req))),
                      onOfferHelp: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailsScreen(request: req))),
                    );
                  },
                );
              },
            ),
          ),
        );
      }
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text("لا توجد طلبات متاحة حالياً", style: GoogleFonts.cairo(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}