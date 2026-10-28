import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HedefOdasiSayfasi extends StatefulWidget {
  final bool isDarkMode;
  final User? user;
  final String kullaniciAdi;
  final String? profilResimBase64;
  final bool isPremium;
  final VoidCallback onLogin;
  final VoidCallback onPremium;

  const HedefOdasiSayfasi({
    super.key,
    required this.isDarkMode,
    required this.user,
    required this.kullaniciAdi,
    required this.profilResimBase64,
    required this.isPremium,
    required this.onLogin,
    required this.onPremium,
  });

  @override
  State<HedefOdasiSayfasi> createState() => _HedefOdasiSayfasiState();
}

class _HedefOdasiSayfasiState extends State<HedefOdasiSayfasi>
    with WidgetsBindingObserver {
  static const _collection = 'target_rooms';
  static const _subjects = [
    'Matematik',
    'Fizik',
    'Kimya',
    'Biyoloji',
    'Türkçe',
    'Geometri',
    'Tarih',
    'Coğrafya',
    'Edebiyat',
  ];

  Timer? _clock;
  DateTime _now = DateTime.now();
  String? _myTable;
  int? _mySeat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    if (widget.user != null) {
      _prepareTables();
      _findMySeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    if (_myTable != null && _mySeat != null) {
      unawaited(_leave(tableId: _myTable, seatIndex: _mySeat));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_myTable != null && _mySeat != null) {
        unawaited(_leave(tableId: _myTable, seatIndex: _mySeat));
      }
    }
  }

  Future<void> _prepareTables() async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    bool needsCommit = false;
    for (var no = 1; no <= 8; no++) {
      final ref = firestore.collection(_collection).doc('masa_$no');
      final snap = await ref.get();
      if (!snap.exists) {
        batch.set(ref, {
          'masaNo': no,
          'isOccupied': false,
          'occupiedBy': null,
          'seats': [<String, dynamic>{}, <String, dynamic>{}],
        });
        needsCommit = true;
      } else {
        final data = snap.data();
        if (data != null && data['seats'] == null) {
          final List<Map<String, dynamic>> seats = [
            <String, dynamic>{},
            <String, dynamic>{},
          ];
          if (data['occupiedBy'] != null) {
            seats[0] = {
              'occupiedBy': data['occupiedBy'],
              'userName': data['userName'],
              'subject': data['subject'],
              'avatarBase64': data['avatarBase64'],
              'photoUrl': data['photoUrl'],
              'startedAt': data['startedAt'],
            };
          }
          batch.set(ref, {'seats': seats}, SetOptions(merge: true));
          needsCommit = true;
        }
      }
    }
    if (needsCommit) await batch.commit();
  }

  Future<void> _findMySeat() async {
    final uid = widget.user?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance.collection(_collection).get();
    for (final doc in snap.docs) {
      final seats = _seats(doc.data());
      for (var i = 0; i < seats.length; i++) {
        if (seats[i]['occupiedBy'] == uid) {
          if (mounted)
            setState(() {
              _myTable = doc.id;
              _mySeat = i;
            });
          return;
        }
      }
    }
    if (mounted)
      setState(() {
        _myTable = null;
        _mySeat = null;
      });
  }

  static String? _safeString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int _safeInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime _safeStartedAt(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: false);
    }
    final text = value?.toString();
    if (text != null && text.isNotEmpty) {
      return DateTime.tryParse(text) ?? DateTime.now();
    }
    return DateTime.now();
  }

  List<Map<String, dynamic>> _seats(Map<String, dynamic> data) {
    final rawSeats = data['seats'];
    if (rawSeats is Iterable<Object?>) {
      final result = rawSeats.take(2).map<Map<String, dynamic>>((Object? seat) {
        if (seat is Map) {
          final safe = <String, dynamic>{};
          for (final entry in seat.entries) {
            final key = entry.key?.toString();
            if (key != null) safe[key] = entry.value;
          }
          final occupiedBy = _safeString(safe['occupiedBy']);
          if (occupiedBy == null) return <String, dynamic>{};
          return <String, dynamic>{
            'occupiedBy': occupiedBy,
            'userName': _safeString(safe['userName']) ?? 'Öğrenci',
            'subject': _safeString(safe['subject']) ?? 'Çalışıyor',
            'avatarBase64': _safeString(safe['avatarBase64']),
            'photoUrl': _safeString(safe['photoUrl']),
            'startedAt': safe['startedAt'],
          };
        }
        return <String, dynamic>{};
      }).toList();
      while (result.length < 2) result.add(<String, dynamic>{});
      return result;
    }

    final occupiedBy = _safeString(data['occupiedBy']);
    final legacy = occupiedBy == null
        ? <String, dynamic>{}
        : <String, dynamic>{
            'occupiedBy': occupiedBy,
            'userName': _safeString(data['userName']) ?? 'Öğrenci',
            'subject': _safeString(data['subject']) ?? 'Çalışıyor',
            'avatarBase64': _safeString(data['avatarBase64']),
            'photoUrl': _safeString(data['photoUrl']),
            'startedAt': data['startedAt'],
          };
    return [legacy, <String, dynamic>{}];
  }

  bool _occupied(Map<String, dynamic> seat) {
    return _safeString(seat['occupiedBy']) != null;
  }

  Future<void> _sit(String tableId, int seatIndex) async {
    if (seatIndex != 0 && seatIndex != 1) return;
    final safeTableId = _safeString(tableId);
    if (safeTableId == null) return;
    tableId = safeTableId;
    final uid = widget.user?.uid;
    if (uid == null) {
      widget.onLogin();
      return;
    }

    final subject = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF00F0FF).withOpacity(.25)),
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bugün hangi derse çalışacaksın?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _subjects
                        .map((subject) => ActionChip(
                              label: Text(subject),
                              labelStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                              backgroundColor:
                                  const Color(0xFF00F0FF).withOpacity(.12),
                              side: BorderSide(
                                  color:
                                      const Color(0xFF00F0FF).withOpacity(.35)),
                              onPressed: () =>
                                  Navigator.pop(sheetContext, subject),
                            ))
                        .toList()),
              ]),
        ),
      ),
    );
    if (subject == null) return;

    final firestore = FirebaseFirestore.instance;
    try {
      if (_myTable != null && _myTable != tableId) {
        await _clearChat(_myTable!);
      }
      final all = await firestore.collection(_collection).get();
      final batch = firestore.batch();
      for (final doc in all.docs) {
        final seats = _seats(doc.data());
        bool changed = false;
        for (var i = 0; i < seats.length; i++) {
          if (seats[i]['occupiedBy'] == uid) {
            seats[i] = <String, dynamic>{};
            changed = true;
          }
        }
        if (changed)
          batch.set(
              doc.reference,
              {
                'seats': seats,
                'isOccupied': seats.any((seat) => _occupied(seat)),
                'occupiedBy': seats.isNotEmpty && _occupied(seats[0])
                    ? seats[0]['occupiedBy']
                    : null,
              },
              SetOptions(merge: true));
      }
      await batch.commit();

      final ref = firestore.collection(_collection).doc(tableId);
      await firestore.runTransaction((transaction) async {
        final snap = await transaction.get(ref);
        final seats = _seats(snap.data() ?? {});
        while (seats.length < 2) seats.add(<String, dynamic>{});
        if (_occupied(seats[seatIndex]))
          throw Exception('Bu koltuk az önce doldu.');
        seats[seatIndex] = {
          'occupiedBy': uid,
          'userName': widget.kullaniciAdi,
          'subject': subject,
          'avatarBase64': widget.profilResimBase64,
          'photoUrl': widget.user?.photoURL,
          'startedAt': Timestamp.fromDate(DateTime.now()),
        };
        transaction.set(
            ref,
            {
              'masaNo': _safeInt(
                  snap.data()?['masaNo'], _safeInt(tableId.split('_').last, 1)),
              'seats': seats,
              'isOccupied': seats.any((seat) => _occupied(seat)),
              'occupiedBy': _occupied(seats.first)
                  ? seats.first['occupiedBy']
                  : (_occupied(seats[1]) ? seats[1]['occupiedBy'] : null),
              'userName': _occupied(seats.first)
                  ? seats.first['userName']
                  : (_occupied(seats[1]) ? seats[1]['userName'] : null),
              'subject': _occupied(seats.first)
                  ? seats.first['subject']
                  : (_occupied(seats[1]) ? seats[1]['subject'] : null),
              'avatarBase64': _occupied(seats.first)
                  ? seats.first['avatarBase64']
                  : (_occupied(seats[1]) ? seats[1]['avatarBase64'] : null),
              'photoUrl': _occupied(seats.first)
                  ? seats.first['photoUrl']
                  : (_occupied(seats[1]) ? seats[1]['photoUrl'] : null),
              'startedAt': _occupied(seats.first)
                  ? seats.first['startedAt']
                  : (_occupied(seats[1]) ? seats[1]['startedAt'] : null),
            },
            SetOptions(merge: true));
      });
      if (mounted)
        setState(() {
          _myTable = tableId;
          _mySeat = seatIndex;
        });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: const Color(0xFFFF334B),
      ));
    }
  }

  Future<void> _leave({String? tableId, int? seatIndex}) async {
    final uid = widget.user?.uid;
    final target = tableId ?? _myTable;
    final index = seatIndex ?? _mySeat;
    if (uid == null || target == null || index == null) return;

    await _clearChat(target);
    final ref = FirebaseFirestore.instance.collection(_collection).doc(target);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      final seats = _seats(snap.data() ?? {});
      while (seats.length < 2) seats.add(<String, dynamic>{});
      if (index < seats.length && seats[index]['occupiedBy'] == uid) {
        seats[index] = <String, dynamic>{};
      }
      transaction.set(
          ref,
          {
            'masaNo': _safeInt(
                snap.data()?['masaNo'], _safeInt(target.split('_').last, 1)),
            'seats': seats,
            'isOccupied': seats.any((seat) => _occupied(seat)),
            'occupiedBy':
                _occupied(seats.first) ? seats.first['occupiedBy'] : null,
            'userName': _occupied(seats.first) ? seats.first['userName'] : null,
            'subject': _occupied(seats.first) ? seats.first['subject'] : null,
            'avatarBase64':
                _occupied(seats.first) ? seats.first['avatarBase64'] : null,
            'photoUrl': _occupied(seats.first) ? seats.first['photoUrl'] : null,
            'startedAt':
                _occupied(seats.first) ? seats.first['startedAt'] : null,
          },
          SetOptions(merge: true));
    });
    if (mounted && target == _myTable) {
      setState(() {
        _myTable = null;
        _mySeat = null;
      });
    }
  }

  Future<void> _clearChat(String tableId) async {
    final messages = FirebaseFirestore.instance
        .collection(_collection)
        .doc(tableId)
        .collection('messages');
    final snapshot = await messages.limit(300).get();
    if (snapshot.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  void _openChat(String tableId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoomChatSheet(
        tableId: tableId,
        user: widget.user!,
        userName: widget.kullaniciAdi,
        onChatCleared: () => _clearChat(tableId),
      ),
    );
  }

  String _duration(Map<String, dynamic> seat) {
    final startedAt = _safeStartedAt(seat['startedAt']);
    final elapsedSeconds = _now.difference(startedAt).inSeconds;
    final seconds = elapsedSeconds.clamp(0, 24 * 60 * 60 * 365);
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  ImageProvider<Object>? _avatar(Map<String, dynamic> seat) {
    final value = seat['avatarBase64']?.toString();
    if (value != null && value.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(value));
      } catch (_) {}
    }
    final url = seat['photoUrl']?.toString();
    return url != null && url.isNotEmpty ? NetworkImage(url) : null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPremium) {
      return Scaffold(
          backgroundColor: const Color(0xFF030712),
          appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: const Text('Hedef Odası')),
          body: _premiumGate());
    }
    if (widget.user == null) {
      return Scaffold(
          backgroundColor: const Color(0xFF030712),
          appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: const Text('Hedef Odası')),
          body: Center(
              child: ElevatedButton(
                  onPressed: widget.onLogin, child: const Text('Giriş Yap'))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090D1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Hedef Odası',
            style: TextStyle(fontWeight: FontWeight.w800)),
        leadingWidth: 44,
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance.collection(_collection).snapshots(),
            builder: (context, snapshot) {
              var occupiedSeats = 0;
              for (final doc in snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                occupiedSeats += _seats(doc.data()).where(_occupied).length;
              }
              return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: _topCounter(Icons.groups_rounded,
                      '$occupiedSeats Çevrim içi', const Color(0xFFFF334B)));
            },
          ),
          if (_myTable != null)
            IconButton(
              tooltip: 'Masa Sohbeti',
              icon: const Icon(Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF00F0FF)),
              onPressed: () => _openChat(_myTable!),
            ),
          if (_myTable != null)
            TextButton(
                onPressed: () => _leave(),
                child: const Text('KALK',
                    style: TextStyle(
                        color: Color(0xFFFF334B),
                        fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(_collection)
            .orderBy('masaNo')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFC247)));
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            Future<void>.microtask(_prepareTables);
            return const SizedBox.shrink();
          }
          return LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 560
                    ? 2
                    : 2;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth >= 700 ? 32 : 10,
                    vertical: 12,
                  ),
                  child: GridView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio:
                            constraints.maxWidth < 560 ? .82 : .88),
                    itemCount: docs.length <= 8 ? docs.length : 8,
                    itemBuilder: (context, index) => _tableCard(docs[index]),
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _premiumGate() => Center(
      child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: const Color(0xFFFFD700).withOpacity(.5))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.workspace_premium_rounded,
                color: Color(0xFFFFD700), size: 56),
            const SizedBox(height: 12),
            const Text('YKS Hane Premium Alanı',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'Hedef Odası yalnızca Premium üyelerimize özel çalışma alanıdır.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 18),
            ElevatedButton.icon(
                onPressed: widget.onPremium,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Premium’u İncele'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black)),
          ])));

  Widget _topCounter(IconData icon, String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(.35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold))
      ]));

  Widget _tableCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final seats = _seats(data);
    while (seats.length < 2) seats.add(<String, dynamic>{});
    final tableId = _safeString(doc.id) ?? 'masa_1';
    final masaNo =
        _safeInt(data['masaNo'], _safeInt(tableId.split('_').last, 1));
    final anyOccupied = seats.any((seat) => _occupied(seat));
    final mine = seats.any((seat) => seat['occupiedBy'] == widget.user?.uid);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF171E4F), Color(0xFF101536)]),
        border: Border.all(
            color: mine ? const Color(0xFFFFC247) : const Color(0xFF252B57),
            width: mine ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.28),
              blurRadius: 14,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(children: [
        const SizedBox(height: 9),
        Text('MASA $masaNo',
            style: const TextStyle(
                color: Color(0xFFE9A83A),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
        const SizedBox(height: 5),
        _Lamp(on: anyOccupied),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
              children: List.generate(
                  2, (i) => Expanded(child: _seat(seats[i], i, doc.id)))),
        ),
        Container(
            height: 31,
            decoration: const BoxDecoration(
                color: Color(0xFF4A2E1B),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(13))),
            child: Center(
                child: Container(width: 64, height: 2, color: Colors.black26))),
      ]),
    );
  }

  Widget _seat(Map<String, dynamic> seat, int seatIndex, String tableId) {
    final occupied = _occupied(seat);
    if (!occupied) {
      return InkWell(
          onTap: () => _sit(tableId, seatIndex),
          borderRadius: BorderRadius.circular(12),
          child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.event_seat_rounded,
                size: 38, color: Color(0xFF303758)),
            const SizedBox(height: 5),
            TextButton(
                onPressed: () => _sit(tableId, seatIndex),
                style: TextButton.styleFrom(
                    minimumSize: const Size(58, 28),
                    padding: EdgeInsets.zero,
                    backgroundColor: const Color(0xFF00F0FF).withOpacity(.9),
                    foregroundColor: Colors.black),
                child: const Text('OTUR',
                    style:
                        TextStyle(fontSize: 10, fontWeight: FontWeight.w900))),
          ])));
    }

    final mine = seat['occupiedBy'] == widget.user?.uid;
    final image = _avatar(seat);
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: mine ? const Color(0xFF00F0FF) : Colors.white,
                  width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: (mine ? const Color(0xFF00F0FF) : Colors.white)
                        .withOpacity(.16),
                    blurRadius: 8)
              ]),
          child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF26324A),
              backgroundImage: image,
              child: image == null
                  ? const Icon(Icons.person, color: Colors.white70)
                  : null)),
      const SizedBox(height: 5),
      SizedBox(
          width: 92,
          child: Text((seat['userName'] ?? 'Öğrenci').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800))),
      const SizedBox(height: 2),
      SizedBox(
          width: 92,
          child: Text((seat['subject'] ?? 'Çalışıyor').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color:
                      mine ? const Color(0xFF00F0FF) : const Color(0xFFE9A83A),
                  fontSize: 9,
                  fontWeight: FontWeight.w600))),
      const SizedBox(height: 3),
      Text(_duration(seat),
          style: TextStyle(
              color: mine ? const Color(0xFF00F0FF) : const Color(0xFF9CA3AF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()])),
    ]));
  }
}

class _RoomChatSheet extends StatefulWidget {
  final String tableId;
  final User user;
  final String userName;
  final VoidCallback onChatCleared;

  const _RoomChatSheet({
    required this.tableId,
    required this.user,
    required this.userName,
    required this.onChatCleared,
  });

  @override
  State<_RoomChatSheet> createState() => _RoomChatSheetState();
}

class _RoomChatSheetState extends State<_RoomChatSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _messages =>
      FirebaseFirestore.instance
          .collection('target_rooms')
          .doc(widget.tableId)
          .collection('messages');

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await _messages.add({
      'senderId': widget.user.uid,
      'senderName': widget.userName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * .72,
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4))),
          ListTile(
            leading:
                const Icon(Icons.chat_bubble_rounded, color: Color(0xFF00F0FF)),
            title: const Text('Masa Sohbeti',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(
                '${widget.tableId.replaceAll('_', ' ').toUpperCase()} • Geçici sohbet',
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  _messages.orderBy('createdAt', descending: false).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF00F0FF)));
                final messages = snapshot.data!.docs;
                if (messages.isEmpty)
                  return const Center(
                      child: Text('Bu masa için henüz mesaj yok.',
                          style: TextStyle(color: Colors.grey)));
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    final mine = data['senderId'] == widget.user.uid;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .72),
                        decoration: BoxDecoration(
                          color: mine
                              ? const Color(0xFF00F0FF).withOpacity(.18)
                              : const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: mine
                                  ? const Color(0xFF00F0FF).withOpacity(.45)
                                  : Colors.white10),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((data['senderName'] ?? 'Öğrenci').toString(),
                                  style: TextStyle(
                                      color: mine
                                          ? const Color(0xFF00F0FF)
                                          : const Color(0xFFFFC247),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 3),
                              Text((data['text'] ?? '').toString(),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                            ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                12, 8, 12, 12 + MediaQuery.viewInsetsOf(context).bottom),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                          hintText: 'Masa arkadaşına mesaj...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF1F2937),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none)))),
              const SizedBox(width: 8),
              IconButton(
                  onPressed: _send,
                  style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF00F0FF),
                      foregroundColor: Colors.black),
                  icon: const Icon(Icons.send_rounded)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Lamp extends StatefulWidget {
  final bool on;
  const _Lamp({required this.on});
  @override
  State<_Lamp> createState() => _LampState();
}

class _LampState extends State<_Lamp> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    if (widget.on) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Lamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.on && !_controller.isAnimating)
      _controller.repeat(reverse: true);
    if (!widget.on && _controller.isAnimating) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final glow = widget.on ? .35 + _controller.value * .25 : 0.0;
        return Container(
            width: 54,
            height: 48,
            decoration: BoxDecoration(
                boxShadow: widget.on
                    ? [
                        BoxShadow(
                            color: const Color(0xFFFFC247).withOpacity(glow),
                            blurRadius: 18,
                            spreadRadius: 4)
                      ]
                    : null),
            child: Column(children: [
              Icon(Icons.lightbulb_rounded,
                  size: 29,
                  color: widget.on
                      ? const Color(0xFFFFC247)
                      : const Color(0xFF4B4F63)),
              const SizedBox(height: 1),
              Container(
                  width: 7,
                  height: 13,
                  decoration: BoxDecoration(
                      color: widget.on
                          ? const Color(0xFF8A5A22)
                          : const Color(0xFF30364F),
                      borderRadius: BorderRadius.circular(4))),
              Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                      color: widget.on
                          ? const Color(0xFF8A5A22)
                          : const Color(0xFF30364F),
                      borderRadius: BorderRadius.circular(4))),
            ]));
      });
}
