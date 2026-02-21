import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/session_model.dart';
import '../../models/chat_message_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class ChatScreen extends StatefulWidget {
  final SessionModel session;
  final bool isRequester;

  const ChatScreen({super.key, required this.session, required this.isRequester});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _secondTimer;
  Timer? _unlockTimer;

  // ── State ─────────────────────────────────────────────────────────────────
  int _elapsedSeconds = 0;
  int _elapsedMinutes = 0;
  int _currentSP = 0;
  int _helperMessageCount = 0;
  bool _sessionActive = false;
  bool _isEnding = false;
  bool _chatUnlocked = false;
  int _secondsUntilUnlock = 0;

  StreamSubscription<dynamic>? _spStream;
  StreamSubscription<dynamic>? _msgStream;

  @override
  void initState() {
    super.initState();
    _currentSP = widget.session.requesterStartSP;
    _checkUnlock();
  }

  // ── Check if chat is unlocked (T-5 before session) ────────────────────────
  void _checkUnlock() {
    final now = DateTime.now();
    final unlock = widget.session.unlockTime;

    if (now.isAfter(unlock)) {
      setState(() => _chatUnlocked = true);
      _onUnlocked();
    } else {
      setState(() => _secondsUntilUnlock = unlock.difference(now).inSeconds);
      _unlockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        final remaining = widget.session.unlockTime.difference(DateTime.now()).inSeconds;
        if (remaining <= 0) {
          t.cancel();
          setState(() { _chatUnlocked = true; _secondsUntilUnlock = 0; });
          _onUnlocked();
        } else {
          setState(() => _secondsUntilUnlock = remaining);
        }
      });
    }
  }

  void _onUnlocked() {
    // Listen to requester's SP in real time
    final db = Provider.of<DatabaseService>(context, listen: false);
    _spStream = db.getUserData(widget.session.requesterId).listen((user) {
      if (mounted) setState(() => _currentSP = user.wallet);
    });

    // Only requester starts the session timer
    if (widget.isRequester) _startTimer();
  }

  // ── Session timer (runs only for requester) ────────────────────────────────
  void _startTimer() {
    if (_sessionActive) return;
    _sessionActive = true;

    // Mark session active in Firestore
    final db = Provider.of<DatabaseService>(context, listen: false);
    db.activateSession(widget.session.id);

    _secondTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _elapsedSeconds++;
        _elapsedMinutes = _elapsedSeconds ~/ 60;
      });

      // Check SP every 60 seconds
      if (_elapsedSeconds % 60 == 0) {
        if (_currentSP <= 0) {
          _endSession(reason: 'no_points');
        }
      }
    });
  }

  // ── End session ────────────────────────────────────────────────────────────
  Future<void> _endSession({String reason = 'manual'}) async {
    if (_isEnding) return;
    setState(() => _isEnding = true);

    _secondTimer?.cancel();
    _unlockTimer?.cancel();
    _spStream?.cancel();
    _msgStream?.cancel();

    // Anti-fraud: <0.5 helper messages per minute = fraud
    final fraudDetected = _elapsedMinutes >= 2 &&
        _helperMessageCount / _elapsedMinutes < 0.5;

    final db = Provider.of<DatabaseService>(context, listen: false);
    await db.finalizeSession(
      sessionId: widget.session.id,
      requesterId: widget.session.requesterId,
      helperId: widget.session.helperId,
      minutesCompleted: _elapsedMinutes,
      fraudDetected: fraudDetected,
    );

    if (!mounted) return;
    _showSummary(reason, fraudDetected);
  }

  void _showSummary(String reason, bool fraudDetected) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            reason == 'no_points' ? '⏱️ انتهى الرصيد' : '✅ انتهت الجلسة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reason == 'no_points')
                Text("نفد رصيدك، تم إنهاء الجلسة تلقائياً.",
                    style: GoogleFonts.cairo(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  _row("⏱️ مدة الجلسة", "$_elapsedMinutes دقيقة"),
                  _row("💰 SP مُحوَّل", "$_elapsedMinutes SP"),
                  if (fraudDetected)
                    _row("⚠️ تنبيه", "نشاط منخفض — لا تحويل", color: Colors.red),
                ]),
              ),
              if (widget.isRequester && !fraudDetected && _elapsedMinutes > 0) ...[
                const SizedBox(height: 16),
                Text("كيف تقيّم الجلسة؟",
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _RatingRow(
                  onRated: (stars) async {
                    final db = Provider.of<DatabaseService>(context, listen: false);
                    await db.rateHelper(widget.session.helperId, stars);
                  },
                ),
              ],
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  Navigator.of(dialogCtx).pop(); // close dialog
                  // Pop back to home — remove ALL routes on top of the first
                  Navigator.of(context)
                      .popUntil((route) => route.isFirst);
                },
                child: Text("العودة للرئيسية",
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.cairo(fontSize: 13)),
          Text(value,
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  // ── Send message ──────────────────────────────────────────────────────────
  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _isEnding) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);
    _msgController.clear();

    final msg = ChatMessage(
      id: '',
      senderId: auth.currentUser!.uid,
      senderName: widget.isRequester
          ? widget.session.requesterName
          : widget.session.helperName,
      text: text,
      timestamp: DateTime.now(),
    );

    await db.sendMessage(widget.session.id, msg);

    if (!widget.isRequester) _helperMessageCount++;

    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Leave confirmation (requester only) ───────────────────────────────────
  void _confirmLeave() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("إنهاء الجلسة؟", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        content: Text(
          "ستنتهي الجلسة وسيتم تحويل $_elapsedMinutes SP للمعلم.",
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("تراجع", style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx); // close dialog first
              _endSession(reason: 'manual');
            },
            child: Text("إنهاء", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String get _timer {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _unlockCountdown {
    final m = (_secondsUntilUnlock ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsUntilUnlock % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _secondTimer?.cancel();
    _unlockTimer?.cancel();
    _spStream?.cancel();
    _msgStream?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent accidental back swipe — requester must confirm, helper can leave freely
      canPop: !(widget.isRequester && _sessionActive && !_isEnding),
      onPopInvoked: (didPop) {
        if (!didPop && widget.isRequester && _sessionActive && !_isEnding) {
          _confirmLeave();
        }
      },
      child: _chatUnlocked ? _buildChat() : _buildLocked(),
    );
  }

  // ── Locked screen ──────────────────────────────────────────────────────────
  Widget _buildLocked() {
    final formatted = _formatSlot(widget.session.confirmedTime);

    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_clock, color: Colors.white, size: 80),
                const SizedBox(height: 24),
                Text("الغرفة ستُفتح خلال",
                    style: GoogleFonts.cairo(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 12),
                Text(_unlockCountdown,
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    Text("موعد الجلسة", style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(formatted,
                        style: GoogleFonts.cairo(
                            color: Colors.amber,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Text(
                      "مع ${widget.isRequester ? widget.session.helperName : widget.session.requesterName}",
                      style: GoogleFonts.cairo(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.session.requestTitle,
                        style: GoogleFonts.cairo(color: Colors.white60, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 32),
                Text(
                  "الغرفة تُفتح قبل الجلسة بـ 5 دقائق",
                  style: GoogleFonts.cairo(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Chat screen ────────────────────────────────────────────────────────────
  Widget _buildChat() {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final myUid = auth.currentUser!.uid;
    final spColor = _currentSP <= 3
        ? Colors.red
        : (_currentSP <= 10 ? Colors.orange : Colors.green);
    final startSP = widget.session.requesterStartSP;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF283593)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            if (widget.isRequester && _sessionActive && !_isEnding) {
                              _confirmLeave();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          child: Text(
                            (widget.isRequester
                                    ? widget.session.helperName
                                    : widget.session.requesterName)
                                .isNotEmpty
                                ? (widget.isRequester
                                    ? widget.session.helperName[0]
                                    : widget.session.requesterName[0])
                                : '?',
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isRequester
                                    ? widget.session.helperName
                                    : widget.session.requesterName,
                                style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                              Text(
                                widget.session.requestTitle,
                                style: GoogleFonts.cairo(
                                    color: Colors.white70, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Timer badge (only shows when session is active)
                        if (_sessionActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(_timer,
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                        const SizedBox(width: 6),
                        // End button — requester only
                        if (widget.isRequester && _sessionActive)
                          GestureDetector(
                            onTap: _confirmLeave,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text("إنهاء",
                                  style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),

                  // SP bar — requester only
                  if (widget.isRequester && _sessionActive)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Column(children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("رصيد الجلسة",
                                style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11)),
                            Text("$_currentSP SP",
                                style: GoogleFonts.cairo(
                                    color: spColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: startSP > 0
                                ? (_currentSP / startSP).clamp(0.0, 1.0)
                                : 0,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(spColor),
                            minHeight: 6,
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ),

          // ── Waiting banner for helper ──────────────────────────────────────
          if (!widget.isRequester && !_sessionActive)
            Container(
              width: double.infinity,
              color: Colors.amber.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "في انتظار الطالب لبدء الجلسة...",
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),

          // ── Low SP warning ────────────────────────────────────────────────
          if (widget.isRequester && _sessionActive && _currentSP <= 5 && _currentSP > 0)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "تحذير: تبقّى $_currentSP SP! الجلسة ستنتهي خلال $_currentSP دقيقة.",
                    style: GoogleFonts.cairo(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
            ),

          // ── Messages ──────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: db.getMessages(widget.session.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (!widget.isRequester) {
                  _helperMessageCount =
                      messages.where((m) => m.senderId == myUid).length;
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          widget.isRequester
                              ? "اشرح مشكلتك للمعلم 👇"
                              : "انتظر رسالة الطالب...",
                          style: GoogleFonts.cairo(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == myUid;
                    final showAvatar = i == 0 || messages[i - 1].senderId != msg.senderId;
                    return _bubble(msg, isMe, showAvatar);
                  },
                );
              },
            ),
          ),

          // ── Input bar ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            color: Colors.white,
            child: Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24)),
                  child: TextField(
                    controller: _msgController,
                    maxLines: 4,
                    minLines: 1,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: "اكتب رسالة...",
                      hintStyle: GoogleFonts.cairo(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage msg, bool isMe, bool showAvatar) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar)
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.indigo.shade100,
              child: Text(
                msg.senderName.isNotEmpty ? msg.senderName[0] : '?',
                style: GoogleFonts.cairo(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold),
              ),
            )
          else if (!isMe)
            const SizedBox(width: 28),
          if (!isMe) const SizedBox(width: 6),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                    : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(msg.text,
                      style: GoogleFonts.cairo(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 15,
                          height: 1.4),
                      textDirection: TextDirection.rtl),
                  const SizedBox(height: 2),
                  Text(_fmtTime(msg.timestamp),
                      style: GoogleFonts.cairo(
                          color: isMe ? Colors.white60 : Colors.grey, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final p = dt.hour >= 12 ? 'م' : 'ص';
    return '$h:${dt.minute.toString().padLeft(2, '0')} $p';
  }

  String _formatSlot(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
      const months = ['','يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final p = dt.hour >= 12 ? 'م' : 'ص';
      return '${days[dt.weekday % 7]} ${dt.day} ${months[dt.month]}  $h:${dt.minute.toString().padLeft(2, '0')} $p';
    } catch (_) { return iso; }
  }
}

// ── Star rating widget ─────────────────────────────────────────────────────────
class _RatingRow extends StatefulWidget {
  final Future<void> Function(int stars) onRated;
  const _RatingRow({required this.onRated});

  @override
  State<_RatingRow> createState() => _RatingRowState();
}

class _RatingRowState extends State<_RatingRow> {
  int _stars = 0;
  bool _rated = false;

  @override
  Widget build(BuildContext context) {
    if (_rated) {
      return Text("شكراً على تقييمك! ⭐",
          style: GoogleFonts.cairo(color: Colors.amber, fontWeight: FontWeight.bold));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        return GestureDetector(
          onTap: () async {
            setState(() { _stars = i + 1; _rated = true; });
            await widget.onRated(i + 1);
          },
          child: Icon(
            i < _stars ? Icons.star_rounded : Icons.star_border_rounded,
            color: Colors.amber,
            size: 36,
          ),
        );
      }),
    );
  }
}