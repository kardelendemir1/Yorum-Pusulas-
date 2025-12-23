import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:yorum_pusulas/app_colors.dart';
import 'package:yorum_pusulas/urun_detay_sayfasi.dart';

// --- YAPAY ZEKA VE ÇEVİRİ PAKETLERİ ---
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:translator/translator.dart';

class UrunEkleSayfasi extends StatefulWidget {
  final String? gelenUrunAdi;
  final String? gelenResimLinki;

  const UrunEkleSayfasi({super.key, this.gelenUrunAdi, this.gelenResimLinki});

  @override
  State<UrunEkleSayfasi> createState() => _UrunEkleSayfasiState();
}

class _UrunEkleSayfasiState extends State<UrunEkleSayfasi> {
  // --- API KEY (Tırnak içinde olmalı) ---
  final String _geminiApiKey = "AIzaSyClYjegxpMQwnoQMYaoAUDOjaZsDIgJ5GU";

  File? _secilenResimDosyasi;
  String? _webResimLinki;
  final ImagePicker _picker = ImagePicker();

  bool _yukleniyor = false;
  bool _analizEdiliyor = false;
  bool _urunSecildi = false;

  int _verilenPuan = 0;

  final TextEditingController _ipucuController = TextEditingController();
  final TextEditingController _urunAdiController = TextEditingController();
  final TextEditingController _aciklamaController = TextEditingController();

  final List<String> _kategoriler = [
    'Elektronik', 'Moda / Giyim', 'Kozmetik', 'Ev & Yaşam',
    'Mutfak Ürünleri', 'Oyun / Teknoloji', 'Kişisel Bakım', 'Kitap / Kırtasiye', 'Yiyecek & İçecek'
  ];
  String? _secilenKategori;

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    if (widget.gelenUrunAdi != null) {
      _urunAdiController.text = widget.gelenUrunAdi!;
      _webResimLinki = widget.gelenResimLinki;
      _urunSecildi = true;
    }
  }

  // --- 1. ADIM: GÖRSELİ ML KIT İLE TANI ---
  Future<void> _resmiOtomatikAnalizEt(File resim) async {
    setState(() => _analizEdiliyor = true);
    try {
      final inputImage = InputImage.fromFile(resim);
      final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.7));
      final List<ImageLabel> labels = await labeler.processImage(inputImage);
      labeler.close();

      if (labels.isNotEmpty) {
        String etiket = labels.first.label; // Örn: "Dalin"

        // İngilizce sonucu Türkçeye çevir
        final translator = GoogleTranslator();
        var ceviri = await translator.translate(etiket, to: 'tr');

        setState(() {
          _ipucuController.text = ceviri.text;
        });

        // --- 2. ADIM: GEMINI 2.5 FLASH SORGUSUNU BAŞLAT ---
        await _geminiVersiyonlariGetir();
      }
    } catch (e) {
      debugPrint("Görsel Analiz Hatası: $e");
    } finally {
      if (mounted) setState(() => _analizEdiliyor = false);
    }
  }

  // --- GEMINI 2.5 FLASH İLE MODEL BELİRLEME ---
  Future<void> _geminiVersiyonlariGetir() async {
    if (_ipucuController.text.trim().isEmpty) return;

    setState(() => _analizEdiliyor = true);

    try {
      final model = GenerativeModel(
          model: 'gemini-2.5-flash', // Senin kodundaki model ismi korundu
          apiKey: _geminiApiKey
      );

      String promptMetni = """
        Sen bir ürün kataloğu asistanısın.
        Görev: '${_ipucuController.text}' ürününe bakarak tam ticari modelleri listele.
        Asla genel isim verme (Örn: 'Şampuan' deme -> 'Dalin Bebek Şampuanı 500ml' de).
        Format: SADECE saf JSON Array olmalı. Markdown kullanma.
        [{"name": "Tam Marka Model Adı", "category": "Kategori", "desc": "Kısa açıklama"}]
      """;

      final response = await model.generateContent([Content.text(promptMetni)]);
      String? temizJson = response.text?.replaceAll('```json', '').replaceAll('```', '').trim();

      if (temizJson != null) {
        List<dynamic> secenekler = jsonDecode(temizJson);
        if (mounted) _versiyonSecimPenceresi(secenekler);
      }
    } catch (e) {
      _mesajGoster("Yapay Zeka Hatası: API Anahtarını kontrol edin");
    } finally {
      if (mounted) setState(() => _analizEdiliyor = false);
    }
  }

  // --- SEÇİM PENCERESİ VE FORM DOLDURMA ---
  void _versiyonSecimPenceresi(List<dynamic> secenekler) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(children: [
          const Text("Ürünü Seçin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          Expanded(child: ListView.builder(
            itemCount: secenekler.length,
            itemBuilder: (c, i) => ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Colors.teal),
              title: Text(secenekler[i]['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(secenekler[i]['desc'] ?? ""),
              onTap: () {
                _formuDoldur(secenekler[i]['name'], secenekler[i]['category'], secenekler[i]['desc']);
                Navigator.pop(ctx);
              },
            ),
          ))
        ]),
      ),
    );
  }

  void _formuDoldur(String ad, String kategori, String aciklama) {
    setState(() {
      _urunAdiController.text = ad;
      _urunSecildi = true;
      if (_aciklamaController.text.isEmpty) _aciklamaController.text = aciklama;
      for (var k in _kategoriler) {
        if (kategori.toLowerCase().contains(k.toLowerCase().split(' ')[0])) {
          _secilenKategori = k;
          break;
        }
      }
    });
  }

  // --- GÖRSEL SEÇİMİ (SEÇİLDİĞİ ANDA ANALİZİ TETİKLER) ---
  Future<void> _resimSec(ImageSource kaynak) async {
    final XFile? resim = await _picker.pickImage(source: kaynak, imageQuality: 80);
    if (resim != null) {
      File resimDosyasi = File(resim.path);
      setState(() {
        _secilenResimDosyasi = resimDosyasi;
        _webResimLinki = null;
        _urunSecildi = false;
        _urunAdiController.clear();
      });
      // Fotoğraf seçildiğinde süreci otomatik başlatır
      await _resmiOtomatikAnalizEt(resimDosyasi);
    }
  }

  // --- KAYIT VE MESAJ FONKSİYONLARI ---
  Future<void> _kaydetButonunaBasildi() async {
    if (!_urunSecildi) {
      _mesajGoster("Lütfen bir ürün modeli seçin.", hata: true);
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      String finalResimLinki = "";
      if (_secilenResimDosyasi != null) {
        String dosyaAdi = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference ref = _storage.ref().child('urun_resimleri').child(dosyaAdi);
        await ref.putFile(_secilenResimDosyasi!);
        finalResimLinki = await ref.getDownloadURL();
      } else if (_webResimLinki != null) {
        finalResimLinki = _webResimLinki!;
      }

      await _firestore.collection('urunler').add({
        'urunAdi': _urunAdiController.text.trim(),
        'aciklama': _aciklamaController.text.trim(),
        'kategori': _secilenKategori ?? 'Diğer',
        'resimLinki': finalResimLinki,
        'ekleyenKullaniciID': _auth.currentUser!.uid,
        'eklenmeTarihi': FieldValue.serverTimestamp(),
        'ortalamaPuan': _verilenPuan.toDouble(),
        'toplamOySayisi': 1,
      });

      _mesajGoster("Ürün başarıyla eklendi!");
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _mesajGoster("Hata: $e", hata: true);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _mesajGoster(String mesaj, {bool hata = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mesaj),
        backgroundColor: hata ? Colors.red : Colors.teal,
        behavior: SnackBarBehavior.floating
    ));
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? arkaPlanResmi;
    if (_secilenResimDosyasi != null) arkaPlanResmi = FileImage(_secilenResimDosyasi!);
    else if (_webResimLinki != null) arkaPlanResmi = NetworkImage(_webResimLinki!);

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Ürün Ekle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(children: [
          GestureDetector(
            onTap: () {
              showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Wrap(children: [
                ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Fotoğraf Çek ve Tanı'), onTap: () { Navigator.pop(ctx); _resimSec(ImageSource.camera); }),
                ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeriden Seç'), onTap: () { Navigator.pop(ctx); _resimSec(ImageSource.gallery); }),
              ])));
            },
            child: Container(
              height: 150, width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300), image: arkaPlanResmi != null ? DecorationImage(image: arkaPlanResmi, fit: BoxFit.contain) : null),
              child: arkaPlanResmi == null ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.camera_enhance, size: 40, color: Colors.teal), Text("FOTOĞRAFLA OTOMATİK TANI")])) : null,
            ),
          ),
          const SizedBox(height: 20),
          TextField(controller: _ipucuController, decoration: const InputDecoration(labelText: 'Ürün Adı (Otomatik Dolar)', border: OutlineInputBorder())),
          if (_analizEdiliyor) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
          const Divider(height: 40),
          TextField(controller: _urunAdiController, readOnly: true, decoration: const InputDecoration(labelText: 'Onaylanan Model', filled: true, border: OutlineInputBorder(), prefixIcon: Icon(Icons.verified, color: Colors.blue))),
          const SizedBox(height: 15),
          DropdownButtonFormField(value: _secilenKategori, items: _kategoriler.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(), onChanged: (v) => setState(() => _secilenKategori = v), decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(icon: Icon(i < _verilenPuan ? Icons.star : Icons.star_border, color: Colors.amber, size: 40), onPressed: () => setState(() => _verilenPuan = i + 1)))),
          const SizedBox(height: 20),
          TextField(controller: _aciklamaController, maxLines: 3, decoration: const InputDecoration(labelText: 'Yorumun', border: OutlineInputBorder())),
          const SizedBox(height: 30),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: (_yukleniyor || !_urunSecildi) ? null : _kaydetButonunaBasildi, style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white), child: _yukleniyor ? const CircularProgressIndicator(color: Colors.white) : const Text("KAYDET"))),
        ]),
      ),
    );
  }
}