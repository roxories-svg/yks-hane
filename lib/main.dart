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
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
              scaffoldBackgroundColor: const Color(0xFF030712),
              primaryColor: const Color(0xFF00F0FF),
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF00F0FF),
                secondary: Color(0xFFFF334B),
                surface: Color(0xFF0F172A),
              ),
              cardColor: const Color(0xFF0F172A),
            )
          : ThemeData.light().copyWith(
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
        eklenmeTarihi: json['eklenmeTarihi'] != null
            ? DateTime.parse(json['eklenmeTarihi'])
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
        tarih: json['tarih'] != null
            ? DateTime.parse(json['tarih'])
            : DateTime.now(),
        turkceNet: (json['turkceNet'] as num?)?.toDouble() ?? 0.0,
        sosyalNet: (json['sosyalNet'] as num?)?.toDouble() ?? 0.0,
        matNet: (json['matNet'] as num?)?.toDouble() ?? 0.0,
        fenNet: (json['fenNet'] as num?)?.toDouble() ?? 0.0,
        toplamNet: (json['toplamNet'] as num?)?.toDouble() ?? 0.0,
      );
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
  String _kullaniciAdi = "Roxories";
  String? _profilResimBase64;
  User? _aktifKullanici;
  bool _isPremium = false;
  bool _basvuruYapildi = false;

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

  @override
  void initState() {
    super.initState();
    _aktifKullanici = FirebaseAuth.instance.currentUser;
    if (_aktifKullanici != null) {
      _kullaniciAdi = _aktifKullanici!.displayName ?? "Öğrenci";
    }
    _verileriYukle();
  }

  Future<void> _apkIndir() async {
    final Uri url = Uri.parse('/app-release.apk');
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
        }
      });

      await _verileriBuluttanYukle();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Google ile başarıyla giriş yapıldı! Hoş geldin $_kullaniciAdi 🚀")),
        );
      }
    } catch (e) {
      debugPrint("Google giriş hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Giriş yapılırken bir hata oluştu: $e")),
        );
      }
    }
  }

  Future<void> _cikisYap() async {
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
    await FirebaseAuth.instance.signOut();
    setState(() {
      _aktifKullanici = null;
      _kullaniciAdi = "Roxories";
      _profilResimBase64 = null;
      _isPremium = false;
      _basvuruYapildi = false;
    });
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hesaptan çıkış yapıldı.")),
      );
    }
  }

  Future<void> _verileriYukle() async {
    try {
      if (_aktifKullanici != null) {
        await _verileriBuluttanYukle();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final kayitliIsim = prefs.getString('kullanici_adi');
      final kayitliProfilBase64 = prefs.getString('profil_resim_base64');
      final kayitliPremium = prefs.getBool('is_premium') ?? false;

      if (kayitliIsim != null && kayitliIsim.trim().isNotEmpty) {
        setState(() {
          _kullaniciAdi = kayitliIsim.trim();
        });
      }
      if (kayitliProfilBase64 != null &&
          kayitliProfilBase64.trim().isNotEmpty) {
        setState(() {
          _profilResimBase64 = kayitliProfilBase64.trim();
        });
      }

      setState(() {
        _isPremium = kayitliPremium;
      });

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
    } catch (e) {
      debugPrint("Veri yükleme hatası: $e");
    }
  }

  Future<void> _verileriBuluttanYukle() async {
    if (_aktifKullanici == null) return;
    try {
      final uid = _aktifKullanici!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          if (data['kullaniciAdi'] != null) {
            _kullaniciAdi = data['kullaniciAdi'];
          }
          if (data['profilResimBase64'] != null) {
            _profilResimBase64 = data['profilResimBase64'];
          }
          if (data['isPremium'] != null) {
            _isPremium = data['isPremium'];
          }
          if (data['basvuruYapildi'] != null) {
            _basvuruYapildi = data['basvuruYapildi'];
          }
          if (data['sorular'] != null) {
            final List list = data['sorular'];
            sorular = list.map((e) => SoruModel.fromJson(e)).toList();
          }
          if (data['denemeler'] != null) {
            final List list = data['denemeler'];
            denemeler = list.map((e) => DenemeModel.fromJson(e)).toList();
          }
        });
      }
    } catch (e) {
      debugPrint("Buluttan veri çekme hatası: $e");
    }
  }

  Future<void> _verileriBulutaKaydet() async {
    try {
      final dataMap = {
        'kullaniciAdi': _kullaniciAdi,
        'profilResimBase64': _profilResimBase64,
        'isPremium': _isPremium,
        'basvuruYapildi': _basvuruYapildi,
        'sorular': sorular.map((e) => e.toJson()).toList(),
        'denemeler': denemeler.map((e) => e.toJson()).toList(),
      };

      if (_aktifKullanici != null) {
        final uid = _aktifKullanici!.uid;
        await FirebaseFirestore.instance
            .collection('kullanicilar')
            .doc(uid)
            .set(dataMap, SetOptions(merge: true));
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('kullanici_adi', _kullaniciAdi);
        await prefs.setBool('is_premium', _isPremium);
        if (_profilResimBase64 != null) {
          await prefs.setString('profil_resim_base64', _profilResimBase64!);
        }
        await prefs.setString('yks_sorular_json',
            jsonEncode(sorular.map((e) => e.toJson()).toList()));
        await prefs.setString('yks_denemeler_json',
            jsonEncode(denemeler.map((e) => e.toJson()).toList()));
      }
    } catch (e) {
      debugPrint("Buluta veri kaydetme hatası: $e");
    }
  }

  Future<void> _premiumBasvurusuGonder() async {
    if (_aktifKullanici == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Başvuru yapabilmek için önce Google ile giriş yapmalısın!"),
          backgroundColor: Color(0xFFFF334B),
        ),
      );
      _profilDuzenleDialog();
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

      await _verileriBulutaKaydet();

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
              "Başvuru isteğin Editör Hasan Hüseyin Serken'e iletildi.\n\n"
              "Kullanıcı ID'n: $uid\n"
              "E-Posta: $email\n\n"
              "Ödeme onaylandıktan sonra Premium paketiniz doğrudan aktif edilecektir!",
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

  Future<void> _profilKaydet(String yeniIsim, String? yeniBase64) async {
    setState(() {
      _kullaniciAdi = yeniIsim;
      if (yeniBase64 != null) {
        _profilResimBase64 = yeniBase64;
      }
    });
    await _verileriBulutaKaydet();
  }

  Future<void> _sorulariKaydet() async {
    await _verileriBulutaKaydet();
  }

  Future<void> _denemeleriKaydet() async {
    await _verileriBulutaKaydet();
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
                fontSize: 18,
              ),
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
            _premiumOzellikSatiri(
                Icons.cloud_sync, "Öncelikli Bulut Senkronizasyon"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF030712),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _premiumAltin.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  if (_aktifKullanici != null) ...[
                    const SizedBox(height: 6),
                    Text(
                        "Kullanıcı ID: ${_aktifKullanici!.uid.substring(0, 8)}...",
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
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

  void _profilDuzenleDialog() {
    final TextEditingController isimController =
        TextEditingController(text: _kullaniciAdi);
    String? secilenYeniBase64 = _profilResimBase64;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor:
              widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _anaTemaMavi.withOpacity(0.4), width: 1.5),
          ),
          title: Text(
            "Profil & Google Kimlik",
            style: TextStyle(
              color: _anaTemaMavi,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_aktifKullanici == null) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Text("G",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4285F4))),
                    label: const Text("Google ile Giriş Yap",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    onPressed: _googleIleGirisYap,
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 8),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.greenAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Oturum Açık:\n${_aktifKullanici?.email ?? ''}",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _vurguKirmizi,
                      side: BorderSide(color: _vurguKirmizi.withOpacity(0.6)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text("Hesaptan Çıkış Yap"),
                    onPressed: _cikisYap,
                  ),
                  const SizedBox(height: 12),
                ],
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final resim = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 500,
                      maxHeight: 500,
                      imageQuality: 65,
                    );
                    if (resim != null) {
                      final bytes = await resim.readAsBytes();
                      setDialogState(() {
                        secilenYeniBase64 = base64Encode(bytes);
                      });
                    }
                  },
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: _anaTemaMavi,
                    backgroundImage: secilenYeniBase64 != null
                        ? MemoryImage(base64Decode(secilenYeniBase64!))
                        : null,
                    child: secilenYeniBase64 == null
                        ? const Icon(Icons.camera_alt,
                            color: Colors.black, size: 28)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                const Text("Avatarı Değiştir",
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 14),
                TextField(
                  controller: isimController,
                  decoration: InputDecoration(
                    labelText: "Kullanıcı Adın",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
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
                backgroundColor: _anaTemaMavi,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("KAYDET",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (isimController.text.trim().isNotEmpty) {
                  await _profilKaydet(
                      isimController.text.trim(), secilenYeniBase64);
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _paylasimEkraniAc() {
    final String sahteLink =
        "https://share.ykshane.app/ogrenci_${DateTime.now().millisecondsSinceEpoch}";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _anaTemaMavi.withOpacity(0.4), width: 1.5),
        ),
        title: Row(
          children: [
            Icon(Icons.share, color: _anaTemaMavi),
            const SizedBox(width: 8),
            const Text("YKS Hane Paylaşım Linki",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                "Bu bağlantıyı paylaşarak çalışmalarını ve netlerini arkadaşlarına gösterebilirsin:",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? const Color(0xFF030712)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _anaTemaMavi.withOpacity(0.4)),
              ),
              child: SelectableText(
                sahteLink,
                style: TextStyle(
                    color: _anaTemaMavi,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Kapat", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _anaTemaMavi,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text("Linki Kopyala",
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: sahteLink));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Paylaşım bağlantısı panoya kopyalandı! 🔗")),
              );
            },
          ),
        ],
      ),
    );
  }

  void _soruEkleEkraniAc() async {
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
      setState(() {
        sorular.add(yeniSoru);
      });
      await _sorulariKaydet();
    }
  }

  void _denemeEkleEkraniAc() async {
    final yeniDeneme = await Navigator.push<DenemeModel>(
      context,
      MaterialPageRoute(
          builder: (_) => DenemeEkleSayfasi(isDarkMode: widget.isDarkMode)),
    );
    if (yeniDeneme != null) {
      setState(() {
        denemeler.add(yeniDeneme);
      });
      await _denemeleriKaydet();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            InkWell(
              onTap: _profilDuzenleDialog,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _anaTemaMavi,
                    backgroundImage: _profilResimBase64 != null
                        ? MemoryImage(base64Decode(_profilResimBase64!))
                        : null,
                    child: _profilResimBase64 == null
                        ? CircleAvatar(
                            radius: 16,
                            backgroundColor: widget.isDarkMode
                                ? const Color(0xFF0F172A)
                                : Colors.grey[200],
                            child: Icon(Icons.person,
                                color: _anaTemaMavi, size: 18),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            _kullaniciAdi,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: widget.isDarkMode
                                    ? Colors.white
                                    : Colors.black87),
                          ),
                          if (_isPremium) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.workspace_premium,
                                color: _premiumAltin, size: 14),
                          ],
                        ],
                      ),
                      Text(
                        _isPremium
                            ? "PREMIUM ÜYE 👑"
                            : _basvuruYapildi
                                ? "BAŞVURU BEKLEMEDE ⏳"
                                : _aktifKullanici != null
                                    ? "Bulut Senkronize"
                                    : "YKS 1.Sİ",
                        style: TextStyle(
                            fontSize: 9,
                            color: _isPremium ? _premiumAltin : _anaTemaMavi,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: _premiumModalGoster,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _premiumAltin.withOpacity(0.3),
                      Colors.orange.withOpacity(0.3)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _premiumAltin, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: _premiumAltin, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _isPremium ? "PRO" : "PREMİUM",
                      style: TextStyle(
                        color: _premiumAltin,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (kIsWeb) ...[
              InkWell(
                onTap: _apkIndir,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFF10B981), width: 1.2),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.android, color: Color(0xFF10B981), size: 15),
                      SizedBox(width: 4),
                      Text(
                        "Mobil İndir",
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: _anaTemaMavi, size: 20),
            onPressed: _paylasimEkraniAc,
            tooltip: "Paylaşım Linki Oluştur",
          ),
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: _anaTemaMavi,
              size: 20,
            ),
            onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
            tooltip: "Tema Değiştir",
          ),
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
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF0F172A),
                                      Color(0xFF1E1B4B),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: _vurguKirmizi.withOpacity(0.8),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _vurguKirmizi.withOpacity(0.35),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                    BoxShadow(
                                      color: _anaTemaMavi.withOpacity(0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: AspectRatio(
                                  aspectRatio: 21 / 9,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.asset(
                                        'assets/banner.png',
                                        fit: BoxFit.cover,
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.black.withOpacity(0.6),
                                              Colors.transparent,
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 16,
                                        bottom: 16,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _vurguKirmizi,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                "YKS 2027 ÖZEL",
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              "Zirveyi Hedefle.",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
                                            await _sorulariKaydet();
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
                            }).toList(),
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
                                    _sorulariKaydet();
                                  },
                                  isDarkMode: widget.isDarkMode,
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 80),
                                child: AnalizSayfasi(
                                  denemeler: denemeler,
                                  onDenemeEkleTiklandi: _denemeEkleEkraniAc,
                                  onDenemeSilindi: (id) {
                                    setState(() {
                                      denemeler.removeWhere((d) => d.id == id);
                                    });
                                    _denemeleriKaydet();
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
                      : _soruEkleEkraniAc,
                  child: Icon(
                    _seciliSekme == 3 ? Icons.add_chart : Icons.add,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
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
                      borderRadius: BorderRadius.circular(10),
                    ),
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

    try {
      const apiKey = "AQ.Ab8RN6KPclBuFtt8C7F1lo71dN5kR7xKs2_5_JPC0w8L2coSmQ";
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {
                  "text":
                      "Sen uzman bir YKS koçu ve öğretmenisin. Bu gönderilen soru fotoğrafını dikkatle incele. Öğrenciye soruyu çözdürmeden, çözümün ana mantığını, dikkat etmesi gereken püf noktalarını ve izlemesi gereken adımları içeren kısa, anlaşılır ve motive edici bir ipucu / rehberlik hazırla."
                },
                {
                  "inline_data": {
                    "mime_type": "image/jpeg",
                    "data": soru.soruResimBase64
                  }
                }
              ]
            }
          ]
        }),
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiYanit = data['candidates']?[0]?['content']?['parts']?[0]
                ?['text'] ??
            "Yapay zekâ yanıt üretemedi.";

        if (mounted) _aiSonucDialogGoster(soru, aiYanit);
      } else {
        if (mounted) {
          _aiSonucDialogGoster(
              soru, "API Bağlantı Hatası: ${response.statusCode}");
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _aiSonucDialogGoster(soru, "Bağlantı hatası oluştu: $e");
      }
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
