class UserModel {
  final String uid;
  final String email;
  final String name;
  final String major;        // التخصص (للملء التلقائي)
  final List<String> skills; // المهارات (Java, Math...)
  final int wallet;          // الرصيد الحالي (بالدقيقة)
  
  // إحصائيات InDrive
  final int totalMinutesHelped;
  final int ratingSum;       // مجموع النجوم
  final int ratingCount;     // عدد المقيمين

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.major,
    required this.skills,
    required this.wallet,
    this.totalMinutesHelped = 0,
    this.ratingSum = 0,
    this.ratingCount = 0,
  });

  // ---------------------------------------------------------
  // ✅ THE FIX: This makes 'coins' work in HomeScreen
  // ---------------------------------------------------------
  int get coins => wallet;

  // لتحويل البيانات القادمة من Firebase
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      major: map['major'] ?? 'General',
      skills: List<String>.from(map['skills'] ?? []),
      // Updated to read 'wallet' OR 'coins' (to be safe)
      wallet: map['wallet'] ?? map['coins'] ?? 10, 
      totalMinutesHelped: map['stats']?['totalMinutesHelped'] ?? map['totalMinutesHelped'] ?? 0,
      ratingSum: map['stats']?['ratingSum'] ?? map['ratingSum'] ?? 0,
      ratingCount: map['stats']?['ratingCount'] ?? map['ratingCount'] ?? 0,
    );
  }

  // للحفظ في Firebase
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'major': major,
      'skills': skills,
      'wallet': wallet, // Saved as wallet
      'coins': wallet,  // Saved as coins too (backup)
      'stats': {
        'totalMinutesHelped': totalMinutesHelped,
        'ratingSum': ratingSum,
        'ratingCount': ratingCount,
      },
    };
  }

  // لحساب التقييم (مثلاً 4.5)
  double get rating {
    if (ratingCount == 0) return 0.0;
    return ratingSum / ratingCount;
  }
}