import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const Color _cyan = Color(0xFF00F0FF);
const Color _gold = Color(0xFFFFD700);

class SiniflarSayfasi extends StatefulWidget {
  final User? user;
  final String kullaniciAdi;
  final String? profilResimBase64;
  final int roxCoin;
  final bool isDarkMode;
  final bool isAdmin;
  final VoidCallback onLogin;

  const SiniflarSayfasi({
    super.key,
    required this.user,
    required this.kullaniciAdi,
    required this.profilResimBase64,
    required this.roxCoin,
    required this.isDarkMode,
    required this.isAdmin,
    required this.onLogin,
  });

  @override
  State<SiniflarSayfasi> createState() => _SiniflarSayfasiState();
}

class _SiniflarSayfasiState extends State<SiniflarSayfasi> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _createClass() async {
    if (widget.user == null) {
      widget.onLogin();
      return;
    }
    final name = TextEditingController();
    final description = TextEditingController();
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Yeni Sınıf Oluştur',
            style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Sınıf adı')),
          const SizedBox(height: 8),
          TextField(
              controller: description,
              style: const TextStyle(color: Colors.white),
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Açıklama')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                    'name': name.text.trim(),
                    'description': description.text.trim()
                  }),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _gold, foregroundColor: Colors.black),
              child: const Text('100 RC ile Oluştur')),
        ],
      ),
    );
    if (result == null || (result['name'] ?? '').isEmpty) return;
    final uid = widget.user!.uid;
    final userRef =
        FirebaseFirestore.instance.collection('kullanicilar').doc(uid);
    final classes = FirebaseFirestore.instance.collection('siniflar');
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnap = await transaction.get(userRef);
        final data = userSnap.data() ?? <String, dynamic>{};
        final current =
            data['roxCoin'] is num ? (data['roxCoin'] as num).toInt() : 0;
        final existing = data['sinifId']?.toString();
        if (existing != null && existing.isNotEmpty)
          throw Exception(
              'Zaten bir sınıfa üyelik: önce sınıftan ayrılmalısın.');
        if (current < 100)
          throw Exception(
              'Yetersiz RoxCoin. Sınıf oluşturmak için 100 RC gerekiyor.');
        final newRef = classes.doc();
        transaction.update(userRef,
            {'roxCoin': FieldValue.increment(-100), 'sinifId': newRef.id});
        transaction.set(newRef, {
          'name': result['name'],
          'description': result['description'] ?? '',
          'photoBase64': null,
          'ownerId': uid,
          'ownerName': widget.kullaniciAdi,
          'memberIds': <String>[uid],
          'createdAt': Timestamp.now(),
          'status': 'active',
        });
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sınıf oluşturuldu! 100 RC kullanıldı.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF334B)));
    }
  }

  Future<void> _joinClass(String classId) async {
    if (widget.user == null) {
      widget.onLogin();
      return;
    }
    final uid = widget.user!.uid;
    final userRef =
        FirebaseFirestore.instance.collection('kullanicilar').doc(uid);
    final classRef =
        FirebaseFirestore.instance.collection('siniflar').doc(classId);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnap = await transaction.get(userRef);
        final existing = userSnap.data()?['sinifId']?.toString();
        if (existing != null && existing.isNotEmpty && existing != classId)
          throw Exception('Bir kullanıcı yalnızca bir sınıfa katılabilir.');
        final classSnap = await transaction.get(classRef);
        final members = classSnap.data()?['memberIds'];
        final ids = members is Iterable
            ? members.map((e) => e.toString()).toSet()
            : <String>{};
        ids.add(uid);
        transaction.update(classRef, {'memberIds': ids.toList()});
        transaction.update(userRef, {'sinifId': classId});
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF334B)));
    }
  }

  Future<void> _leaveClass(String classId) async {
    final uid = widget.user?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final classRef =
          FirebaseFirestore.instance.collection('siniflar').doc(classId);
      final classSnap = await transaction.get(classRef);
      final members = classSnap.data()?['memberIds'];
      final ids = members is Iterable
          ? members.map((e) => e.toString()).toList()
          : <String>[];
      ids.remove(uid);
      transaction.update(classRef, {'memberIds': ids});
      transaction.update(
          FirebaseFirestore.instance.collection('kullanicilar').doc(uid),
          {'sinifId': FieldValue.delete()});
    });
  }

  Future<void> _editClass(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final ownerId = data['ownerId']?.toString();
    if (!widget.isAdmin && ownerId != widget.user?.uid) return;
    final name = TextEditingController(text: data['name']?.toString() ?? '');
    final description =
        TextEditingController(text: data['description']?.toString() ?? '');
    String? photo = data['photoBase64']?.toString();
    await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, dialogSetState) => AlertDialog(
                  backgroundColor: const Color(0xFF111827),
                  title: const Text('Sınıfı Düzenle',
                      style: TextStyle(color: Colors.white)),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(
                        radius: 42,
                        backgroundColor: const Color(0xFF252E4A),
                        backgroundImage: photo?.isNotEmpty == true
                            ? MemoryImage(base64Decode(photo!))
                            : null,
                        child: photo?.isNotEmpty != true
                            ? const Icon(Icons.school, color: _gold, size: 40)
                            : null),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      TextButton.icon(
                          onPressed: () async {
                            final file = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 800,
                                imageQuality: 70);
                            if (file != null) {
                              final bytes = await file.readAsBytes();
                              dialogSetState(() => photo = base64Encode(bytes));
                            }
                          },
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Fotoğraf')),
                      if (photo != null && photo!.isNotEmpty)
                        TextButton(
                            onPressed: () => dialogSetState(() => photo = null),
                            child: const Text('Kaldır',
                                style: TextStyle(color: Color(0xFFFF334B))))
                    ]),
                    TextField(
                        controller: name,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            const InputDecoration(labelText: 'Sınıf adı')),
                    TextField(
                        controller: description,
                        style: const TextStyle(color: Colors.white),
                        maxLength: 160,
                        decoration:
                            const InputDecoration(labelText: 'Açıklama')),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('İptal')),
                    ElevatedButton(
                        onPressed: () async {
                          await doc.reference.set({
                            'name': name.text.trim(),
                            'description': description.text.trim(),
                            'photoBase64': photo
                          }, SetOptions(merge: true));
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Kaydet'))
                  ],
                )));
  }

  Future<void> _deleteClass(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final ownerId = doc.data()['ownerId']?.toString();
    if (!widget.isAdmin && ownerId != widget.user?.uid) return;
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF111827),
                title: const Text('Sınıf silinsin mi?',
                    style: TextStyle(color: Colors.white)),
                content: const Text(
                    'Bu işlem sınıfı ve üyelik verilerini kalıcı olarak kaldırır.',
                    style: TextStyle(color: Colors.grey)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('İptal')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sil',
                          style: TextStyle(color: Color(0xFFFF334B))))
                ]));
    if (ok != true) return;
    final members = doc.data()['memberIds'];
    final ids = members is Iterable
        ? members.map((e) => e.toString()).toList()
        : <String>[];
    final batch = FirebaseFirestore.instance.batch();
    for (final uid in ids)
      batch.update(
          FirebaseFirestore.instance.collection('kullanicilar').doc(uid),
          {'sinifId': FieldValue.delete()});
    batch.delete(doc.reference);
    await batch.commit();
  }

  ImageProvider<Object>? _classImage(Map<String, dynamic> data) {
    final photo = data['photoBase64']?.toString();
    if (photo?.isNotEmpty == true) return MemoryImage(base64Decode(photo!));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF090D1F)
            : const Color(0xFFF4F7FC),
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Sınıflar'),
            actions: [_coinBadge(widget.roxCoin), const SizedBox(width: 12)]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal:
                            MediaQuery.sizeOf(context).width >= 700 ? 24 : 12),
                    child: Column(children: [
                      TextField(
                          controller: _search,
                          onChanged: (v) =>
                              setState(() => _query = v.trim().toLowerCase()),
                          decoration: InputDecoration(
                              prefixIcon:
                                  const Icon(Icons.search, color: _cyan),
                              hintText: 'Sınıf ara...',
                              filled: true,
                              fillColor: widget.isDarkMode
                                  ? const Color(0xFF111827)
                                  : Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                      color: _cyan.withOpacity(.25))))),
                      const SizedBox(height: 10),
                      Expanded(
                          child: StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('siniflar')
                                  .orderBy('createdAt', descending: true)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return const Center(
                                      child: CircularProgressIndicator());
                                final docs = snapshot.data!.docs.where((d) {
                                  final name = d
                                          .data()['name']
                                          ?.toString()
                                          .toLowerCase() ??
                                      '';
                                  return name.contains(_query);
                                }).toList();
                                if (docs.isEmpty)
                                  return const Center(
                                      child: Text('Henüz sınıf bulunamadı.',
                                          style:
                                              TextStyle(color: Colors.grey)));
                                return ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 100),
                                    itemCount: docs.length,
                                    itemBuilder: (context, index) {
                                      final doc = docs[index];
                                      final data = doc.data();
                                      final members = data['memberIds'];
                                      final ids = members is Iterable
                                          ? members
                                              .map((e) => e.toString())
                                              .toList()
                                          : <String>[];
                                      final mine =
                                          ids.contains(widget.user?.uid);
                                      final owner = data['ownerId']?.toString();
                                      final canManage = widget.isAdmin ||
                                          owner == widget.user?.uid;
                                      return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
                                          decoration: BoxDecoration(
                                              color: widget.isDarkMode
                                                  ? const Color(0xFF111827)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                  color: mine
                                                      ? _gold.withOpacity(.7)
                                                      : _cyan
                                                          .withOpacity(.18))),
                                          child: ListTile(
                                              contentPadding:
                                                  const EdgeInsets.all(14),
                                              leading: CircleAvatar(
                                                  radius: 26,
                                                  backgroundColor:
                                                      const Color(0xFF252E4A),
                                                  backgroundImage:
                                                      _classImage(data),
                                                  child: _classImage(data) == null
                                                      ? Text(
                                                          (data['name']?.toString().isNotEmpty == true
                                                              ? data['name']
                                                                  .toString()[0]
                                                                  .toUpperCase()
                                                              : 'S'),
                                                          style: const TextStyle(
                                                              color: _gold,
                                                              fontWeight: FontWeight.bold))
                                                      : null),
                                              title: Text(data['name']?.toString() ?? 'İsimsiz Sınıf', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              subtitle: Text('${ids.length} Üye • ${data['description']?.toString().isNotEmpty == true ? data['description'] : (owner == widget.user?.uid ? 'Kurucu sensin' : 'YKS Hane Sınıfı')}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                                if (canManage)
                                                  PopupMenuButton<String>(
                                                      onSelected:
                                                          (value) async {
                                                        if (value == 'edit')
                                                          await _editClass(doc);
                                                        if (value == 'delete')
                                                          await _deleteClass(
                                                              doc);
                                                      },
                                                      itemBuilder: (_) =>
                                                          const [
                                                            PopupMenuItem(
                                                                value: 'edit',
                                                                child: Text(
                                                                    'Düzenle')),
                                                            PopupMenuItem(
                                                                value: 'delete',
                                                                child:
                                                                    Text('Sil'))
                                                          ]),
                                                if (mine)
                                                  TextButton(
                                                      onPressed: () => Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (_) => SinifOdasiSayfasi(
                                                                  classId:
                                                                      doc.id,
                                                                  className:
                                                                      data['name']?.toString() ??
                                                                          'Sınıf',
                                                                  user: widget
                                                                      .user,
                                                                  userName: widget
                                                                      .kullaniciAdi,
                                                                  profilResimBase64:
                                                                      widget
                                                                          .profilResimBase64,
                                                                  isDarkMode: widget
                                                                      .isDarkMode,
                                                                  isAdmin: widget
                                                                      .isAdmin))),
                                                      child: const Text(
                                                          'Sınıfa Gir'))
                                                else
                                                  TextButton(
                                                      onPressed: () =>
                                                          _joinClass(doc.id),
                                                      child: const Text('KATIL'))
                                              ])));
                                    });
                              }))
                    ])))));
  }
}

Widget _coinBadge(int roxCoin) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
        color: _gold.withOpacity(.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withOpacity(.55))),
    child: Text('🪙 $roxCoin RC',
        style: const TextStyle(
            color: _gold, fontSize: 11, fontWeight: FontWeight.w900)));

class SinifOdasiSayfasi extends StatefulWidget {
  final String classId, className;
  final User? user;
  final String userName;
  final String? profilResimBase64;
  final bool isDarkMode, isAdmin;
  const SinifOdasiSayfasi(
      {super.key,
      required this.classId,
      required this.className,
      required this.user,
      required this.userName,
      required this.profilResimBase64,
      required this.isDarkMode,
      required this.isAdmin});
  @override
  State<SinifOdasiSayfasi> createState() => _SinifOdasiSayfasiState();
}

class _SinifOdasiSayfasiState extends State<SinifOdasiSayfasi> {
  final TextEditingController _generalMessage = TextEditingController();
  Timer? _presenceTimer;

  CollectionReference<Map<String, dynamic>> get _generalMessages =>
      FirebaseFirestore.instance
          .collection('siniflar')
          .doc(widget.classId)
          .collection('messages');
  CollectionReference<Map<String, dynamic>> get _tables =>
      FirebaseFirestore.instance
          .collection('siniflar')
          .doc(widget.classId)
          .collection('tables');

  @override
  void initState() {
    super.initState();
    _prepareTables();
    _startPresence();
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _setPresence(false);
    _generalMessage.dispose();
    super.dispose();
  }

  Future<void> _prepareTables() async {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 1; i <= 8; i++) {
      final ref = _tables.doc('masa_$i');
      final snap = await ref.get();
      if (!snap.exists)
        batch.set(ref, {
          'masaNo': i,
          'seats': <Map<String, dynamic>>[
            <String, dynamic>{},
            <String, dynamic>{}
          ]
        });
    }
    await batch.commit();
  }

  Future<void> _startPresence() async {
    await _setPresence(true);
    _presenceTimer =
        Timer.periodic(const Duration(seconds: 45), (_) => _setPresence(true));
  }

  Future<void> _setPresence(bool online) async {
    final uid = widget.user?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('siniflar')
        .doc(widget.classId)
        .collection('presence')
        .doc(uid)
        .set({
      'online': online,
      'lastSeen': Timestamp.now(),
      'name': widget.userName
    }, SetOptions(merge: true));
  }

  Future<void> _sendGeneral() async {
    final text = _generalMessage.text.trim();
    if (text.isEmpty || widget.user == null) return;
    await _generalMessages.add({
      'senderId': widget.user!.uid,
      'senderName': widget.userName,
      'text': text,
      'createdAt': Timestamp.now()
    });
    _generalMessage.clear();
  }

  Future<void> _sit(
      DocumentSnapshot<Map<String, dynamic>> table, int seatIndex) async {
    if (widget.user == null) return;
    final uid = widget.user!.uid;
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(table.reference);
      final rawSeats = snap.data()?['seats'];
      final seats = rawSeats is Iterable
          ? rawSeats
              .map((e) =>
                  e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
              .toList()
          : <Map<String, dynamic>>[];
      while (seats.length < 2) seats.add(<String, dynamic>{});
      for (int i = 0; i < seats.length; i++)
        if (seats[i]['userId'] == uid) seats[i] = <String, dynamic>{};
      if (seats[seatIndex]['userId']?.toString().isNotEmpty == true)
        throw Exception('Bu koltuk dolu.');
      seats[seatIndex] = {
        'userId': uid,
        'userName': widget.userName,
        'photoBase64': widget.profilResimBase64,
        'startedAt': Timestamp.now()
      };
      transaction.update(table.reference, {'seats': seats, 'isOccupied': true});
    });
  }

  Future<void> _leaveSeat() async {
    final uid = widget.user?.uid;
    if (uid == null) return;
    final snap = await _tables.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final table in snap.docs) {
      final raw = table.data()['seats'];
      final seats = raw is Iterable
          ? raw
              .map((e) =>
                  e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
              .toList()
          : <Map<String, dynamic>>[];
      bool changed = false;
      for (int i = 0; i < seats.length; i++) {
        if (seats[i]['userId'] == uid) {
          seats[i] = <String, dynamic>{};
          changed = true;
        }
      }
      if (changed) batch.update(table.reference, {'seats': seats});
    }
    await batch.commit();
  }

  String? _mySeatTable(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final uid = widget.user?.uid;
    if (uid == null) return null;
    for (final table in snapshot.docs) {
      final seats = table.data()['seats'];
      if (seats is Iterable && seats.any((e) => e is Map && e['userId'] == uid))
        return table.id;
    }
    return null;
  }

  Widget _board() => TweenAnimationBuilder<double>(
      tween: Tween(begin: .92, end: 1),
      duration: const Duration(milliseconds: 900),
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
          height: 82,
          width: double.infinity,
          decoration: BoxDecoration(
              color: const Color(0xFF143D36),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC49A5B), width: 5),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black54, blurRadius: 12, offset: Offset(0, 6))
              ]),
          child: const Center(
              child: Text('DERS ÇALIŞMASI',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)))));

  Widget _seat(Map<String, dynamic> seat, int index,
      DocumentSnapshot<Map<String, dynamic>> table) {
    final occupied = seat['userId']?.toString().isNotEmpty == true;
    final uid = seat['userId']?.toString();
    final photo = seat['photoBase64']?.toString();
    return InkWell(
        onTap: occupied && uid != widget.user?.uid
            ? null
            : () async {
                if (occupied)
                  await _leaveSeat();
                else
                  await _sit(table, index);
              },
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 450),
            decoration: BoxDecoration(
                color:
                    occupied ? _gold.withOpacity(.12) : const Color(0xFF20283D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: occupied ? _gold : Colors.white10)),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircleAvatar(
                  radius: 16,
                  backgroundColor: occupied ? _gold : Colors.grey.shade700,
                  backgroundImage: photo?.isNotEmpty == true
                      ? MemoryImage(base64Decode(photo!))
                      : null,
                  child: photo?.isNotEmpty != true
                      ? Icon(occupied ? Icons.person : Icons.event_seat,
                          size: 16, color: Colors.black)
                      : null),
              const SizedBox(height: 3),
              Text(
                  occupied
                      ? (seat['userName']?.toString() ?? 'Öğrenci')
                      : 'OTUR',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 9,
                      color: occupied ? Colors.white : _cyan,
                      fontWeight: FontWeight.bold))
            ])));
  }

  Widget _tableCard(DocumentSnapshot<Map<String, dynamic>> table) {
    final rawSeats = table.data()?['seats'];
    final seats = rawSeats is Iterable
        ? rawSeats
            .map((e) =>
                e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
            .toList()
        : <Map<String, dynamic>>[];
    while (seats.length < 2) seats.add(<String, dynamic>{});
    final occupied =
        seats.where((s) => s['userId']?.toString().isNotEmpty == true).length;
    return Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
                colors: [Color(0xFF171E4F), Color(0xFF101536)]),
            border: Border.all(
                color: occupied > 0
                    ? _gold.withOpacity(.55)
                    : const Color(0xFF252B57))),
        child: Column(children: [
          const SizedBox(height: 6),
          Text('MASA ${table.data()?['masaNo'] ?? 1}',
              style: const TextStyle(
                  color: _gold, fontSize: 9, fontWeight: FontWeight.bold)),
          Icon(Icons.lightbulb_rounded,
              size: 27, color: occupied > 0 ? _gold : const Color(0xFF555A70)),
          Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              height: 42,
              child: Row(children: [
                _seat(seats[0], 0, table),
                const SizedBox(width: 4),
                _seat(seats[1], 1, table)
              ])),
          Container(
              height: 24,
              margin: const EdgeInsets.fromLTRB(8, 5, 8, 7),
              decoration: const BoxDecoration(
                  color: Color(0xFF503B24),
                  borderRadius: BorderRadius.all(Radius.circular(5))))
        ]));
  }

  Widget _privateChat(String tableId) => _PrivateTableChat(
      classId: widget.classId,
      tableId: tableId,
      user: widget.user,
      userName: widget.userName);

  Widget _generalChat() => Column(children: [
        const ListTile(
            leading: Icon(Icons.forum, color: _cyan),
            title: Text('Ortak Oda Chati',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))),
        Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _generalMessages.orderBy('createdAt').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  return ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final data = snapshot.data!.docs[index].data();
                        final mine = data['senderId'] == widget.user?.uid;
                        return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                padding: const EdgeInsets.all(8),
                                constraints: BoxConstraints(maxWidth: 260),
                                decoration: BoxDecoration(
                                    color: mine
                                        ? _cyan.withOpacity(.16)
                                        : const Color(0xFF1F2937),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          data['senderName']?.toString() ??
                                              'Öğrenci',
                                          style: const TextStyle(
                                              color: _gold,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold)),
                                      Text(data['text']?.toString() ?? '',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12))
                                    ])));
                      });
                })),
        Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: _generalMessage,
                      onSubmitted: (_) => _sendGeneral(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                          hintText: 'Herkese mesaj...',
                          filled: true,
                          fillColor: const Color(0xFF1F2937),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none)))),
              IconButton(
                  onPressed: _sendGeneral,
                  icon: const Icon(Icons.send, color: _cyan))
            ]))
      ]);

  Widget _members() => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('siniflar')
          .doc(widget.classId)
          .snapshots(),
      builder: (context, classSnap) {
        final ids = classSnap.data?.data()?['memberIds'];
        final memberIds = ids is Iterable
            ? ids.map((e) => e.toString()).toList()
            : <String>[];
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('siniflar')
                .doc(widget.classId)
                .collection('presence')
                .snapshots(),
            builder: (context, presenceSnap) {
              final presence = {
                for (final d in presenceSnap.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                  d.id: d.data()
              };
              return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: memberIds.length,
                  itemBuilder: (context, index) {
                    final uid = memberIds[index];
                    final p = presence[uid];
                    final online = p?['online'] == true;
                    return StreamBuilder<
                            DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('kullanicilar')
                            .doc(uid)
                            .snapshots(),
                        builder: (context, userSnap) {
                          final u =
                              userSnap.data?.data() ?? <String, dynamic>{};
                          final photo = u['profilResimBase64']?.toString();
                          final name = u['kullaniciAdi']?.toString() ??
                              p?['name']?.toString() ??
                              'Üye';
                          return ListTile(
                              leading: Stack(children: [
                                CircleAvatar(
                                    backgroundImage: photo?.isNotEmpty == true
                                        ? MemoryImage(base64Decode(photo!))
                                        : null,
                                    child: photo?.isNotEmpty != true
                                        ? Text(name.isNotEmpty ? name[0] : 'Ü')
                                        : null),
                                Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                            color: online
                                                ? const Color(0xFF22C55E)
                                                : Colors.grey,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: const Color(0xFF111827),
                                                width: 2))))
                              ]),
                              title: Text(name,
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text(
                                  online ? 'Çevrimiçi' : 'Çevrimdışı',
                                  style: TextStyle(
                                      color: online
                                          ? const Color(0xFF22C55E)
                                          : Colors.grey)),
                              trailing: widget.isAdmin &&
                                      uid != widget.user?.uid
                                  ? IconButton(
                                      icon: const Icon(Icons.person_remove,
                                          color: Color(0xFFFF334B)),
                                      onPressed: () async {
                                        await FirebaseFirestore.instance
                                            .runTransaction((tx) async {
                                          final classRef = FirebaseFirestore
                                              .instance
                                              .collection('siniflar')
                                              .doc(widget.classId);
                                          final classSnap =
                                              await tx.get(classRef);
                                          final raw =
                                              classSnap.data()?['memberIds'];
                                          final ids = raw is Iterable
                                              ? raw
                                                  .map((e) => e.toString())
                                                  .where((e) => e != uid)
                                                  .toList()
                                              : <String>[];
                                          tx.update(
                                              classRef, {'memberIds': ids});
                                          tx.update(
                                              FirebaseFirestore.instance
                                                  .collection('kullanicilar')
                                                  .doc(uid),
                                              {'sinifId': FieldValue.delete()});
                                        });
                                      })
                                  : null);
                        });
                  });
            });
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Text(widget.className),
        actions: [
          IconButton(
              onPressed: _leaveSeat,
              tooltip: 'Masadan kalk',
              icon: const Icon(Icons.event_seat_outlined, color: _gold))
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _tables.orderBy('masaNo').snapshots(),
        builder: (context, tableSnapshot) {
          if (!tableSnapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final myTable = _mySeatTable(tableSnapshot.data!);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal:
                        MediaQuery.sizeOf(context).width >= 700 ? 32 : 8),
                child: LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final room = Column(children: [
                    _board(),
                    const SizedBox(height: 10),
                    Expanded(
                        child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: constraints.maxWidth >= 900 ? 4 : 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio:
                            constraints.maxWidth < 560 ? .82 : .92,
                      ),
                      itemCount: tableSnapshot.data!.docs.length,
                      itemBuilder: (context, index) =>
                          _tableCard(tableSnapshot.data!.docs[index]),
                    )),
                  ]);
                  if (!wide) {
                    return DefaultTabController(
                        length: 3,
                        child: Column(children: [
                          const TabBar(tabs: [
                            Tab(text: 'Oda'),
                            Tab(text: 'Chat'),
                            Tab(text: 'Üyeler')
                          ]),
                          Expanded(
                              child: TabBarView(children: [
                            room,
                            _generalChat(),
                            _members()
                          ])),
                        ]));
                  }
                  return Row(children: [
                    Expanded(flex: 6, child: room),
                    const SizedBox(width: 12),
                    Expanded(
                        flex: 4,
                        child: DefaultTabController(
                            length: 3,
                            child: Container(
                              decoration: BoxDecoration(
                                  color: const Color(0xFF111827),
                                  borderRadius: BorderRadius.circular(16)),
                              child: Column(children: [
                                const TabBar(tabs: [
                                  Tab(text: 'Chat'),
                                  Tab(text: 'Masa'),
                                  Tab(text: 'Üyeler')
                                ]),
                                Expanded(
                                    child: TabBarView(children: [
                                  _generalChat(),
                                  myTable != null
                                      ? _privateChat(myTable)
                                      : const Center(
                                          child: Text(
                                              'Özel masa chat için yan yana otur.',
                                              style: TextStyle(
                                                  color: Colors.grey))),
                                  _members(),
                                ])),
                              ]),
                            ))),
                  ]);
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PrivateTableChat extends StatefulWidget {
  final String classId, tableId;
  final User? user;
  final String userName;
  const _PrivateTableChat(
      {super.key,
      required this.classId,
      required this.tableId,
      required this.user,
      required this.userName});
  @override
  State<_PrivateTableChat> createState() => _PrivateTableChatState();
}

class _PrivateTableChatState extends State<_PrivateTableChat> {
  final TextEditingController _message = TextEditingController();

  CollectionReference<Map<String, dynamic>> get _messages =>
      FirebaseFirestore.instance
          .collection('siniflar')
          .doc(widget.classId)
          .collection('table_chats')
          .doc(widget.tableId)
          .collection('messages');

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || widget.user == null) return;
    await _messages.add({
      'senderId': widget.user!.uid,
      'senderName': widget.userName,
      'text': text,
      'createdAt': Timestamp.now(),
    });
    _message.clear();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableRef = FirebaseFirestore.instance
        .collection('siniflar')
        .doc(widget.classId)
        .collection('tables')
        .doc(widget.tableId);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: tableRef.snapshots(),
      builder: (context, tableSnap) {
        final raw = tableSnap.data?.data()?['seats'];
        final seats = raw is Iterable
            ? raw
                .map((e) => e is Map
                    ? Map<String, dynamic>.from(e)
                    : <String, dynamic>{})
                .toList()
            : <Map<String, dynamic>>[];
        final ids = seats
            .map((e) => e['userId']?.toString())
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .toList();
        final allowed = ids.contains(widget.user?.uid) && ids.length == 2;
        if (!allowed) {
          return const Center(
              child: Text('Masadaki iki kişi oturduğunda özel chat açılır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)));
        }
        return Column(children: [
          const ListTile(
              leading: Icon(Icons.lock_outline, color: _gold),
              title: Text('Özel Masa Sohbeti',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold))),
          Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _messages.orderBy('createdAt').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final data = snapshot.data!.docs[index].data();
                  final mine = data['senderId'] == widget.user?.uid;
                  return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: mine
                                ? _gold.withOpacity(.14)
                                : const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(data['text']?.toString() ?? '',
                            style: const TextStyle(color: Colors.white)),
                      ));
                },
              );
            },
          )),
          Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: _message,
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                            hintText: 'Yalnızca masa arkadaşına...',
                            filled: true,
                            fillColor: const Color(0xFF1F2937),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none)))),
                IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send, color: _gold)),
              ])),
        ]);
      },
    );
  }
}
