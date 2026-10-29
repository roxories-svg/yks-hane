import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'siniflar.dart';
import 'yks_ai_asistan.dart';
import 'gemini_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCbPTqdlIE7poQMcRlbpLgqlzCfcqVsfO0",
        authDomain: "yks-hane.firebaseapp.com",
        projectId: "yks-hane",
        storageBucket: "yks-hane.firebasestorage.app",
        messagingSenderId: "655065330053",
        appId: "1:655065330053:web:2023292c06d0cc6f04d4ec",
      ),
    );
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }
  } catch (e, stack) {
    debugPrint("Firebase başlatma hatası: $e");
    debugPrint("Firebase stack: $stack");
  }

  ErrorWidget.builder = (details) => Material(
        color: const Color(0xFF030712),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ),
      );

  runApp(const YKSYanlisDefterimApp());
}

class YKSYanlisDefterimApp extends StatefulWidget {
  const YKSYanlisDefterimApp({super.key});

  @override
  State<YKSYanlisDefterimApp> createState() => _YKSYanlisDefterimAppState();
}

class _YKSYanlisDefterimAppState extends State<YKSYanlisDefterimApp> {
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _temaYukle();
  }

  Future<void> _temaYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    });
  }

  Future<void> _temaDegistir(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YKS Hane',
      debugShowCheckedModeBanner: false,
      theme: _isDarkMode
          ? ThemeData.dark().copyWith(
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFF030712),
              primaryColor: const Color(0xFF00F0FF),
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF00F0FF),
                secondary: Color(0xFFA855F7),
                surface: Color(0xFF0F172A),
              ),
              cardColor: const Color(0xFF0F172A),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF030712),
                surfaceTintColor: Colors.transparent,
              ),
            )
          : ThemeData.light().copyWith(
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFF4F7FC),
              primaryColor: const Color(0xFF0066FF),
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF0066FF),
                secondary: Color(0xFFFF334B),
                surface: Colors.white,
              ),
              cardColor: Colors.white,
            ),
      home: AnaSayfa(
        isDarkMode: _isDarkMode,
        onThemeChanged: _temaDegistir,
      ),
    );
  }
}

class SoruModel {
  final String id;
  final String ders;
  final String konu;
  final String soruResimBase64;
  final String? cozumResimBase64;
  final DateTime eklenmeTarihi;
  bool cozuldu;
  int tekrarAraligiGun;

  SoruModel({
    required this.id,
    required this.ders,
    required this.konu,
    required this.soruResimBase64,
    this.cozumResimBase64,
    required this.eklenmeTarihi,
    this.cozuldu = false,
    this.tekrarAraligiGun = 3,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ders': ders,
        'konu': konu,
        'soruResimBase64': soruResimBase64,
        'cozumResimBase64': cozumResimBase64,
        'eklenmeTarihi': eklenmeTarihi.toIso8601String(),
        'cozuldu': cozuldu,
        'tekrarAraligiGun': tekrarAraligiGun,
      };

  factory SoruModel.fromJson(Map<String, dynamic> json) => SoruModel(
        id: json['id'] ?? '',
        ders: json['ders'] ?? '',
        konu: json['konu'] ?? '',
        soruResimBase64: json['soruResimBase64'] ?? json['soruResimYolu'] ?? '',
        cozumResimBase64: json['cozumResimBase64'] ?? json['cozumResimYolu'],
        eklenmeTarihi: json['eklenmeTarihi'] is String
            ? (DateTime.tryParse(json['eklenmeTarihi'] as String) ??
                DateTime.now())
            : json['eklenmeTarihi'] is Timestamp
                ? (json['eklenmeTarihi'] as Timestamp).toDate()
                : DateTime.now(),
        cozuldu: json['cozuldu'] ?? false,
        tekrarAraligiGun: json['tekrarAraligiGun'] ?? 3,
      );
}

class DenemeModel {
  final String id;
  final String denemeAdi;
  final DateTime tarih;
  final double turkceNet;
  final double sosyalNet;
  final double matNet;
  final double fenNet;
  final double toplamNet;

  DenemeModel({
    required this.id,
    required this.denemeAdi,
    required this.tarih,
    required this.turkceNet,
    required this.sosyalNet,
    required this.matNet,
    required this.fenNet,
    required this.toplamNet,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'denemeAdi': denemeAdi,
        'tarih': tarih.toIso8601String(),
        'turkceNet': turkceNet,
        'sosyalNet': sosyalNet,
        'matNet': matNet,
        'fenNet': fenNet,
        'toplamNet': toplamNet,
      };

  factory DenemeModel.fromJson(Map<String, dynamic> json) => DenemeModel(
        id: json['id'] ?? '',
        denemeAdi: json['denemeAdi'] ?? 'Deneme',
        tarih: json['tarih'] is String
            ? (DateTime.tryParse(json['tarih'] as String) ?? DateTime.now())
            : json['tarih'] is Timestamp
                ? (json['tarih'] as Timestamp).toDate()
                : DateTime.now(),
        turkceNet: (json['turkceNet'] as num?)?.toDouble() ?? 0.0,
        sosyalNet: (json['sosyalNet'] as num?)?.toDouble() ?? 0.0,
        matNet: (json['matNet'] as num?)?.toDouble() ?? 0.0,
        fenNet: (json['fenNet'] as num?)?.toDouble() ?? 0.0,
        toplamNet: (json['toplamNet'] as num?)?.toDouble() ?? 0.0,
      );
}

class BildirimMerkeziSayfasi extends StatefulWidget {
  final bool isDarkMode;
  final String? uid;
  const BildirimMerkeziSayfasi({super.key, required this.isDarkMode, this.uid});

  @override
  State<BildirimMerkeziSayfasi> createState() => _BildirimMerkeziSayfasiState();
}

class _BildirimMerkeziSayfasiState extends State<BildirimMerkeziSayfasi> {
  String get _okunanAnahtar =>
      "okunan_sistem_bildirimleri_${widget.uid ?? 'misafir'}";

  Future<void> _tumunuOkunduIsaretle(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_okunanAnahtar, docs.map((e) => e.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF030712) : const Color(0xFFF4F7FC),
      appBar: AppBar(
          title: const Text("Bildirim Merkezi"),
          backgroundColor: Colors.transparent),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('sistem_bildirimleri')
            .orderBy('olusturmaTarihi', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text("Bildirimler yüklenemedi."));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _tumunuOkunduIsaretle(docs);
          });
          if (docs.isEmpty)
            return const Center(child: Text("Henüz bir sistem bildirimi yok."));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final metin = (data['metin'] ?? '').toString().trim();
              final baslik =
                  (data['baslik'] ?? 'Sistem Bildirimi').toString().trim();
              final onemli = data['onemli'] == true;
              Timestamp? ts = data['olusturmaTarihi'] is Timestamp
                  ? data['olusturmaTarihi'] as Timestamp
                  : null;
              final tarih = ts?.toDate();
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? const Color(0xFF0F172A)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: onemli
                          ? const Color(0xFFFF334B).withOpacity(0.5)
                          : Colors.grey.withOpacity(0.25)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                            onemli
                                ? Icons.priority_high
                                : Icons.campaign_outlined,
                            color: onemli
                                ? const Color(0xFFFF334B)
                                : const Color(0xFF00F0FF)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(baslik,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                      ]),
                      const SizedBox(height: 8),
                      Text(metin,
                          style: TextStyle(
                              color: widget.isDarkMode
                                  ? Colors.white70
                                  : Colors.black87,
                              height: 1.35)),
                      if (tarih != null) ...[
                        const SizedBox(height: 8),
                        Text(
                            '${tarih.day.toString().padLeft(2, '0')}.${tarih.month.toString().padLeft(2, '0')}.${tarih.year} ${tarih.hour.toString().padLeft(2, '0')}:${tarih.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ]),
              );
            },
          );
        },
      ),
    );
  }
}

class YKSHaneProfilSayfasi extends StatelessWidget {
  final bool isDarkMode;
  final User? user;
  final String kullaniciAdi;
  final String? profilResimBase64;
  final VoidCallback onEditProfile;
  final VoidCallback onLogin;
  final VoidCallback onLogout;
  final VoidCallback onSwitchAccount;
  final VoidCallback onPremium;
  final VoidCallback onTargetRoom;
  final VoidCallback? onAdmin;

  const YKSHaneProfilSayfasi({
    super.key,
    required this.isDarkMode,
    required this.user,
    required this.kullaniciAdi,
    required this.profilResimBase64,
    required this.onEditProfile,
    required this.onLogin,
    required this.onLogout,
    required this.onSwitchAccount,
    required this.onPremium,
    required this.onTargetRoom,
    this.onAdmin,
  });

  ImageProvider<Object>? get _profilGorseli {
    if (profilResimBase64 != null && profilResimBase64!.isNotEmpty) {
      return MemoryImage(base64Decode(profilResimBase64!));
    }
    if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
      return NetworkImage(user!.photoURL!);
    }
    return null;
  }

  Widget _premiumKart(BuildContext context) {
    return InkWell(
      onTap: onPremium,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [
            Color(0xFF312E81),
            Color(0xFF6D28D9),
            Color(0xFF2563EB)
          ]),
          border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.7)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 7))
          ],
        ),
        child: Row(children: [
          const Icon(Icons.auto_awesome_outlined,
              color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                Row(children: [
                  Text('YKS Hane Premium',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  SizedBox(width: 7),
                  _YakindaRozeti(),
                ]),
                SizedBox(height: 7),
                Text(
                    'Yapay zeka destekli soru çözümleme, akıllı tekrar planı ve kişisel analizlerle yakında Premium ayrıcalıklar!',
                    style: TextStyle(
                        color: Colors.white, height: 1.35, fontSize: 12)),
              ])),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white70, size: 18),
        ]),
      ),
    );
  }

  Widget _ayarSatiri(IconData icon, String title, String subtitle,
      {bool yakinda = false,
      bool premium = false,
      bool bakimda = false,
      VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.14),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: const Color(0xFF818CF8), size: 21)),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 11)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (bakimda) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF334B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('BAKIMDA',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 6),
        ],
        if (premium) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('PREMIUM',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 6),
        ],
        if (yakinda) ...[
          const _YakindaRozeti(),
          const SizedBox(width: 6),
        ],
        const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ]),
      onTap: onTap ?? () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF030712) : const Color(0xFFF4F7FC),
      appBar: AppBar(
          title: const Text('Profil'),
          backgroundColor: Colors.transparent,
          elevation: 0),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFF00F0FF).withOpacity(0.25))),
          child: user == null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    CircleAvatar(
                        radius: 32,
                        backgroundColor: Color(0xFF334155),
                        child: Icon(Icons.person_outline,
                            color: Colors.white, size: 34)),
                    SizedBox(width: 14),
                    Expanded(
                        child: Text('Misafir',
                            style: TextStyle(
                                fontSize: 21, fontWeight: FontWeight.bold)))
                  ]),
                  const SizedBox(height: 12),
                  const Text('Sorular sadece bu cihazda',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),
                  SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                          onPressed: onLogin,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00F0FF),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Giriş yap, sorularını yedekle',
                              style: TextStyle(fontWeight: FontWeight.bold)))),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(
                        radius: 32,
                        backgroundColor: const Color(0xFF00F0FF),
                        backgroundImage: _profilGorseli,
                        child: _profilGorseli == null
                            ? const Icon(Icons.person,
                                color: Colors.black, size: 34)
                            : null),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            Flexible(
                                child: Text(kullaniciAdi,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold))),
                            IconButton(
                                onPressed: onEditProfile,
                                tooltip: 'İsmi düzenle',
                                icon: const Icon(Icons.edit_outlined,
                                    size: 19, color: Color(0xFF00F0FF)))
                          ]),
                          Text(user?.email ?? '',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 8),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF10B981).withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Text('Bulutla eşitleniyor',
                                  style: TextStyle(
                                      color: Color(0xFF34D399),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11))),
                        ])),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: onSwitchAccount,
                            icon: const Icon(Icons.swap_horiz_rounded),
                            label: const Text('Hesap Değiştir'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: onLogout,
                            icon: const Icon(Icons.logout_rounded,
                                color: Color(0xFFFF334B)),
                            label: const Text('Çıkış Yap')))
                  ]),
                ]),
        ),
        _premiumKart(context),
        const Divider(height: 20),
        if (onAdmin != null)
          _ayarSatiri(Icons.admin_panel_settings_rounded, 'Yönetim Paneli',
              'YKS Hane yönetim araçları',
              onTap: onAdmin),
        _ayarSatiri(Icons.local_library_outlined,
            'Hedef Odası / Sanal Kütüphane', 'Gerçek zamanlı çalışma masaları',
            premium: false, bakimda: true, onTap: onTargetRoom),
        _ayarSatiri(Icons.school_outlined, 'Sınav Tercihleri',
            'Alan ve hedef seçimini düzenle',
            yakinda: true),
        _ayarSatiri(Icons.notifications_none_outlined, 'Bildirim Saati',
            'Hatırlatma saatini belirle'),
        _ayarSatiri(Icons.vibration_outlined, 'Dokunma Titreşimi',
            'Dokunuş geri bildirim ayarı'),
        _ayarSatiri(Icons.palette_outlined, 'Tema',
            isDarkMode ? 'Koyu tema aktif' : 'Açık tema aktif'),
      ]),
    );
  }
}

class _YakindaRozeti extends StatelessWidget {
  const _YakindaRozeti();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: const Color(0xFFFF334B),
          borderRadius: BorderRadius.circular(20)),
      child: const Text('YAKINDA',
          style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.7)));
}

class AnaSayfa extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const AnaSayfa({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  int _seciliSekme = 0;
  String _kullaniciAdi = "Misafir Ziyaretçi";
  String? _profilResimBase64;
  User? _aktifKullanici;
  bool _isPremium = false;
  bool _basvuruYapildi = false;
  int _roxCoin = 0;

  final String _adminUID = "Wbs67Nmf43gLQlf9U6n8Ju0xyJE3";

  bool get _isAdmin =>
      (_aktifKullanici?.uid == _adminUID) ||
      (_aktifKullanici?.email?.toLowerCase().contains("roxories") ?? false) ||
      (_aktifKullanici?.email?.toLowerCase().contains("hasanhuseyin") ?? false);

  final Color _anaTemaMavi = const Color(0xFF00F0FF);
  final Color _vurguKirmizi = const Color(0xFFFF334B);
  final Color _premiumAltin = const Color(0xFFFFD700);

  final List<Map<String, dynamic>> dersBilgileri = [
    {'isim': 'Matematik', 'ikon': Icons.calculate_outlined},
    {'isim': 'Fizik', 'ikon': Icons.electric_bolt_outlined},
    {'isim': 'Kimya', 'ikon': Icons.science_outlined},
    {'isim': 'Biyoloji', 'ikon': Icons.biotech_outlined},
    {'isim': 'Türkçe', 'ikon': Icons.menu_book_outlined},
    {'isim': 'Geometri', 'ikon': Icons.explore_outlined},
  ];

  List<SoruModel> sorular = [];
  List<DenemeModel> denemeler = [];
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _profilSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _yanlisSorularSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _denemelerSubscription;
  String? _sonAktifUid;
  bool _authIsBusy = false;
  int _authIslemNo = 0;

  @override
  void initState() {
    super.initState();
    _aktifKullanici = FirebaseAuth.instance.currentUser;
    _sonAktifUid = _aktifKullanici?.uid;
    if (_aktifKullanici != null) {
      _kullaniciAdi = _aktifKullanici!.displayName ??
          (_aktifKullanici!.email?.split('@')[0] ?? "Öğrenci");
      _verileriBuluttanYukle();
    } else {
      _verileriYukle();
    }

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (!mounted || _sonAktifUid == user?.uid) return;
      _sonAktifUid = user?.uid;
      final int islemNo = ++_authIslemNo;
      if (!mounted) return;
      await _profilSubscription?.cancel();
      await _yanlisSorularSubscription?.cancel();
      await _denemelerSubscription?.cancel();
      _profilSubscription = null;
      _yanlisSorularSubscription = null;
      _denemelerSubscription = null;
      setState(() {
        _aktifKullanici = user;
        _kullaniciAdi = user?.displayName ??
            (user?.email?.split('@')[0] ?? "Misafir Ziyaretçi");
        _profilResimBase64 = null;
        _isPremium = false;
        _basvuruYapildi = false;
        _roxCoin = 0;
        sorular = [];
        denemeler = [];
      });
      if (user != null) {
        await _verileriBuluttanYukle(islemNo: islemNo);
      } else {
        await _verileriYukle(islemNo: islemNo);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profilSubscription?.cancel();
    _yanlisSorularSubscription?.cancel();
    _denemelerSubscription?.cancel();
    super.dispose();
  }

  Future<void> _apkIndir() async {
    final Uri url = Uri.parse(
        'https://drive.google.com/uc?export=download&id=1FRWbSJW6cFD6tLbSN2DT1ojZQdnFJlVQ');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("APK dosyası indirilemedi. Lütfen tekrar deneyin."),
            backgroundColor: Color(0xFFFF334B),
          ),
        );
      }
    }
  }

  Future<void> _googleIleGirisYap() async {
    try {
      UserCredential userCredential;
      if (kIsWeb) {
        GoogleAuthProvider provider = GoogleAuthProvider();
        provider.setCustomParameters(<String, String>{
          'prompt': 'select_account',
        });
        userCredential = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        final GoogleSignInAuthentication? googleAuth =
            await googleUser?.authentication;
        if (googleAuth == null) return;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      }

      setState(() {
        _aktifKullanici = userCredential.user;
        if (_aktifKullanici?.displayName != null) {
          _kullaniciAdi = _aktifKullanici!.displayName!;
        } else if (_aktifKullanici?.email != null) {
          _kullaniciAdi = _aktifKullanici!.email!.split('@')[0];
        }
      });

      await _verileriBuluttanYukle();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Oturum açıldı, hoş geldin $_kullaniciAdi! 🚀")),
        );
      }
    } catch (e) {
      debugPrint("Giriş hatası: $e");
    }
  }

  Future<void> _cikisYap() async {
    if (_authIsBusy) return;
    _authIsBusy = true;
    await _profilSubscription?.cancel();
    _profilSubscription = null;
    await _yanlisSorularSubscription?.cancel();
    _yanlisSorularSubscription = null;
    await _denemelerSubscription?.cancel();
    _denemelerSubscription = null;
    if (mounted) {
      setState(() {
        _aktifKullanici = null;
        _kullaniciAdi = "Misafir Ziyaretçi";
        _profilResimBase64 = null;
        _isPremium = false;
        _basvuruYapildi = false;
        _roxCoin = 0;
        sorular = [];
        denemeler = [];
        _seciliSekme = 0;
      });
    }
    try {
      if (!kIsWeb) await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint("Oturum kapatma hatası: $e");
    } finally {
      _authIsBusy = false;
    }
    if (!mounted) return;
    await _verileriYukle();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Oturum kapatıldı.")));
    }
  }

  Future<void> _hesabiDegistir() async {
    if (_authIsBusy) return;
    await _cikisYap();
    if (!mounted) return;
    await _googleIleGirisYap();
  }

  Future<void> _verileriYukle({int? islemNo}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || (islemNo != null && islemNo != _authIslemNo)) return;
      final sorularJson = prefs.getString('yks_sorular_json');
      if (sorularJson != null) {
        final List decoded = jsonDecode(sorularJson);
        setState(() {
          sorular = decoded.map((e) => SoruModel.fromJson(e)).toList();
        });
      }
      final denemelerJson = prefs.getString('yks_denemeler_json');
      if (denemelerJson != null) {
        final List decoded = jsonDecode(denemelerJson);
        setState(() {
          denemeler = decoded.map((e) => DenemeModel.fromJson(e)).toList();
        });
      }
      final yerelKullaniciAdi = prefs.getString('profil_kullanici_adi');
      final yerelProfilResmi = prefs.getString('profil_resim_base64');
      if (yerelKullaniciAdi != null || yerelProfilResmi != null) {
        setState(() {
          if (yerelKullaniciAdi != null &&
              yerelKullaniciAdi.trim().isNotEmpty) {
            _kullaniciAdi = yerelKullaniciAdi.trim();
          }
          if (yerelProfilResmi != null) {
            _profilResimBase64 = yerelProfilResmi;
          }
        });
      }
    } catch (e) {
      debugPrint("Yerel veri yükleme hatası: $e");
    }
  }

  Future<void> _verileriBuluttanYukle({int? islemNo}) async {
    if (_aktifKullanici == null) return;
    try {
      final uid = _aktifKullanici!.uid;
      await _profilSubscription?.cancel();
      await _yanlisSorularSubscription?.cancel();
      await _denemelerSubscription?.cancel();
      _profilSubscription = FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(uid)
          .snapshots()
          .listen((snapshot) {
        final data = snapshot.data();
        if (!mounted || data == null) return;
        final value = data['roxCoin'];
        setState(() {
          if (value is num) _roxCoin = value.toInt();
        });
      });
      _yanlisSorularSubscription = FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(uid)
          .collection('yanlis_sorular')
          .orderBy('eklenmeTarihi', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
        setState(() {
          sorular = snapshot.docs
              .map((doc) => SoruModel.fromJson({
                    ...doc.data(),
                    'id': doc.data()['id']?.toString().isNotEmpty == true
                        ? doc.data()['id'].toString()
                        : doc.id,
                  }))
              .toList();
        });
      });
      _denemelerSubscription = FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(uid)
          .collection('denemeler')
          .orderBy('tarih', descending: true)
          .snapshots()
          .listen((snapshot) {
        if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
        setState(() {
          denemeler = snapshot.docs
              .map((doc) => DenemeModel.fromJson({
                    ...doc.data(),
                    'id': doc.data()['id']?.toString().isNotEmpty == true
                        ? doc.data()['id'].toString()
                        : doc.id,
                  }))
              .toList();
        });
      });
      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(uid)
          .get();

      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      if (islemNo != null && islemNo != _authIslemNo) return;
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          if (data['kullaniciAdi'] is String) {
            final String bulutAdi = data['kullaniciAdi'] as String;
            if (bulutAdi.trim().isNotEmpty) {
              _kullaniciAdi = bulutAdi.trim();
            }
          } else if (_aktifKullanici?.displayName != null) {
            _kullaniciAdi = _aktifKullanici!.displayName!;
          }
          if (data['profilResimBase64'] is String) {
            _profilResimBase64 = data['profilResimBase64'] as String;
          }
          if (data['isPremium'] is bool) {
            _isPremium = data['isPremium'] as bool;
          }
          if (data['basvuruYapildi'] is bool) {
            _basvuruYapildi = data['basvuruYapildi'] as bool;
          }
          if (data['roxCoin'] is num) {
            _roxCoin = (data['roxCoin'] as num).toInt();
          }
        });
        final eskiSorular = data['sorular'];
        if (eskiSorular is List && eskiSorular.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          final collection = FirebaseFirestore.instance
              .collection('kullanicilar')
              .doc(uid)
              .collection('yanlis_sorular');
          for (final raw in eskiSorular) {
            if (raw is! Map) continue;
            final soru = SoruModel.fromJson(Map<String, dynamic>.from(raw));
            final id = soru.id.isNotEmpty
                ? soru.id
                : 'soru_${DateTime.now().millisecondsSinceEpoch}_${batch.hashCode}';
            batch.set(
                collection.doc(id),
                {
                  ...soru.toJson(),
                  'id': id,
                  'uid': uid,
                  'guncellenmeTarihi': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true));
          }
          await batch.commit();
        }
        final eskiDenemeler = data['denemeler'];
        if (eskiDenemeler is List && eskiDenemeler.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          final collection = FirebaseFirestore.instance
              .collection('kullanicilar')
              .doc(uid)
              .collection('denemeler');
          for (final raw in eskiDenemeler) {
            if (raw is! Map) continue;
            final deneme = DenemeModel.fromJson(Map<String, dynamic>.from(raw));
            final id = deneme.id.isNotEmpty
                ? deneme.id
                : 'deneme_${DateTime.now().millisecondsSinceEpoch}_${batch.hashCode}';
            batch.set(
                collection.doc(id),
                {
                  ...deneme.toJson(),
                  'id': id,
                  'uid': uid,
                  'guncellenmeTarihi': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true));
          }
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint("Buluttan veri çekme hatası: $e");
    }
  }

  Future<void> _yanlisSoruyuFirestoreKaydet(SoruModel soru) async {
    final uid = _aktifKullanici?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('kullanicilar')
        .doc(uid)
        .collection('yanlis_sorular')
        .doc(soru.id)
        .set({
      ...soru.toJson(),
      'uid': uid,
      'guncellenmeTarihi': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _denemeyiFirestoreKaydet(DenemeModel deneme) async {
    final uid = _aktifKullanici?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('kullanicilar')
        .doc(uid)
        .collection('denemeler')
        .doc(deneme.id)
        .set({
      ...deneme.toJson(),
      'uid': uid,
      'guncellenmeTarihi': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _yanlisSoruyuFirestoreSil(String id) async {
    final uid = _aktifKullanici?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('kullanicilar')
        .doc(uid)
        .collection('yanlis_sorular')
        .doc(id)
        .delete();
  }

  Future<void> _denemeyiFirestoreSil(String id) async {
    final uid = _aktifKullanici?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('kullanicilar')
        .doc(uid)
        .collection('denemeler')
        .doc(id)
        .delete();
  }

  Future<bool> _verileriKaydet() async {
    Future<void> yerelKaydet() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('yks_sorular_json',
          jsonEncode(sorular.map((e) => e.toJson()).toList()));
      await prefs.setString('yks_denemeler_json',
          jsonEncode(denemeler.map((e) => e.toJson()).toList()));
      await prefs.setString('profil_kullanici_adi', _kullaniciAdi);
      if (_profilResimBase64 != null) {
        await prefs.setString('profil_resim_base64', _profilResimBase64!);
      } else {
        await prefs.remove('profil_resim_base64');
      }
    }

    try {
      if (_aktifKullanici != null) {
        final uid = _aktifKullanici!.uid;
        final dataMap = {
          'kullaniciAdi': _kullaniciAdi,
          'profilResimBase64': _profilResimBase64,
          'isPremium': _isPremium,
          'basvuruYapildi': _basvuruYapildi,
          'guncellenmeTarihi': FieldValue.serverTimestamp(),
        };
        Object? lastError;
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            await FirebaseFirestore.instance
                .collection('kullanicilar')
                .doc(uid)
                .set(dataMap, SetOptions(merge: true));
            lastError = null;
            break;
          } catch (error) {
            lastError = error;
            if (attempt < 2) {
              await Future<void>.delayed(
                  Duration(milliseconds: 300 * (attempt + 1)));
            }
          }
        }
        if (lastError != null) throw lastError;

        Future<void> kayitAltBelgeleriniEsenkronizeEt({
          required String collectionName,
          required List<Map<String, dynamic>> records,
          required String idPrefix,
        }) async {
          final collection = FirebaseFirestore.instance
              .collection('kullanicilar')
              .doc(uid)
              .collection(collectionName);
          final existing = await collection.get();
          final allowedIds = <String>{};
          var batch = FirebaseFirestore.instance.batch();
          var writes = 0;
          Future<void> commitIfNeeded() async {
            if (writes == 0) return;
            await batch.commit();
            batch = FirebaseFirestore.instance.batch();
            writes = 0;
          }

          for (var i = 0; i < records.length; i++) {
            final record = records[i];
            final rawId = record['id']?.toString().trim();
            final id =
                rawId != null && rawId.isNotEmpty ? rawId : '$idPrefix$i';
            allowedIds.add(id);
            batch.set(
                collection.doc(id),
                {
                  ...record,
                  'id': id,
                  'uid': uid,
                  'guncellenmeTarihi': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true));
            writes++;
            if (writes >= 400) await commitIfNeeded();
          }
          for (final old in existing.docs) {
            if (!allowedIds.contains(old.id)) {
              batch.delete(old.reference);
              writes++;
              if (writes >= 400) await commitIfNeeded();
            }
          }
          await commitIfNeeded();
        }

        Object? altBelgeHatasi;
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            await kayitAltBelgeleriniEsenkronizeEt(
              collectionName: 'yanlis_sorular',
              records: sorular.map((e) => e.toJson()).toList(),
              idPrefix: 'soru_',
            );
            await kayitAltBelgeleriniEsenkronizeEt(
              collectionName: 'denemeler',
              records: denemeler.map((e) => e.toJson()).toList(),
              idPrefix: 'deneme_',
            );
            altBelgeHatasi = null;
            break;
          } catch (error) {
            altBelgeHatasi = error;
            if (attempt < 2) {
              await Future<void>.delayed(
                  Duration(milliseconds: 400 * (attempt + 1)));
            }
          }
        }
        if (altBelgeHatasi != null) throw altBelgeHatasi;
      } else {
        await yerelKaydet();
      }

      await yerelKaydet();
      return true;
    } catch (e) {
      debugPrint("Veri kaydetme hatası: $e");
      await yerelKaydet();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Buluta kayıt başarısız oldu. İnternet bağlantınızı kontrol edip tekrar deneyin.'),
          backgroundColor: const Color(0xFFFF334B),
        ));
      }
      return false;
    }
  }

  Future<void> _premiumBasvurusuGonder() async {
    if (_aktifKullanici == null) {
      _girisGerekliDialog(
          "Premium başvurusu yapabilmek için oturum açmalısın!");
      return;
    }
    try {
      final uid = _aktifKullanici!.uid;
      final email = _aktifKullanici!.email ?? "E-posta yok";

      await FirebaseFirestore.instance
          .collection('premium_basvurulari')
          .doc(uid)
          .set({
        'uid': uid,
        'kullaniciAdi': _kullaniciAdi,
        'email': email,
        'tarih': DateTime.now().toIso8601String(),
        'durum': 'beklemede',
      });

      setState(() {
        _basvuruYapildi = true;
      });
      await _verileriKaydet();

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: _premiumAltin),
                const SizedBox(width: 8),
                const Text("Başvuru Alındı! 🎉",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Text(
              "Başvuru isteğin sistem yöneticisine iletildi.\n\nKullanıcı: $_kullaniciAdi\nE-Posta: $email",
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _premiumAltin,
                    foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("TAMAM",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Başvuru hatası: $e");
    }
  }

  Widget _bildirimRozeti() {
    final uid = _aktifKullanici?.uid;
    final anahtar = "okunan_sistem_bildirimleri_${uid ?? 'misafir'}";
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('sistem_bildirimleri')
          .snapshots(),
      builder: (context, snapshot) {
        return FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, prefsSnapshot) {
            int okunmamis = 0;
            if (snapshot.hasData && prefsSnapshot.hasData) {
              final okunan =
                  prefsSnapshot.data!.getStringList(anahtar)?.toSet() ??
                      <String>{};
              okunmamis = snapshot.data!.docs
                  .where((d) => !okunan.contains(d.id))
                  .length;
            }
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: "Bildirim Merkezi",
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BildirimMerkeziSayfasi(
                                isDarkMode: widget.isDarkMode, uid: uid)));
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.notifications_none_outlined),
                ),
                if (okunmamis > 0)
                  Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFF334B),
                            borderRadius: BorderRadius.circular(9)),
                        child: Text(okunmamis > 99 ? '99+' : '$okunmamis',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      )),
              ],
            );
          },
        );
      },
    );
  }

  void _adminPaneliAc() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AdminPaneliSayfasi(isDarkMode: widget.isDarkMode)),
    );
  }

  void _girisGerekliDialog(String mesaj) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _vurguKirmizi.withOpacity(0.5), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Color(0xFFFF334B)),
            SizedBox(width: 8),
            Text("Oturum Gerekli",
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(mesaj,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: Colors.black87),
            icon: const Text("G",
                style: TextStyle(
                    fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
            label: const Text("Google ile Giriş Yap",
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _googleIleGirisYap();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _profilDuzenlemeDialogGoster() async {
    final TextEditingController isimController =
        TextEditingController(text: _kullaniciAdi);
    String? secilenResimBase64 = _profilResimBase64;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _anaTemaMavi.withOpacity(0.5), width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.edit_outlined, color: _anaTemaMavi),
              const SizedBox(width: 8),
              const Text("Profili Düzenle",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: _anaTemaMavi,
                  backgroundImage: secilenResimBase64 != null
                      ? (MemoryImage(base64Decode(secilenResimBase64!))
                          as ImageProvider<Object>)
                      : (_aktifKullanici?.photoURL != null
                          ? (NetworkImage(_aktifKullanici!.photoURL!)
                              as ImageProvider<Object>)
                          : null),
                  child: secilenResimBase64 == null &&
                          _aktifKullanici?.photoURL == null
                      ? const Icon(Icons.person, color: Colors.black, size: 50)
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text("Fotoğraf Seç"),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final XFile? resim = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 800,
                            imageQuality: 70,
                          );
                          if (resim != null) {
                            final List<int> bytes = await resim.readAsBytes();
                            dialogSetState(() {
                              secilenResimBase64 = base64Encode(bytes);
                            });
                          }
                        },
                      ),
                    ),
                    if (secilenResimBase64 != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: "Fotoğrafı kaldır",
                        onPressed: () => dialogSetState(() {
                          secilenResimBase64 = null;
                        }),
                        icon: const Icon(Icons.delete_outline,
                            color: Color(0xFFFF334B)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: isimController,
                  maxLength: 30,
                  decoration: InputDecoration(
                    labelText: "Kullanıcı Adı",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: const Color(0xFF030712),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text("İptal", style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _anaTemaMavi, foregroundColor: Colors.black),
              child: const Text("Kaydet",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final String yeniIsim = isimController.text.trim();
                if (yeniIsim.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text("Kullanıcı adı boş bırakılamaz.")),
                  );
                  return;
                }

                setState(() {
                  _kullaniciAdi = yeniIsim;
                  _profilResimBase64 = secilenResimBase64;
                });

                if (_aktifKullanici != null) {
                  try {
                    await _aktifKullanici!.updateDisplayName(yeniIsim);
                    if (secilenResimBase64 != null &&
                        secilenResimBase64!.isNotEmpty) {
                      await _aktifKullanici!.updatePhotoURL(
                          'data:image/jpeg;base64,$secilenResimBase64');
                    } else {
                      await _aktifKullanici!.updatePhotoURL(null);
                    }
                    await _aktifKullanici!.reload();
                    _aktifKullanici = FirebaseAuth.instance.currentUser;
                  } catch (e) {
                    debugPrint("Firebase kullanıcı adı güncelleme hatası: $e");
                  }
                }

                await _verileriKaydet();
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Profil güncellendi!")),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );

    isimController.dispose();
  }

  void _premiumModalGoster() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _premiumAltin.withOpacity(0.6), width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: _premiumAltin, size: 28),
            const SizedBox(width: 8),
            Text(
              "YKS Hane Premium",
              style: TextStyle(
                  color: _premiumAltin,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "YKS 2027 maratonunda yapay zekâ desteğiyle rakiplerinin önüne geç!",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _premiumOzellikSatiri(
                Icons.auto_awesome, "Gemini AI Soru Çözüm & İpucu Asistanı"),
            _premiumOzellikSatiri(
                Icons.all_inclusive, "Sınırsız Yanlış Soru ve Çözüm Depolama"),
            _premiumOzellikSatiri(
                Icons.insights, "Gelişmiş Net Grafikleri ve Analizler"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF030712),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _premiumAltin.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Aylık Abonelik:",
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                  Text("₺49.99 / Ay",
                      style: TextStyle(
                          color: _premiumAltin,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Kapat", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _premiumAltin,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _isPremium
                  ? "PREMIUM AKTİF ✨"
                  : _basvuruYapildi
                      ? "BAŞVURU BEKLEMEDE ⏳"
                      : "PREMİUM BAŞVURUSU YAP 🚀",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onPressed: _isPremium
                ? null
                : () async {
                    await _premiumBasvurusuGonder();
                  },
          ),
        ],
      ),
    );
  }

  Widget _premiumOzellikSatiri(IconData ikon, String metin) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          Icon(ikon, color: _premiumAltin, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(metin,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _hedefOdasiniAc() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFB91C1C),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: const Row(
          children: [
            Icon(Icons.build_circle_rounded, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hedef Odası şu anda bakımdadır, yakında tekrar açılacaktır!',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _profilSayfasiAc() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YKSHaneProfilSayfasi(
          isDarkMode: widget.isDarkMode,
          user: _aktifKullanici,
          kullaniciAdi: _kullaniciAdi,
          profilResimBase64: _profilResimBase64,
          onEditProfile: _profilDuzenlemeDialogGoster,
          onLogin: _girisBottomSheetGoster,
          onLogout: _cikisYap,
          onSwitchAccount: _hesabiDegistir,
          onPremium: _premiumModalGoster,
          onTargetRoom: _hedefOdasiniAc,
          onAdmin: _isAdmin ? _adminPaneliAc : null,
        ),
      ),
    );
  }

  void _girisBottomSheetGoster() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 22),
            ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset('assets/icon2.png',
                    width: 76, height: 76, fit: BoxFit.cover)),
            const SizedBox(height: 14),
            const Text('YKS Hane',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
                'Bütün cihazlarınızdan soru eklemek ve çözemediğiniz soruları görmek için giriş yapabilirsiniz.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.grey, height: 1.45, fontSize: 13)),
            const SizedBox(height: 8),
            const Text(
              'YKS Hane uygulamasına devam etmek için bir hesap seçin',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF00F0FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 22),
            SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _googleIleGirisYap();
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFFFFF),
                        foregroundColor: const Color(0xFF202124),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.login_rounded,
                        color: Color(0xFF4285F4)),
                    label: const Text('Google ile Giriş Yap',
                        style: TextStyle(fontWeight: FontWeight.bold)))),
            const SizedBox(height: 16),
            const Text('Kullanım Şartları  •  Gizlilik Politikası',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  void _aiAsistanAc() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => YksAiAsistanSayfasi(isDarkMode: widget.isDarkMode),
    );
  }

  void _soruEkleEkraniAc() async {
    if (_aktifKullanici == null) {
      _girisGerekliDialog(
          "Soru ekleyebilmek ve yanlış defterini oluşturabilmek için önce oturum açmalısın!");
      return;
    }
    final yeniSoru = await Navigator.push<SoruModel>(
      context,
      MaterialPageRoute(
        builder: (_) => SoruEkleSayfasi(
          dersler: dersBilgileri.map((e) => e['isim'] as String).toList(),
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
    if (yeniSoru != null) {
      final uid = _aktifKullanici?.uid;
      if (uid == null) return;
      setState(() {
        sorular.add(yeniSoru);
        _roxCoin += 5;
      });
      await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(uid)
          .set(<String, dynamic>{
        'roxCoin': FieldValue.increment(5),
      }, SetOptions(merge: true));
      await _yanlisSoruyuFirestoreKaydet(yeniSoru);
      await _verileriKaydet();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('+5 RC kazanıldı! 🪙')),
        );
      }
    }
  }

  void _denemeEkleEkraniAc() async {
    if (_aktifKullanici == null) {
      _girisGerekliDialog(
          "Deneme sonucu ekleyebilmek için önce oturum açmalısın!");
      return;
    }
    final yeniDeneme = await Navigator.push<DenemeModel>(
      context,
      MaterialPageRoute(
          builder: (_) => DenemeEkleSayfasi(isDarkMode: widget.isDarkMode)),
    );
    if (yeniDeneme != null) {
      setState(() {
        denemeler.add(yeniDeneme);
      });
      await _denemeyiFirestoreKaydet(yeniDeneme);
      await _verileriKaydet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: InkWell(
          onTap: _profilSayfasiAc,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? const Color(0xFF0F172A)
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _anaTemaMavi.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: _anaTemaMavi,
                  backgroundImage: _profilResimBase64 != null
                      ? MemoryImage(base64Decode(_profilResimBase64!))
                          as ImageProvider<Object>
                      : (_aktifKullanici?.photoURL != null
                          ? NetworkImage(_aktifKullanici!.photoURL!)
                              as ImageProvider<Object>
                          : null),
                  child: (_profilResimBase64 == null &&
                          _aktifKullanici?.photoURL == null)
                      ? const Icon(Icons.person, color: Colors.black, size: 16)
                      : null,
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    _kullaniciAdi,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFFFD700).withOpacity(.5)),
                  ),
                  child: Text('🪙 $_roxCoin RC',
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 9,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: _anaTemaMavi, size: 18),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Hedef Odası',
            onPressed: _hedefOdasiniAc,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.local_library_outlined,
                    color: Color(0xFF00F0FF)),
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF334B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('BAKIMDA',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: InkWell(
                onTap: _premiumModalGoster,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _premiumAltin.withOpacity(0.8),
                        Colors.orangeAccent
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.workspace_premium,
                          color: Colors.black, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        _isPremium ? "PRO" : "PREMIUM",
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (kIsWeb)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: InkWell(
                  onTap: _apkIndir,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: const Color(0xFF10B981), width: 1),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.android, color: Color(0xFF10B981), size: 14),
                        SizedBox(width: 2),
                        Text(
                          "APK",
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          _bildirimRozeti(),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _seciliSekme == 0
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: AspectRatio(
                                aspectRatio: 1983 / 793,
                                child: Image.asset(
                                  'assets/images/29ekim.png',
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const NeonSayacKarti(),
                            const SizedBox(height: 16),
                            Text(
                              "Çalışmak istediğin derse dokun, hatalarını anında ezip geç!",
                              style: TextStyle(
                                  color: widget.isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.black54,
                                  fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ...dersBilgileri.map((ders) {
                              final dersAdi = ders['isim'] as String;
                              final dersIkon = ders['ikon'] as IconData;
                              final dersSoruSayisi = sorular
                                  .where((s) => s.ders == dersAdi && !s.cozuldu)
                                  .length;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: widget.isDarkMode
                                      ? const Color(0xFF0F172A)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _anaTemaMavi.withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _anaTemaMavi.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: widget.isDarkMode
                                          ? const Color(0xFF030712)
                                          : Colors.blue[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: _anaTemaMavi.withOpacity(0.3)),
                                    ),
                                    child: Icon(dersIkon, color: _anaTemaMavi),
                                  ),
                                  title: Text(
                                    "$dersAdi Soruları",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: widget.isDarkMode
                                            ? Colors.white
                                            : Colors.black87),
                                  ),
                                  subtitle: Text(
                                    "$dersSoruSayisi Bekleyen Soru",
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                  trailing: Icon(Icons.chevron_right,
                                      color: _anaTemaMavi),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DersSorulariSayfasi(
                                          dersAdi: dersAdi,
                                          sorular: sorular
                                              .where((s) => s.ders == dersAdi)
                                              .toList(),
                                          onSoruGuncellendi:
                                              (guncellenmisSorular) async {
                                            setState(() {
                                              sorular.removeWhere(
                                                  (s) => s.ders == dersAdi);
                                              sorular
                                                  .addAll(guncellenmisSorular);
                                            });
                                            for (final soru
                                                in guncellenmisSorular) {
                                              await _yanlisSoruyuFirestoreKaydet(
                                                  soru);
                                            }
                                            await _verileriKaydet();
                                          },
                                          isDarkMode: widget.isDarkMode,
                                          isPremium: _isPremium,
                                          onPremiumGerekli: _premiumModalGoster,
                                        ),
                                      ),
                                    );
                                    setState(() {});
                                  },
                                ),
                              );
                            }),
                            const SizedBox(height: 20),
                            Center(
                              child: Text(
                                "Editör: Hasan Hüseyin Serken",
                                style: TextStyle(
                                  color: widget.isDarkMode
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _seciliSekme == 1
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 80),
                            child: ZamanlayiciVeKronometreSekmesi(
                                isDarkMode: widget.isDarkMode),
                          )
                        : _seciliSekme == 2
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 80),
                                child: KutuphaneSayfasi(
                                  cozulenSorular:
                                      sorular.where((s) => s.cozuldu).toList(),
                                  onSoruSilindi: (id) {
                                    setState(() {
                                      sorular.removeWhere((s) => s.id == id);
                                    });
                                    _yanlisSoruyuFirestoreSil(id);
                                    _verileriKaydet();
                                  },
                                  isDarkMode: widget.isDarkMode,
                                ),
                              )
                            : _seciliSekme == 4
                                ? SiniflarSayfasi(
                                    user: _aktifKullanici,
                                    kullaniciAdi: _kullaniciAdi,
                                    profilResimBase64: _profilResimBase64,
                                    roxCoin: _roxCoin,
                                    isDarkMode: widget.isDarkMode,
                                    isAdmin: _isAdmin,
                                    onLogin: _googleIleGirisYap,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.only(bottom: 80),
                                    child: AnalizSayfasi(
                                      denemeler: denemeler,
                                      onDenemeEkleTiklandi: _denemeEkleEkraniAc,
                                      onDenemeSilindi: (id) {
                                        setState(() {
                                          denemeler
                                              .removeWhere((d) => d.id == id);
                                        });
                                        _denemeyiFirestoreSil(id);
                                        _verileriKaydet();
                                      },
                                      isDarkMode: widget.isDarkMode,
                                    ),
                                  ),
              ),
            ],
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? const Color(0xFF0F172A).withOpacity(0.9)
                          : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: _anaTemaMavi.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: _anaTemaMavi.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _dockOgesi(Icons.list_alt, "Sorular", 0),
                        _dockOgesi(Icons.timer_outlined, "Zamanlayıcı", 1),
                        const SizedBox(width: 45),
                        _dockOgesi(
                            Icons.local_library_outlined, "Kütüphane", 2),
                        _dockOgesi(Icons.groups_2_outlined, "Sınıflar", 4),
                        _dockOgesi(Icons.bar_chart, "Analiz", 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 56,
                height: 56,
                child: FloatingActionButton(
                  backgroundColor: _vurguKirmizi,
                  elevation: 8,
                  shape: const CircleBorder(),
                  onPressed: _seciliSekme == 3
                      ? _denemeEkleEkraniAc
                      : _seciliSekme == 4
                          ? null
                          : _soruEkleEkraniAc,
                  child: Icon(
                    _seciliSekme == 3
                        ? Icons.add_chart
                        : _seciliSekme == 4
                            ? Icons.groups_2
                            : Icons.add,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 92,
            child: FloatingActionButton.small(
              heroTag: 'yksAiAsistanFab',
              backgroundColor: const Color(0xFFA855F7),
              foregroundColor: Colors.white,
              tooltip: 'YKS AI Soru Çözücü',
              onPressed: _aiAsistanAc,
              child: const Icon(Icons.auto_awesome_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dockOgesi(IconData ikon, String etiket, int index) {
    bool aktif = _seciliSekme == index;
    return InkWell(
      onTap: () => setState(() => _seciliSekme = index),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              ikon,
              color: aktif ? _anaTemaMavi : Colors.grey,
              size: aktif ? 24 : 20,
            ),
            const SizedBox(height: 2),
            Text(
              etiket,
              style: TextStyle(
                fontSize: 9,
                fontWeight: aktif ? FontWeight.bold : FontWeight.normal,
                color: aktif ? _anaTemaMavi : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= ADMIN PANELİ =================
class AdminPaneliSayfasi extends StatefulWidget {
  final bool isDarkMode;
  const AdminPaneliSayfasi({super.key, required this.isDarkMode});

  @override
  State<AdminPaneliSayfasi> createState() => _AdminPaneliSayfasiState();
}

class _AdminPaneliSayfasiState extends State<AdminPaneliSayfasi> {
  int _adminSekme = 0;
  final TextEditingController _duyuruController = TextEditingController();
  final TextEditingController _bildirimBaslikController =
      TextEditingController();
  bool _bildirimOnemli = false;

  @override
  void dispose() {
    _duyuruController.dispose();
    _bildirimBaslikController.dispose();
    super.dispose();
  }

  Future<void> _duyuruSifirla() async {
    await FirebaseFirestore.instance.collection('sistem').doc('duyuru').set({
      'metin': '',
      'tarih': '',
      'aktif': false,
    }, SetOptions(merge: true));
    _duyuruController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aktif duyuru kaldırıldı.")),
      );
    }
  }

  Future<void> _duyuruYayinla() async {
    final metin = _duyuruController.text.trim();
    if (metin.isEmpty) return;
    final baslik = _bildirimBaslikController.text.trim();
    final simdi = Timestamp.now();
    await FirebaseFirestore.instance.collection('sistem').doc('duyuru').set({
      'metin': metin,
      'tarih': DateTime.now().toIso8601String(),
      'aktif': true,
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance.collection('sistem_bildirimleri').add({
      'baslik': baslik.isEmpty ? 'Sistem Güncellemesi' : baslik,
      'metin': metin,
      'onemli': _bildirimOnemli,
      'olusturmaTarihi': simdi,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Bildirim sistemi için duyuru yayınlandı! 📢")),
      );
      _duyuruController.clear();
      _bildirimBaslikController.clear();
      setState(() => _bildirimOnemli = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF030712) : Colors.white,
      appBar: AppBar(
        title: const Text("👑 YKS Hane Yönetim Paneli"),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _adminSekme == 0
                        ? const Color(0xFFA855F7)
                        : const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => setState(() => _adminSekme = 0),
                  child: const Text("Öğrenciler"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _adminSekme == 1
                        ? const Color(0xFFA855F7)
                        : const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => setState(() => _adminSekme = 1),
                  child: const Text("Başvurular"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _adminSekme == 2
                        ? const Color(0xFFA855F7)
                        : const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => setState(() => _adminSekme = 2),
                  child: const Text("Duyuru"),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.grey),
          Expanded(
            child: _adminSekme == 0
                ? _ogrenciListesiBolumu()
                : _adminSekme == 1
                    ? _bekleyenBasvurularBolumu()
                    : _duyuruYayinlaBolumu(),
          ),
        ],
      ),
    );
  }

  Widget _ogrenciListesiBolumu() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('kullanicilar').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFA855F7)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text("Sistemde henüz kayıtlı kullanıcı yok.",
                  style: TextStyle(color: Colors.grey)));
        }

        final Map<String, QueryDocumentSnapshot> benzersizKullanicilar = {};
        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final Object? emailValue = data['email'];
          final String email =
              emailValue is String ? emailValue.toLowerCase().trim() : '';
          final String key = doc.id.isNotEmpty
              ? 'uid:${doc.id}'
              : (email.isNotEmpty ? 'email:$email' : 'doc:${doc.id}');
          benzersizKullanicilar.putIfAbsent(key, () => doc);
        }
        final kullanicilar = benzersizKullanicilar.values.toList();
        int toplamSoru = 0;
        int proUyeSayisi = 0;
        for (var doc in kullanicilar) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['isPremium'] == true) proUyeSayisi++;
          final List sList = d['sorular'] ?? [];
          toplamSoru += sList.length;
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                      child: _statKarti("Öğrenci", "${kullanicilar.length}",
                          Icons.people, Colors.blue)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _statKarti("Soru", "$toplamSoru",
                          Icons.library_books, Colors.orange)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _statKarti("PRO", "$proUyeSayisi",
                          Icons.workspace_premium, Colors.amber)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: kullanicilar.length,
                itemBuilder: (context, index) {
                  final doc = kullanicilar[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final uid = doc.id;
                  final kIsim = data['kullaniciAdi'] ?? 'İsimsiz Öğrenci';
                  final isPro = data['isPremium'] ?? false;
                  final basvuruVar = data['basvuruYapildi'] ?? false;

                  final List sorularData = data['sorular'] ?? [];
                  final List denemelerData = data['denemeler'] ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isPro
                              ? const Color(0xFFFFD700)
                              : basvuruVar
                                  ? Colors.orange
                                  : const Color(0xFFA855F7).withOpacity(0.4)),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFA855F7),
                        backgroundImage: data['profilResimBase64'] != null
                            ? MemoryImage(
                                base64Decode(data['profilResimBase64']))
                            : null,
                        child: data['profilResimBase64'] == null
                            ? Text(
                                kIsim.isNotEmpty ? kIsim[0].toUpperCase() : "Ö",
                                style: const TextStyle(color: Colors.white))
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(kIsim,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                          if (isPro) ...[
                            const Icon(Icons.workspace_premium,
                                color: Color(0xFFFFD700), size: 16),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        "Soru: ${sorularData.length} | Deneme: ${denemelerData.length}\n"
                        "Durum: ${isPro ? 'PRO ÜYE 👑' : basvuruVar ? 'BAŞVURU YAPTI ⏳' : 'Ücretsiz'}",
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.manage_accounts,
                                color: Color(0xFF00F0FF)),
                            tooltip: 'Kullanıcı profilini düzenle',
                            onPressed: () async {
                              final nameController =
                                  TextEditingController(text: kIsim.toString());
                              String? photo =
                                  data['profilResimBase64']?.toString();
                              await showDialog<void>(
                                  context: context,
                                  builder: (dialogContext) => StatefulBuilder(
                                      builder: (dialogContext,
                                              dialogSetState) =>
                                          AlertDialog(
                                            backgroundColor:
                                                const Color(0xFF0F172A),
                                            title: Text(
                                                '$kIsim profilini düzenle',
                                                style: const TextStyle(
                                                    color: Colors.white)),
                                            content: SingleChildScrollView(
                                                child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                  CircleAvatar(
                                                      radius: 44,
                                                      backgroundImage:
                                                          photo?.isNotEmpty ==
                                                                  true
                                                              ? MemoryImage(
                                                                  base64Decode(
                                                                      photo!))
                                                              : null,
                                                      child:
                                                          photo?.isNotEmpty !=
                                                                  true
                                                              ? const Icon(
                                                                  Icons.person)
                                                              : null),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        TextButton.icon(
                                                            onPressed:
                                                                () async {
                                                              final file = await ImagePicker().pickImage(
                                                                  source:
                                                                      ImageSource
                                                                          .gallery,
                                                                  maxWidth: 800,
                                                                  imageQuality:
                                                                      70);
                                                              if (file !=
                                                                  null) {
                                                                final bytes =
                                                                    await file
                                                                        .readAsBytes();
                                                                dialogSetState(
                                                                    () => photo =
                                                                        base64Encode(
                                                                            bytes));
                                                              }
                                                            },
                                                            icon: const Icon(Icons
                                                                .photo_library),
                                                            label: const Text(
                                                                'Fotoğraf')),
                                                        if (photo?.isNotEmpty ==
                                                            true)
                                                          TextButton(
                                                              onPressed: () =>
                                                                  dialogSetState(
                                                                      () => photo =
                                                                          null),
                                                              child: const Text(
                                                                  'Kaldır'))
                                                      ]),
                                                  TextField(
                                                      controller:
                                                          nameController,
                                                      style: const TextStyle(
                                                          color: Colors.white),
                                                      maxLength: 30,
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'Kullanıcı adı')),
                                                ])),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          dialogContext),
                                                  child: const Text('İptal')),
                                              ElevatedButton(
                                                  onPressed: () async {
                                                    final newName =
                                                        nameController.text
                                                            .trim();
                                                    if (newName.isEmpty) return;
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection(
                                                            'kullanicilar')
                                                        .doc(uid)
                                                        .set({
                                                      'kullaniciAdi': newName,
                                                      'profilResimBase64': photo
                                                    }, SetOptions(merge: true));
                                                    if (dialogContext.mounted)
                                                      Navigator.pop(
                                                          dialogContext);
                                                  },
                                                  child: const Text('Kaydet'))
                                            ],
                                          )));
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              isPro ? Icons.star : Icons.star_border,
                              color:
                                  isPro ? const Color(0xFFFFD700) : Colors.grey,
                            ),
                            tooltip: isPro ? "Pro'yu Kaldır" : "Pro Yap",
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('kullanicilar')
                                  .doc(uid)
                                  .update({'isPremium': !isPro});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.monetization_on,
                                color: Color(0xFFFFD700)),
                            tooltip: "RoxCoin yükle",
                            onPressed: () async {
                              final TextEditingController miktarController =
                                  TextEditingController();
                              final int? miktar = await showDialog<int>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  backgroundColor: const Color(0xFF0F172A),
                                  title: Text('$kIsim — RC Yükle',
                                      style:
                                          const TextStyle(color: Colors.white)),
                                  content: TextField(
                                    controller: miktarController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                        hintText: 'Yüklenecek RC miktarı'),
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext),
                                        child: const Text('İptal')),
                                    ElevatedButton(
                                        onPressed: () {
                                          final int? value = int.tryParse(
                                              miktarController.text.trim());
                                          Navigator.pop(dialogContext, value);
                                        },
                                        child: const Text('Yükle')),
                                  ],
                                ),
                              );
                              if (miktar == null || miktar <= 0) return;
                              await FirebaseFirestore.instance
                                  .collection('kullanicilar')
                                  .doc(uid)
                                  .set(<String, dynamic>{
                                'roxCoin': FieldValue.increment(miktar),
                              }, SetOptions(merge: true));
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      '$kIsim hesabına +$miktar RC yüklendi')));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.analytics_outlined,
                                color: Color(0xFFFFD700)),
                            tooltip: "Deneme ve netleri incele",
                            onPressed: () {
                              _kullaniciDenemeIstatistikleriniGoster(
                                context,
                                kIsim.toString(),
                                denemelerData,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right,
                                color: Color(0xFF00F0FF)),
                            tooltip: "Defterini İncele",
                            onPressed: () {
                              final ogrenciSorulari = sorularData
                                  .map((e) => SoruModel.fromJson(
                                      e as Map<String, dynamic>))
                                  .toList();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OgrenciSoruIncelemeSayfasi(
                                    kullaniciAdi: kIsim,
                                    sorular: ogrenciSorulari,
                                    isDarkMode: widget.isDarkMode,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _kullaniciDenemeIstatistikleriniGoster(
      BuildContext context, String kullaniciAdi, List denemelerData) {
    final List<DenemeModel> denemeler = denemelerData
        .whereType<Map<String, dynamic>>()
        .map(DenemeModel.fromJson)
        .toList()
      ..sort((a, b) => b.tarih.compareTo(a.tarih));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final double enYuksek = denemeler.isEmpty
            ? 0
            : denemeler.map((d) => d.toplamNet).reduce((a, b) => a > b ? a : b);
        final double sonNet = denemeler.isEmpty ? 0 : denemeler.first.toplamNet;
        final double ortalama = denemeler.isEmpty
            ? 0
            : denemeler
                    .map((d) => d.toplamNet)
                    .fold<double>(0, (a, b) => a + b) /
                denemeler.length;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text("$kullaniciAdi • Deneme Analizi",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _statKarti("Son Net", sonNet.toStringAsFixed(2),
                            Icons.trending_up, Colors.blue)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _statKarti(
                            "Ortalama",
                            ortalama.toStringAsFixed(2),
                            Icons.analytics,
                            Colors.orange)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _statKarti("En İyi", enYuksek.toStringAsFixed(2),
                            Icons.workspace_premium, Colors.amber)),
                  ]),
                  const SizedBox(height: 12),
                  Expanded(
                    child: denemeler.isEmpty
                        ? const Center(
                            child: Text("Bu kullanıcı henüz deneme eklememiş.",
                                style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: denemeler.length,
                            itemBuilder: (context, index) {
                              final d = denemeler[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF030712),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFA855F7)
                                          .withOpacity(0.35)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.denemeAdi,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 5),
                                    Text(
                                        "TYT Netleri: Türkçe ${d.turkceNet.toStringAsFixed(2)} • Sosyal ${d.sosyalNet.toStringAsFixed(2)} • Matematik ${d.matNet.toStringAsFixed(2)} • Fen ${d.fenNet.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                    Text(
                                        "Toplam: ${d.toplamNet.toStringAsFixed(2)} • ${d.tarih.day}.${d.tarih.month}.${d.tarih.year}",
                                        style: const TextStyle(
                                            color: Color(0xFF00F0FF),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statKarti(String baslik, String deger, IconData ikon, Color renk) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Icon(ikon, color: renk, size: 20),
          const SizedBox(height: 4),
          Text(deger,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(baslik,
              style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _bekleyenBasvurularBolumu() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('premium_basvurulari')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFA855F7)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text("Bekleyen premium başvuru bulunmuyor.",
                  style: TextStyle(color: Colors.grey)));
        }

        final basvurular = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: basvurular.length,
          itemBuilder: (context, index) {
            final doc = basvurular[index];
            final data = doc.data() as Map<String, dynamic>;
            final uid = data['uid'] ?? doc.id;
            final kAdi = data['kullaniciAdi'] ?? 'Öğrenci';
            final email = data['email'] ?? '';
            final tarih = data['tarih'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(kAdi,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("E-posta: $email\nTarih: $tarih",
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black),
                  child: const Text("ONAYLA",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('kullanicilar')
                        .doc(uid)
                        .update({
                      'isPremium': true,
                      'basvuruYapildi': false,
                    });
                    await FirebaseFirestore.instance
                        .collection('premium_basvurulari')
                        .doc(doc.id)
                        .delete();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("$kAdi başarıyla PRO yapıldı! ✨")),
                      );
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _duyuruYayinlaBolumu() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tüm Öğrencilere Global Duyuru Gönder",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 8),
          const Text(
              "Buraya yazdığın mesaj, öğrencilerin uygulamayı açtığında karşılarına pop-up olarak çıkacaktır.",
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          TextField(
            controller: _bildirimBaslikController,
            decoration: InputDecoration(
              labelText: "Bildirim başlığı",
              hintText: "Örn: Yeni sürüm yayınlandı",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _duyuruController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "Örn: YKS 2027 tayfa, yeni deneme analizleri aktif!",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _bildirimOnemli,
            onChanged: (v) => setState(() => _bildirimOnemli = v ?? false),
            contentPadding: EdgeInsets.zero,
            activeColor: const Color(0xFFFF334B),
            title: const Text("Önemli güncelleme olarak işaretle",
                style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA855F7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _duyuruYayinla,
              child: const Text("DUYURUYU YAYINLA 🚀",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF334B),
                side: const BorderSide(color: Color(0xFFFF334B)),
              ),
              onPressed: _duyuruSifirla,
              icon: const Icon(Icons.clear_all),
              label: const Text("Aktif duyuruyu kaldır"),
            ),
          ),
        ],
      ),
    );
  }
}

class OgrenciSoruIncelemeSayfasi extends StatelessWidget {
  final String kullaniciAdi;
  final List<SoruModel> sorular;
  final bool isDarkMode;

  const OgrenciSoruIncelemeSayfasi({
    super.key,
    required this.kullaniciAdi,
    required this.sorular,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF030712) : Colors.white,
      appBar: AppBar(
        title: Text("$kullaniciAdi'nin Yanlış Defteri"),
        backgroundColor: Colors.transparent,
      ),
      body: sorular.isEmpty
          ? const Center(
              child: Text("Bu öğrenci henüz soru yüklememiş.",
                  style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sorular.length,
              itemBuilder: (context, index) {
                final s = sorular[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF00F0FF).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${s.ders} - ${s.konu}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00F0FF))),
                          Text(s.cozuldu ? "Çözüldü ✅" : "Bekliyor ⏳",
                              style: TextStyle(
                                  color:
                                      s.cozuldu ? Colors.green : Colors.orange,
                                  fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _tamEkranResimGoster(
                            context, s.soruResimBase64, "${s.ders} - Soru"),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            base64Decode(s.soruResimBase64),
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (s.cozumResimBase64 != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFD700),
                            side: BorderSide(
                                color:
                                    const Color(0xFFFFD700).withOpacity(0.5)),
                          ),
                          icon: const Icon(Icons.lightbulb, size: 18),
                          label: const Text("Öğrencinin Eklediği Çözümü Gör"),
                          onPressed: () => _tamEkranResimGoster(context,
                              s.cozumResimBase64!, "${s.ders} - Çözüm"),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class NeonSayacKarti extends StatefulWidget {
  const NeonSayacKarti({super.key});

  @override
  State<NeonSayacKarti> createState() => _NeonSayacKartiState();
}

class _NeonSayacKartiState extends State<NeonSayacKarti> {
  late Timer _timer;
  Duration _kalanSure = Duration.zero;

  @override
  void initState() {
    super.initState();
    _hedefHesapla();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _hedefHesapla());
  }

  void _hedefHesapla() {
    final hedef = DateTime(2027, 6, 20, 10, 0, 0);
    final simdi = DateTime.now();
    if (hedef.isAfter(simdi)) {
      setState(() {
        _kalanSure = hedef.difference(simdi);
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF00F0FF).withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.military_tech, color: Color(0xFFFFD700), size: 20),
                  SizedBox(width: 6),
                  Text("YKS 2027 HEDEF SAYACI",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF334B),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text("CANLI",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _zamanKutusu(_kalanSure.inDays.toString(), "GÜN"),
              _zamanKutusu((_kalanSure.inHours % 24).toString(), "SAAT"),
              _zamanKutusu((_kalanSure.inMinutes % 60).toString(), "DAKİKA"),
              _zamanKutusu((_kalanSure.inSeconds % 60).toString(), "SANİYE"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _zamanKutusu(String deger, String etiket) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF030712),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(deger.padLeft(2, '0'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(etiket,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class ZamanlayiciVeKronometreSekmesi extends StatefulWidget {
  final bool isDarkMode;
  const ZamanlayiciVeKronometreSekmesi({super.key, required this.isDarkMode});

  @override
  State<ZamanlayiciVeKronometreSekmesi> createState() =>
      _ZamanlayiciVeKronometreSekmesiState();
}

class _ZamanlayiciVeKronometreSekmesiState
    extends State<ZamanlayiciVeKronometreSekmesi> {
  int _mod = 0;
  int _secilenDakika = 25;
  int _kalanSaniye = 25 * 60;
  Timer? _zamanlayiciTimer;
  bool _zamanlayiciAktif = false;
  bool _sureBitti = false;

  int _kronometreSaniye = 0;
  Timer? _kronometreTimer;
  bool _kronometreAktif = false;

  void _alarmCal() {
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  void _zamanlayiciBaslatDurdur() {
    if (_zamanlayiciAktif) {
      _zamanlayiciTimer?.cancel();
      setState(() => _zamanlayiciAktif = false);
    } else {
      if (_sureBitti) {
        setState(() {
          _kalanSaniye = _secilenDakika * 60;
          _sureBitti = false;
        });
      }
      setState(() => _zamanlayiciAktif = true);
      _zamanlayiciTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_kalanSaniye > 0) {
          setState(() => _kalanSaniye--);
        } else {
          timer.cancel();
          setState(() {
            _zamanlayiciAktif = false;
            _sureBitti = true;
          });
          _alarmCal();
        }
      });
    }
  }

  void _zamanlayiciSifirla() {
    _zamanlayiciTimer?.cancel();
    setState(() {
      _zamanlayiciAktif = false;
      _sureBitti = false;
      _kalanSaniye = _secilenDakika * 60;
    });
  }

  void _sureSecDialogGoster() {
    if (_zamanlayiciAktif) return;
    final TextEditingController customDakikaController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text("Süre Seçin veya Girin",
            style: TextStyle(
                color: Color(0xFF00F0FF), fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children:
                      [10, 15, 20, 25, 30, 40, 45, 60, 90, 120].map((dakika) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _secilenDakika == dakika
                            ? const Color(0xFF00F0FF)
                            : const Color(0xFF030712),
                        foregroundColor: _secilenDakika == dakika
                            ? Colors.black
                            : Colors.white,
                        side: BorderSide(
                            color: const Color(0xFF00F0FF).withOpacity(0.4)),
                      ),
                      onPressed: () {
                        setState(() {
                          _secilenDakika = dakika;
                          _kalanSaniye = dakika * 60;
                          _sureBitti = false;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Text("$dakika dk"),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.grey),
                const SizedBox(height: 10),
                TextField(
                  controller: customDakikaController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Özel Dakika Girin",
                    hintText: "Örn: 35",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: const Color(0xFF00F0FF).withOpacity(0.4)),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F0FF),
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(42),
                  ),
                  onPressed: () {
                    final val =
                        int.tryParse(customDakikaController.text.trim());
                    if (val != null && val > 0) {
                      setState(() {
                        _secilenDakika = val;
                        _kalanSaniye = val * 60;
                        _sureBitti = false;
                      });
                      Navigator.pop(ctx);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Lütfen geçerli bir dakika girin!")),
                      );
                    }
                  },
                  child: const Text("Özel Süreyi Ayarla",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          )
        ],
      ),
    );
  }

  void _kronometreBaslatDurdur() {
    if (_kronometreAktif) {
      _kronometreTimer?.cancel();
      setState(() => _kronometreAktif = false);
    } else {
      setState(() => _kronometreAktif = true);
      _kronometreTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _kronometreSaniye++);
      });
    }
  }

  void _kronometreSifirla() {
    _kronometreTimer?.cancel();
    setState(() {
      _kronometreAktif = false;
      _kronometreSaniye = 0;
    });
  }

  @override
  void dispose() {
    _zamanlayiciTimer?.cancel();
    _kronometreTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int zDakika = _kalanSaniye ~/ 60;
    int zSaniye = _kalanSaniye % 60;

    int kSaat = _kronometreSaniye ~/ 3600;
    int kDakika = (_kronometreSaniye % 3600) ~/ 60;
    int kSaniye = _kronometreSaniye % 60;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mod == 0
                      ? const Color(0xFF00F0FF)
                      : const Color(0xFF0F172A),
                  foregroundColor: _mod == 0 ? Colors.black : Colors.white,
                ),
                onPressed: () => setState(() => _mod = 0),
                child: const Text("Zamanlayıcı"),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _mod == 1
                      ? const Color(0xFF00F0FF)
                      : const Color(0xFF0F172A),
                  foregroundColor: _mod == 1 ? Colors.black : Colors.white,
                ),
                onPressed: () => setState(() => _mod = 1),
                child: const Text("Kronometre"),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_mod == 0) ...[
            const Icon(Icons.timer, size: 64, color: Color(0xFF00F0FF)),
            const SizedBox(height: 12),
            const Text("Odaklanma Zamanlayıcısı",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (!_zamanlayiciAktif) ...[
              GestureDetector(
                onTap: _sureSecDialogGoster,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF00F0FF).withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app,
                          color: Color(0xFF00F0FF), size: 18),
                      const SizedBox(width: 8),
                      Text("Süre Seç: $_secilenDakika Dakika",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down,
                          color: Color(0xFF00F0FF)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              "${zDakika.toString().padLeft(2, '0')}:${zSaniye.toString().padLeft(2, '0')}",
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.bold,
                color: _sureBitti
                    ? const Color(0xFFFF334B)
                    : const Color(0xFF00F0FF),
              ),
            ),
            if (_sureBitti) ...[
              const SizedBox(height: 10),
              const Text("🚨 SÜRE BİTTİ! ALARM ÇALDI! HARİKA İŞ!",
                  style: TextStyle(
                      color: Color(0xFFFF334B),
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _zamanlayiciAktif
                        ? const Color(0xFFFF334B)
                        : const Color(0xFF00F0FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  onPressed: _zamanlayiciBaslatDurdur,
                  child: Text(_zamanlayiciAktif ? "Durdur" : "Başlat",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _zamanlayiciSifirla,
                  child: const Text("Sıfırla",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ] else ...[
            const Icon(Icons.av_timer, size: 64, color: Color(0xFF00F0FF)),
            const SizedBox(height: 12),
            const Text("Çalışma Kronometresi",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Text(
              "${kSaat.toString().padLeft(2, '0')}:${kDakika.toString().padLeft(2, '0')}:${kSaniye.toString().padLeft(2, '0')}",
              style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00F0FF)),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kronometreAktif
                        ? const Color(0xFFFF334B)
                        : const Color(0xFF00F0FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  onPressed: _kronometreBaslatDurdur,
                  child: Text(_kronometreAktif ? "Durdur" : "Başlat",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _kronometreSifirla,
                  child: const Text("Sıfırla",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

void _tamEkranResimGoster(
    BuildContext context, String base64Str, String baslik) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.memory(
                base64Decode(base64Str),
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: Text(
              baslik,
              style: const TextStyle(
                color: Color(0xFF00F0FF),
                fontWeight: FontWeight.bold,
                fontSize: 16,
                shadows: [Shadow(blurRadius: 10, color: Colors.black)],
              ),
            ),
          ),
          Positioned(
            top: 30,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ),
  );
}

class KutuphaneSayfasi extends StatelessWidget {
  final List<SoruModel> cozulenSorular;
  final Function(String) onSoruSilindi;
  final bool isDarkMode;

  const KutuphaneSayfasi({
    super.key,
    required this.cozulenSorular,
    required this.onSoruSilindi,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: cozulenSorular.isEmpty
          ? const Center(
              child: Text("Henüz çözülen soru bulunmuyor.",
                  style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cozulenSorular.length,
              itemBuilder: (context, index) {
                final s = cozulenSorular[index];
                return Card(
                  color: const Color(0xFF0F172A),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _tamEkranResimGoster(
                              context, s.soruResimBase64, "${s.ders} - Soru"),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(base64Decode(s.soruResimBase64),
                                width: 55, height: 55, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${s.ders} - ${s.konu}",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              const Text("Çözüldü 🎉 (Tam ekran için dokun)",
                                  style: TextStyle(
                                      color: Colors.greenAccent, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (s.cozumResimBase64 != null) ...[
                          IconButton(
                            icon: const Icon(Icons.lightbulb,
                                color: Color(0xFFFFD700)),
                            tooltip: "Çözümü Göster",
                            onPressed: () => _tamEkranResimGoster(context,
                                s.cozumResimBase64!, "${s.ders} - Çözüm"),
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Color(0xFFFF334B)),
                          tooltip: "Sil",
                          onPressed: () => onSoruSilindi(s.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class SoruEkleSayfasi extends StatefulWidget {
  final List<String> dersler;
  final bool isDarkMode;

  const SoruEkleSayfasi(
      {super.key, required this.dersler, required this.isDarkMode});

  @override
  State<SoruEkleSayfasi> createState() => _SoruEkleSayfasiState();
}

class _SoruEkleSayfasiState extends State<SoruEkleSayfasi> {
  String? _secilenDers;
  final TextEditingController _konuController = TextEditingController();
  String? _soruBase64;
  String? _cozumBase64;

  @override
  void initState() {
    super.initState();
    if (widget.dersler.isNotEmpty) {
      _secilenDers = widget.dersler.first;
    }
  }

  Future<void> _resimSec(bool soruMu) async {
    final picker = ImagePicker();
    final resim =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (resim != null) {
      final bytes = await resim.readAsBytes();
      setState(() {
        if (soruMu) {
          _soruBase64 = base64Encode(bytes);
        } else {
          _cozumBase64 = base64Encode(bytes);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF030712) : Colors.white,
      appBar: AppBar(
        title: const Text("Yeni Yanlış Soru Ekle"),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _secilenDers,
              dropdownColor:
                  widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
              items: widget.dersler
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (val) => setState(() => _secilenDers = val),
              decoration: InputDecoration(
                  labelText: "Ders Seçin",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _konuController,
              decoration: InputDecoration(
                  labelText: "Konu (Örn: Türev, Newton Kanunları)",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  foregroundColor: Colors.black),
              icon: const Icon(Icons.camera_alt),
              label: Text(_soruBase64 == null
                  ? "Soru Fotoğrafı Yükle"
                  : "Soru Fotoğrafı Değiştir"),
              onPressed: () => _resimSec(true),
            ),
            if (_soruBase64 != null) ...[
              const SizedBox(height: 8),
              const Text("Soru resmi başarıyla eklendi!",
                  style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  foregroundColor: Colors.black),
              icon: const Icon(Icons.image),
              label: Text(_cozumBase64 == null
                  ? "Çözüm Fotoğrafı Yükle (İsteğe Bağlı)"
                  : "Çözüm Fotoğrafı Değiştir"),
              onPressed: () => _resimSec(false),
            ),
            if (_cozumBase64 != null) ...[
              const SizedBox(height: 8),
              const Text("Çözüm resmi başarıyla eklendi!",
                  style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF334B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("KAYDET VE EKLE",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: () {
                  if (_secilenDers != null && _soruBase64 != null) {
                    final yeniSoru = SoruModel(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      ders: _secilenDers!,
                      konu: _konuController.text.trim().isEmpty
                          ? "Genel"
                          : _konuController.text.trim(),
                      soruResimBase64: _soruBase64!,
                      cozumResimBase64: _cozumBase64,
                      eklenmeTarihi: DateTime.now(),
                    );
                    Navigator.pop(context, yeniSoru);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              "Lütfen ders seçin ve soru fotoğrafı yükleyin!")),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DersSorulariSayfasi extends StatefulWidget {
  final String dersAdi;
  final List<SoruModel> sorular;
  final Function(List<SoruModel>) onSoruGuncellendi;
  final bool isDarkMode;
  final bool isPremium;
  final VoidCallback onPremiumGerekli;

  const DersSorulariSayfasi({
    super.key,
    required this.dersAdi,
    required this.sorular,
    required this.onSoruGuncellendi,
    required this.isDarkMode,
    required this.isPremium,
    required this.onPremiumGerekli,
  });

  @override
  State<DersSorulariSayfasi> createState() => _DersSorulariSayfasiState();
}

class _DersSorulariSayfasiState extends State<DersSorulariSayfasi> {
  Future<void> _aiIpucuGoster(SoruModel soru) async {
    if (!widget.isPremium) {
      widget.onPremiumGerekli();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        backgroundColor: Color(0xFF0F172A),
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFFA855F7)),
            SizedBox(width: 20),
            Text("Gemini AI soruyu inceliyor... 🤖",
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );

    String? aiYanit;
    Object? hata;
    try {
      final aiService = GeminiYksService();
      aiYanit = await aiService.ask(
        prompt:
            'Bu YKS sorusunu incele. Ders: ${soru.ders}. Konu: ${soru.konu}. '
            'Öğrenciye soruyu çözdürmeden ana mantığı, püf noktalarını ve '
            'izlemesi gereken adımları içeren kısa, anlaşılır ve motive edici bir ipucu ver.',
        imageBytes: soru.soruResimBase64.isNotEmpty
            ? base64Decode(soru.soruResimBase64)
            : null,
        imageMimeType: 'image/jpeg',
      );
    } catch (e) {
      hata = e;
    } finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }

    if (mounted) {
      _aiSonucDialogGoster(
        soru,
        hata != null
            ? 'Bağlantı hatası oluştu. İnternet bağlantını veya Gemini API yapılandırmasını kontrol edip tekrar dene.\n\nDetay: ${hata.toString().replaceFirst("StateError: ", "")}'
            : aiYanit ?? 'Bir yanıt alınamadı. Lütfen tekrar dene.',
      );
    }
  }

  void _aiSonucDialogGoster(SoruModel soru, String aiMetin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFA855F7), width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.auto_awesome, color: Color(0xFFA855F7)),
            SizedBox(width: 8),
            Text("Gemini AI Soru Asistanı",
                style: TextStyle(
                    color: Color(0xFFA855F7),
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Ders: ${soru.ders} | Konu: ${soru.konu}",
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF030712),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFA855F7).withOpacity(0.3)),
                ),
                child: Text(
                  aiMetin,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA855F7),
              foregroundColor: Colors.white,
            ),
            child: const Text("Anladım"),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bekleyenler = widget.sorular.where((s) => !s.cozuldu).toList();

    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF030712) : Colors.white,
      appBar: AppBar(
          title: Text("${widget.dersAdi} Yanlışları"),
          backgroundColor: Colors.transparent),
      body: bekleyenler.isEmpty
          ? const Center(
              child: Text(
                  "Bu derste bekleyen yanlış soru yok. Harika gidiyorsun! 🚀",
                  style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bekleyenler.length,
              itemBuilder: (context, index) {
                final soru = bekleyenler[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? const Color(0xFF0F172A)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF00F0FF).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Konu: ${soru.konu}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00F0FF))),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Color(0xFFFF334B), size: 20),
                            onPressed: () {
                              setState(() {
                                widget.sorular
                                    .removeWhere((s) => s.id == soru.id);
                              });
                              widget.onSoruGuncellendi(widget.sorular);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _tamEkranResimGoster(context,
                            soru.soruResimBase64, "${widget.dersAdi} - Soru"),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Image.memory(base64Decode(soru.soruResimBase64),
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover),
                              Container(
                                padding: const EdgeInsets.all(6),
                                color: Colors.black54,
                                child: const Icon(Icons.fullscreen,
                                    color: Color(0xFF00F0FF), size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (soru.cozumResimBase64 != null) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFFD700),
                                  side: BorderSide(
                                      color: const Color(0xFFFFD700)
                                          .withOpacity(0.5)),
                                ),
                                icon: const Icon(Icons.lightbulb, size: 18),
                                label: const Text("Çözüm",
                                    style: TextStyle(fontSize: 12)),
                                onPressed: () => _tamEkranResimGoster(
                                    context,
                                    soru.cozumResimBase64!,
                                    "${widget.dersAdi} - Çözüm"),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFA855F7),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.auto_awesome, size: 18),
                              label: Text(
                                widget.isPremium
                                    ? "AI İpucu Al"
                                    : "AI İpucu (PRO)",
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _aiIpucuGoster(soru),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white),
                          icon: const Icon(Icons.check),
                          label:
                              const Text("Öğrendim / Çözüldü Olarak İşaretle"),
                          onPressed: () {
                            setState(() {
                              soru.cozuldu = true;
                            });
                            widget.onSoruGuncellendi(widget.sorular);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class AnalizSayfasi extends StatelessWidget {
  final List<DenemeModel> denemeler;
  final VoidCallback onDenemeEkleTiklandi;
  final Function(String) onDenemeSilindi;
  final bool isDarkMode;

  const AnalizSayfasi({
    super.key,
    required this.denemeler,
    required this.onDenemeEkleTiklandi,
    required this.onDenemeSilindi,
    required this.isDarkMode,
  });

  void _denemeDetayGoster(BuildContext context, DenemeModel d) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: const Color(0xFF00F0FF).withOpacity(0.4), width: 1.5),
        ),
        title: Text(d.denemeAdi,
            style: const TextStyle(
                color: Color(0xFF00F0FF), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Tarih: ${d.tarih.day}.${d.tarih.month}.${d.tarih.year}",
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const Divider(color: Colors.grey),
            const SizedBox(height: 4),
            Text("📖 Türkçe Net: ${d.turkceNet}",
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 8),
            Text("🌍 Sosyal Net: ${d.sosyalNet}",
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 8),
            Text("📐 Matematik Net: ${d.matNet}",
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 8),
            Text("🧪 Fen Net: ${d.fenNet}",
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            const Divider(color: Colors.grey),
            const SizedBox(height: 4),
            Text("🔥 Toplam Net: ${d.toplamNet}",
                style: const TextStyle(
                    color: Color(0xFF00F0FF),
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF),
                foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context),
            child: const Text("Kapat",
                style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: denemeler.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Henüz deneme sonucu eklenmemiş.",
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00F0FF),
                        foregroundColor: Colors.black),
                    onPressed: onDenemeEkleTiklandi,
                    child: const Text("İlk Denemeyi Ekle"),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: denemeler.length,
              itemBuilder: (context, index) {
                final d = denemeler[index];
                return InkWell(
                  onTap: () => _denemeDetayGoster(context, d),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF00F0FF).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.denemeAdi,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(
                                "Toplam Net: ${d.toplamNet} (Detay için dokun)",
                                style: const TextStyle(
                                    color: Color(0xFF00F0FF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Color(0xFFFF334B)),
                          onPressed: () => onDenemeSilindi(d.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class DenemeEkleSayfasi extends StatefulWidget {
  final bool isDarkMode;
  const DenemeEkleSayfasi({super.key, required this.isDarkMode});

  @override
  State<DenemeEkleSayfasi> createState() => _DenemeEkleSayfasiState();
}

class _DenemeEkleSayfasiState extends State<DenemeEkleSayfasi> {
  final TextEditingController _adController =
      TextEditingController(text: "TYT Genel Deneme");

  final TextEditingController _turkceD = TextEditingController();
  final TextEditingController _turkceY = TextEditingController();

  final TextEditingController _sosyalD = TextEditingController();
  final TextEditingController _sosyalY = TextEditingController();

  final TextEditingController _matD = TextEditingController();
  final TextEditingController _matY = TextEditingController();

  final TextEditingController _fenD = TextEditingController();
  final TextEditingController _fenY = TextEditingController();

  double _netHesapla(TextEditingController dCtrl, TextEditingController yCtrl) {
    double d = double.tryParse(dCtrl.text) ?? 0;
    double y = double.tryParse(yCtrl.text) ?? 0;
    double net = d - (y / 4.0);
    return net < 0 ? 0 : net;
  }

  Widget _dersSatiri(String dersAdi, TextEditingController dCtrl,
      TextEditingController yCtrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(dersAdi,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Expanded(
            child: TextField(
              controller: dCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Doğru",
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: yCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Yanlış",
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text("Net",
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text(
                  _netHesapla(dCtrl, yCtrl).toStringAsFixed(2),
                  style: const TextStyle(
                      color: Color(0xFF00F0FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double tNet = _netHesapla(_turkceD, _turkceY);
    double sNet = _netHesapla(_sosyalD, _sosyalY);
    double mNet = _netHesapla(_matD, _matY);
    double fNet = _netHesapla(_fenD, _fenY);
    double toplamNet = tNet + sNet + mNet + fNet;

    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF030712) : Colors.white,
      appBar: AppBar(
        title: const Text("Deneme Sonucu Ekle"),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _adController,
              decoration: const InputDecoration(
                labelText: "Deneme Adı",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _dersSatiri("Türkçe", _turkceD, _turkceY),
            _dersSatiri("Sosyal", _sosyalD, _sosyalY),
            _dersSatiri("Matematik", _matD, _matY),
            _dersSatiri("Fen", _fenD, _fenY),
            const Divider(color: Colors.grey),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFF00F0FF).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Hesaplanan Toplam Net:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    toplamNet.toStringAsFixed(2),
                    style: const TextStyle(
                        color: Color(0xFF00F0FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  foregroundColor: Colors.black,
                ),
                child: const Text("KAYDET",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: () {
                  final deneme = DenemeModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    denemeAdi: _adController.text,
                    tarih: DateTime.now(),
                    turkceNet: double.parse(tNet.toStringAsFixed(2)),
                    sosyalNet: double.parse(sNet.toStringAsFixed(2)),
                    matNet: double.parse(mNet.toStringAsFixed(2)),
                    fenNet: double.parse(fNet.toStringAsFixed(2)),
                    toplamNet: double.parse(toplamNet.toStringAsFixed(2)),
                  );
                  Navigator.pop(context, deneme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
