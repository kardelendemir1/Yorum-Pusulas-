import 'package:yorum_pusulas/servisler/api_servisi.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:translator/translator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yorum_pusulas/firebase_options.dart';
import 'package:yorum_pusulas/giris_sayfasi.dart';
import 'package:yorum_pusulas/profil_sayfasi.dart';
import 'package:yorum_pusulas/urun_ekle_sayfasi.dart';
import 'package:yorum_pusulas/app_colors.dart';
import 'package:yorum_pusulas/urun_detay_sayfasi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yorum Pusulası',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.turkuaz,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.turkuaz),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) return const HomePage();
        return const GirisSayfasi();
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  static final List<Widget> _widgetOptions = <Widget>[
    const DiscoverPage(),
    const UrunEkleSayfasi(),
    const ProfilSayfasi(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Keşfet'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Ekle'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.turkuaz,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

// --- KEŞFET SAYFASI (YENİ TASARIM) ---
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _sonucListesi = [];
  bool _aramaYapiliyor = false;

  @override
  void initState() {
    super.initState();
    _firebasePopulerUrunleriGetir();
  }

  Future<void> _firebasePopulerUrunleriGetir() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('urunler')
        .orderBy('eklenmeTarihi', descending: true)
        .limit(10)
        .get();
    List<Map<String, dynamic>> gecici = [];
    for (var doc in snapshot.docs) {
      gecici.add({
        'type': 'firebase',
        'id': doc.id,
        'title': doc['urunAdi'],
        'image': doc['resimLinki'],
        'rating': (doc['ortalamaPuan'] ?? 0).toDouble(),
        'category': doc['kategori']
      });
    }
    setState(() {
      _sonucListesi = gecici;
    });
  }

  Future<void> _akilliAramaYap(String kelime) async {
    if (kelime.isEmpty) {
      _firebasePopulerUrunleriGetir();
      return;
    }

    setState(() {
      _aramaYapiliyor = true;
      _sonucListesi = [];
    });

    try {
      var snap = await FirebaseFirestore.instance.collection('urunler').get();
      var firebaseList = snap.docs
          .where((d) => d['urunAdi'].toString().toLowerCase().contains(kelime.toLowerCase()))
          .map((d) => {
        'type': 'firebase',
        'id': d.id,
        'title': d['urunAdi'],
        'image': d['resimLinki'],
        'rating': (d['ortalamaPuan'] ?? 0).toDouble(),
        'category': d['kategori']
      }).toList();

      final sonuclar = await Future.wait([
        APIServisi.marketUrunuAra(kelime).catchError((e) => <Map<String, dynamic>>[]),
        APIServisi.makyajUrunuAra(kelime).catchError((e) => <Map<String, dynamic>>[]),
        APIServisi.teknolojiUrunuAra(kelime).catchError((e) => <Map<String, dynamic>>[]),
        APIServisi.yerelCSVVerisiAra(kelime).catchError((e) => <Map<String, dynamic>>[]),
      ]);

      setState(() {
        _sonucListesi = [...firebaseList, ...sonuclar[0], ...sonuclar[1], ...sonuclar[2], ...sonuclar[3]];
      });
    } catch (e) {
      print("Arama Hatası: $e");
    } finally {
      if (mounted) setState(() => _aramaYapiliyor = false);
    }
  }

  Future<void> _resimIsle(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, imageQuality: 85);
      if (image == null) return;

      final InputImage inputImage = InputImage.fromFile(File(image.path));
      final ImageLabeler labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.7));
      final List<ImageLabel> labels = await labeler.processImage(inputImage);
      labeler.close();

      if (labels.isNotEmpty) {
        final translator = GoogleTranslator();
        var ceviri = await translator.translate(labels.first.label, to: 'tr');
        setState(() {
          _searchController.text = ceviri.text;
        });
        _akilliAramaYap(ceviri.text);
      }
    } catch (e) {
      print("Görsel Arama Hatası: $e");
    }
  }

  void _gorselAramaSecimi() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
          child: Wrap(children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Fotoğraf Çek'), onTap: () { Navigator.pop(ctx); _resimIsle(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeriden Seç'), onTap: () { Navigator.pop(ctx); _resimIsle(ImageSource.gallery); }),
          ])),
    );
  }

  void _webUrunuSecenekleri(Map<String, dynamic> urun) async {
    String aciklama = urun['description'] ?? "İnceleme bulunamadı.";
    if (urun['source'] == "Makeup API" && aciklama != "Ürün açıklaması bulunmuyor.") {
      final t = GoogleTranslator();
      var c = await t.translate(aciklama, to: 'tr');
      aciklama = c.text;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(urun['image'], width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c, o, s) => const Icon(Icons.image))),
              const SizedBox(width: 15),
              Expanded(child: Text(urun['title'], style: const TextStyle(fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 15),
            Text(urun['source'] == "Trendyol Veri Seti" ? "💬 Kullanıcı Yorumu:" : "🔍 Ürün Analizi:", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.turkuaz)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.all(12), width: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)), child: Text(aciklama, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87))),
            const SizedBox(height: 20),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.turkuaz, foregroundColor: Colors.white), onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (c) => UrunEkleSayfasi(gelenUrunAdi: urun['title'], gelenResimLinki: urun['image']))); }, child: const Center(child: Text("Sen de Yorum Yap")))
          ],
        ),
      ),
    );
  }

// main.dart içindeki DiscoverPage kısmını şu şekilde güncelleyin:

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // --- PROFİL SAYFASI İLE AYNI GRADYAN (TURKUAZDAN PEMBEYE) ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: const BoxDecoration(
              // Profil sayfanızdaki renk geçişi
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF38A3A5), // Üst sol: Turkuaz tonu
                  Color(0xFFE29587), // Alt sağ: Pembe/Şeftali tonu
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                    "Keşfet",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    )
                ),
                const SizedBox(height: 20),
                // --- ARAMA ÇUBUĞU ---
                TextField(
                  controller: _searchController,
                  onSubmitted: _akilliAramaYap,
                  decoration: InputDecoration(
                    hintText: 'Ürün ara...',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF38A3A5)),
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Color(0xFFE29587)),
                        onPressed: _gorselAramaSecimi
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                )
              ],
            ),
          ),
          // --- ÜRÜN LİSTESİ ---
          Expanded(
            child: _aramaYapiliyor
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF38A3A5)))
                : GridView.builder(
              padding: const EdgeInsets.all(15),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10
              ),
              itemCount: _sonucListesi.length,
              itemBuilder: (ctx, i) {
                var item = _sonucListesi[i];
                bool isFirebase = item['type'] == 'firebase';
                return GestureDetector(
                  onTap: () => isFirebase
                      ? Navigator.push(context, MaterialPageRoute(builder: (c) => UrunDetaySayfasi(urunId: item['id'])))
                      : _webUrunuSecenekleri(item),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Column(children: [
                      Expanded(
                          child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                              child: Image.network(
                                  item['image'],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (c, o, s) => const Icon(Icons.image)
                              )
                          )
                      ),
                      Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                              item['title'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
                          )
                      ),
                    ]),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }}