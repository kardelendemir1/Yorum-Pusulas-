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
import 'package:google_generative_ai/google_generative_ai.dart';

import 'package:yorum_pusulas/firebase_options.dart';
import 'package:yorum_pusulas/giris_sayfasi.dart';
import 'package:yorum_pusulas/profil_sayfasi.dart';
import 'package:yorum_pusulas/urun_ekle_sayfasi.dart';
import 'package:yorum_pusulas/app_colors.dart';

// --- İŞTE BU EKSİKTİ, EKLENDİ! ARTIK HATA VERMEYECEK ---
import 'package:yorum_pusulas/urun_detay_sayfasi.dart';
// ------------------------------------------------------

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

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  // --- ANAHTARLAR ---
  final String _googleSearchApiKey = "AIzaSyD28pwVU7m49tZ8IB_wqvVtLdlNqcExSys";
  final String _searchEngineId = "714dd38dae5c64ae0";
  final String _geminiApiKey = "AIzaSyA6MMBjLPhEGPHd469huG5BH3FaFxq-D7g";
  // ------------------

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _sonucListesi = [];
  bool _aramaYapiliyor = false;
  String _durumMesaji = "";

  @override
  void initState() {
    super.initState();
    _firebasePopulerUrunleriGetir();
  }

  Future<void> _firebasePopulerUrunleriGetir() async {
    var snapshot = await FirebaseFirestore.instance.collection('urunler').orderBy('eklenmeTarihi', descending: true).limit(10).get();
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
    setState(() { _sonucListesi = gecici; });
  }

  // --- AKILLI ARAMA ---
  Future<void> _akilliAramaYap(String kelime) async {
    if (kelime.isEmpty) { _firebasePopulerUrunleriGetir(); return; }

    setState(() {
      _aramaYapiliyor = true;
      _sonucListesi = [];
      _durumMesaji = "Web taranıyor...";
    });

    try {
      // 1. Firebase Arama
      var snap = await FirebaseFirestore.instance.collection('urunler').get();
      var firebaseList = snap.docs.where((d) => d['urunAdi'].toString().toLowerCase().contains(kelime.toLowerCase())).map((d) =>
      {'type': 'firebase', 'id': d.id, 'title': d['urunAdi'], 'image': d['resimLinki'], 'rating': (d['ortalamaPuan']??0).toDouble(), 'category': d['kategori']}
      ).toList();

      // 2. Google Search
      List<Map<String, String>> hamWebSonuclari = [];
      final HttpClient httpClient = HttpClient();
      final Uri uri = Uri.parse('https://www.googleapis.com/customsearch/v1?key=$_googleSearchApiKey&cx=$_searchEngineId&q=$kelime&num=10');

      final HttpClientRequest request = await httpClient.getUrl(uri);
      final HttpClientResponse response = await request.close();

      if (response.statusCode == 200) {
        final String body = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = json.decode(body);
        if (data['items'] != null) {
          for (var item in data['items']) {
            String? resim;
            if (item['pagemap'] != null && item['pagemap']['cse_image'] != null) {
              resim = item['pagemap']['cse_image'][0]['src'];
            }
            if (resim != null) {
              hamWebSonuclari.add({
                'title': item['title'],
                'link': item['link'],
                'image': resim,
                'source': item['displayLink'] ?? 'Web'
              });
            }
          }
        }
      }

      // 3. Gemini AI
      List<Map<String, dynamic>> aiListesi = [];
      if (hamWebSonuclari.isNotEmpty) {
        setState(() { _durumMesaji = "Yapay Zeka analiz ediyor... 🧠"; });

        final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _geminiApiKey);
        final prompt = Content.text('''
          Aşağıdaki JSON listesinde ürünler var.
          GÖREV:
          1. Aynı olan ürünleri tekilleştir.
          2. Sadece BENZERSİZ modelleri listele.
          3. Kaynak linkini koru.
          
          GİRDİ: ${jsonEncode(hamWebSonuclari)}

          ÇIKTI (JSON Array):
          [{"title": "Ürün Adı", "image": "url", "link": "url", "source": "Web"}]
        ''');

        final aiResponse = await model.generateContent([prompt]);
        String? temizJson = aiResponse.text?.replaceAll('```json', '').replaceAll('```', '').trim();

        if (temizJson != null) {
          try {
            List<dynamic> decoded = jsonDecode(temizJson);
            for (var item in decoded) {
              aiListesi.add({
                'type': 'google',
                'title': item['title'],
                'image': item['image'],
                'link': item['link'],
                'source': 'AI Sonucu'
              });
            }
          } catch (e) {
            for(var ham in hamWebSonuclari) {
              aiListesi.add({'type': 'google', 'title': ham['title'], 'image': ham['image'], 'link': ham['link'], 'source': ham['source']});
            }
          }
        }
      }
      setState(() { _sonucListesi = [...firebaseList, ...aiListesi]; });

    } catch (e) { print(e); }
    finally { if (mounted) setState(() => _aramaYapiliyor = false); }
  }

  // --- GELİŞMİŞ SEÇİM MENÜSÜ ---
  void _webUrunuSecenekleri(Map<String, dynamic> urun) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(urun['image'], width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c,o,s)=>const Icon(Icons.image, size: 50, color: Colors.grey)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(urun['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 5),
                      const Text("Bu ürün için ne yapmak istersin?", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            const Text("Sadece Yorumlara Göz At 🌍", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.griYazi)),
            const SizedBox(height: 10),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.link, color: Colors.blue)),
              title: const Text("Bulunan Kaynağa Git"),
              subtitle: Text(urun['link'], maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              onTap: () async {
                Navigator.pop(ctx);
                final Uri url = Uri.parse(urun['link']);
                await launchUrl(url, mode: LaunchMode.externalApplication);
              },
            ),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.orange),
                    label: const Text("Trendyol", style: TextStyle(color: Colors.orange, fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _disPlatformdaAra("Trendyol", urun['title']);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.search, size: 16, color: Colors.blue),
                    label: const Text("Google", style: TextStyle(color: Colors.blue, fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _disPlatformdaAra("Google", urun['title']);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.turkuaz,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => UrunEkleSayfasi(
                    gelenUrunAdi: urun['title'],
                    gelenResimLinki: urun['image'],
                  )));
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline),
                    SizedBox(width: 10),
                    Text("Uygulamaya Ekle & İlk Yorumu Yap", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _disPlatformdaAra(String platform, String urunAdi) async {
    String url = "";
    if (platform == "Google") url = "https://www.google.com/search?q=$urunAdi yorumları";
    else if (platform == "Trendyol") url = "https://www.trendyol.com/sr?q=$urunAdi";
    final Uri uri = Uri.parse(Uri.encodeFull(url));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // --- GÖRSEL ARAMA ---
  Future<void> _resimIsle(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, imageQuality: 85);
      if (image == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yapay zeka ürünü tarıyor..."), duration: Duration(seconds: 1)));

      final InputImage inputImage = InputImage.fromFile(File(image.path));
      final ImageLabelerOptions options = ImageLabelerOptions(confidenceThreshold: 0.6);
      final ImageLabeler labeler = ImageLabeler(options: options);
      final translator = GoogleTranslator();
      final List<ImageLabel> labels = await labeler.processImage(inputImage);
      labeler.close();

      if (labels.isNotEmpty) {
        String ingilizceTahmin = labels.first.label;
        var ceviri = await translator.translate(ingilizceTahmin, to: 'tr');
        setState(() { _searchController.text = ceviri.text; });
        _akilliAramaYap(ceviri.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bulunan: ${ceviri.text}")));
      }
    } catch (e) { print("Hata: $e"); }
  }

  void _gorselAramaSecimi() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.camera_alt, color: AppColors.turkuaz), title: const Text('Fotoğraf Çek'), onTap: () { Navigator.pop(context); _resimIsle(ImageSource.camera); }),
        ListTile(leading: const Icon(Icons.photo_library, color: Colors.orangeAccent), title: const Text('Galeriden Seç'), onTap: () { Navigator.pop(context); _resimIsle(ImageSource.gallery); }),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.turkuaz, AppColors.softPembe]), borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
            child: Column(children: [
              const Text("Keşfet", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(
                controller: _searchController, onSubmitted: _akilliAramaYap,
                decoration: InputDecoration(
                  hintText: 'Yapay Zeka ile ürün ara...', filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.auto_awesome, color: AppColors.turkuaz),
                  suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => _akilliAramaYap(_searchController.text)),
                ),
              )
            ]),
          ),
          Expanded(
            child: _aramaYapiliyor
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const CircularProgressIndicator(color: AppColors.turkuaz),
              const SizedBox(height: 20),
              Text(_durumMesaji, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
            ]))
                : _sonucListesi.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 60, color: Colors.grey.shade300), const SizedBox(height: 10), const Text("Sonuç bulunamadı.")]))
                : GridView.builder(
              padding: const EdgeInsets.all(15),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.70, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: _sonucListesi.length,
              itemBuilder: (context, index) {
                var item = _sonucListesi[index];
                bool bizdeVar = item['type'] == 'firebase';
                return GestureDetector(
                  onTap: () {
                    if (bizdeVar) Navigator.push(context, MaterialPageRoute(builder: (context) => UrunDetaySayfasi(urunId: item['id'])));
                    else _webUrunuSecenekleri(item);
                  },
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)]),
                    child: Column(children: [
                      Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), child: Image.network(item['image'], fit: BoxFit.cover, width: double.infinity, errorBuilder: (c,o,s)=>const Icon(Icons.image)))),
                      Padding(padding: const EdgeInsets.all(10.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        if (!bizdeVar) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(4)), child: const Text("AI ÖNERİSİ ✨", style: TextStyle(color: Colors.purple, fontSize: 9, fontWeight: FontWeight.bold))),
                      ])),
                    ]),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}