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

class UrunEkleSayfasi extends StatefulWidget {
  final String? gelenUrunAdi;
  final String? gelenResimLinki;

  const UrunEkleSayfasi({super.key, this.gelenUrunAdi, this.gelenResimLinki});

  @override
  State<UrunEkleSayfasi> createState() => _UrunEkleSayfasiState();
}

class _UrunEkleSayfasiState extends State<UrunEkleSayfasi> {
  // --- API KEY ---
  final String _geminiApiKey = "AIzaSyA6MMBjLPhEGPHd469huG5BH3FaFxq-D7g";

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

  void _mesajGoster(String mesaj, {bool hata = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mesaj),
        backgroundColor: hata ? Colors.red : AppColors.turkuaz,
        behavior: SnackBarBehavior.floating
    ));
  }

  // --- GEMINI VERSİYONLARI GETİR ---
  Future<void> _geminiVersiyonlariGetir() async {
    if (_ipucuController.text.trim().isEmpty) {
      _mesajGoster("Lütfen ürünün adını yazın.", hata: true);
      return;
    }

    setState(() => _analizEdiliyor = true);

    try {
      // ---------------------------------------------------------
      // 🛠️ MODEL ADI GÜNCELLENDİ: SİZİN LİSTENİZDEN ALINDI
      // ---------------------------------------------------------
      final model = GenerativeModel(
          model: 'gemini-2.5-flash', // Listenizdeki en stabil ve güçlü model
          apiKey: _geminiApiKey
      );

      String promptMetni = """
        Sen bir ürün kataloğu asistanısın.
        Görev: Kullanıcının girdiği isme (ve varsa fotoğrafa) bakarak, bu ürünün piyasadaki olası Tam Ticari Modellerini listele.
        
        Kullanıcı Girdisi: '${_ipucuController.text}'
        
        Kurallar:
        1. Asla genel isim verme (Örn: 'Telefon' deme -> 'iPhone 13 128GB' de).
        2. Çıktı SADECE aşağıdaki formatta saf bir JSON Array olmalı. Markdown (```json) kullanma.
        
        İstenen JSON Formatı:
        [
          {"name": "Tam Marka Model Adı", "category": "Kategori", "desc": "Kısa açıklama"}
        ]
      """;

      GenerateContentResponse response;

      if (_secilenResimDosyasi != null) {
        final imageBytes = await _secilenResimDosyasi!.readAsBytes();
        final prompt = Content.multi([
          TextPart(promptMetni),
          DataPart('image/jpeg', imageBytes),
        ]);
        response = await model.generateContent([prompt]);
      } else {
        final prompt = Content.text(promptMetni);
        response = await model.generateContent([prompt]);
      }

      String? temizJson = response.text?.replaceAll('```json', '').replaceAll('```', '').trim();

      if (temizJson != null) {
        try {
          List<dynamic> secenekler = jsonDecode(temizJson);
          if (mounted) _versiyonSecimPenceresi(secenekler);
        } catch (e) {
          _mesajGoster("Yapay zeka cevabı anlaşılamadı. Tekrar deneyin.", hata: true);
        }
      }
    } catch (e) {
      print("Hata Detayı: $e");
      String hataMesaji = "Bir hata oluştu.";

      if (e.toString().contains("404") || e.toString().contains("not found")) {
        hataMesaji = "Model bulunamadı (Bölge kısıtlaması olabilir).";
      } else if (e.toString().contains("API_KEY")) {
        hataMesaji = "API Anahtarı geçersiz.";
      }

      _mesajGoster("$hataMesaji ($e)", hata: true);
    } finally {
      if (mounted) setState(() => _analizEdiliyor = false);
    }
  }

  // --- Buradan aşağısı aynı ---
  void _versiyonSecimPenceresi(List<dynamic> secenekler) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Modeli Seçin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.griYazi)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: secenekler.length,
                  itemBuilder: (context, index) {
                    var item = secenekler[index];
                    return Card(
                      elevation: 0,
                      color: AppColors.turkuaz.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.check_circle_outline, color: AppColors.turkuaz),
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(item['desc'] ?? ""),
                        onTap: () {
                          _formuDoldur(item['name'], item['category'], item['desc']);
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
    _mesajGoster("Model seçildi! Şimdi puan verip kaydedin.");
  }

  void _kaynakSecimiGoster() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.camera_alt, color: AppColors.turkuaz), title: const Text('Fotoğraf Çek'), onTap: () { Navigator.pop(context); _resimSec(ImageSource.camera); }),
        ListTile(leading: const Icon(Icons.photo_library, color: Colors.orangeAccent), title: const Text('Galeriden Seç'), onTap: () { Navigator.pop(context); _resimSec(ImageSource.gallery); }),
      ])),
    );
  }

  Future<void> _resimSec(ImageSource kaynak) async {
    final XFile? resim = await _picker.pickImage(source: kaynak, imageQuality: 80);
    if (resim != null) {
      setState(() {
        _secilenResimDosyasi = File(resim.path);
        _webResimLinki = null;
        _urunSecildi = false;
        _urunAdiController.clear();
      });
    }
  }

  Future<void> _kaydetButonunaBasildi() async {
    if (!_urunSecildi || _urunAdiController.text.isEmpty) {
      _mesajGoster("Lütfen önce bir isim yazıp 'Yapay Zeka ile Modeli Seç' deyin.", hata: true);
      return;
    }
    setState(() => _yukleniyor = true);

    try {
      QuerySnapshot tamEslesme = await _firestore.collection('urunler').where('urunAdi', isEqualTo: _urunAdiController.text).get();
      if (tamEslesme.docs.isNotEmpty) {
        var mevcut = tamEslesme.docs.first;
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Bu Ürün Zaten Var!"),
              content: const Text("Bu ürün kataloğumuzda kayıtlı. Oraya gitmek ister misin?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal")),
                ElevatedButton(onPressed: () { Navigator.pop(ctx); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => UrunDetaySayfasi(urunId: mevcut.id))); }, child: const Text("Git")),
              ],
            ),
          );
        }
        setState(() => _yukleniyor = false);
        return;
      }
    } catch (e) { print(e); }

    await _urunEkle();
  }

  Future<void> _urunEkle() async {
    if (_verilenPuan == 0) { _mesajGoster("Lütfen ürüne puan verin.", hata: true); setState(() => _yukleniyor = false); return; }

    String finalResimLinki = "";
    try {
      if (_secilenResimDosyasi != null) {
        String dosyaAdi = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference ref = _storage.ref().child('urun_resimleri').child(dosyaAdi);
        await ref.putFile(_secilenResimDosyasi!);
        finalResimLinki = await ref.getDownloadURL();
      } else if (_webResimLinki != null) {
        finalResimLinki = _webResimLinki!;
      }

      List<String> kelimeler = _urunAdiController.text.toLowerCase().split(' ');
      List<String> anahtarlar = [];
      for(var k in kelimeler) if(k.length>1) anahtarlar.add(k);

      Map<String, dynamic> urunVerisi = {
        'urunAdi': _urunAdiController.text.trim(),
        'aramaAnahtarlari': anahtarlar,
        'aciklama': _aciklamaController.text.trim(),
        'kategori': _secilenKategori ?? 'Diğer',
        'resimLinki': finalResimLinki,
        'ekleyenKullaniciID': _auth.currentUser!.uid,
        'eklenmeTarihi': FieldValue.serverTimestamp(),
        'ilkPuan': _verilenPuan,
        'ortalamaPuan': _verilenPuan.toDouble(),
        'toplamOySayisi': 1,
      };

      DocumentReference docRef = await _firestore.collection('urunler').add(urunVerisi);

      if (_aciklamaController.text.isNotEmpty) {
        await _firestore.collection('urunler').doc(docRef.id).collection('yorumlar').add({
          'yorum': _aciklamaController.text.trim(), 'puan': _verilenPuan, 'kullaniciId': _auth.currentUser!.uid, 'kullaniciEmail': _auth.currentUser!.email, 'tarih': FieldValue.serverTimestamp(),
        });
        await _firestore.collection('reviews').add({
          'userId': _auth.currentUser!.uid, 'productId': docRef.id, 'productName': _urunAdiController.text.trim(), 'imageUrl': finalResimLinki, 'reviewText': _aciklamaController.text.trim(), 'rating': _verilenPuan, 'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _mesajGoster("Ürün başarıyla eklendi!");
      if(mounted) Navigator.pop(context);
    } catch (e) { _mesajGoster("Hata: $e", hata: true); }
    finally { if(mounted) setState(() { _yukleniyor = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? arkaPlanResmi;
    if (_secilenResimDosyasi != null) arkaPlanResmi = FileImage(_secilenResimDosyasi!);
    else if (_webResimLinki != null) arkaPlanResmi = NetworkImage(_webResimLinki!);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Yeni Ürün Ekle'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _kaynakSecimiGoster,
              child: Container(
                height: 150, width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300), image: arkaPlanResmi != null ? DecorationImage(image: arkaPlanResmi, fit: BoxFit.contain) : null),
                child: arkaPlanResmi == null ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_a_photo, size: 40, color: AppColors.turkuaz), Text("Fotoğraf Yükle (İsteğe Bağlı)")])) : null,
              ),
            ),
            const SizedBox(height: 20),
            TextField(controller: _ipucuController, decoration: const InputDecoration(labelText: '1. Adım: Ürün Nedir? (Zorunlu)', hintText: 'Örn: Tenis Raketi', border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: _analizEdiliyor ? null : _geminiVersiyonlariGetir, icon: _analizEdiliyor ? const CircularProgressIndicator() : const Icon(Icons.auto_awesome), label: Text(_analizEdiliyor ? "Aranıyor..." : "2. Adım: Yapay Zeka ile Modeli Seç"))),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            TextField(controller: _urunAdiController, readOnly: true, decoration: const InputDecoration(labelText: 'Seçilen Model (Otomatik)', filled: true, fillColor: Colors.grey, border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
            const SizedBox(height: 15),
            DropdownButtonFormField(value: _secilenKategori, items: _kategoriler.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(), onChanged: (v) => setState(() => _secilenKategori = v), decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(icon: Icon(i < _verilenPuan ? Icons.star : Icons.star_border, color: Colors.amber, size: 40), onPressed: () => setState(() => _verilenPuan = i + 1)))),
            const SizedBox(height: 20),
            TextField(controller: _aciklamaController, maxLines: 3, decoration: const InputDecoration(labelText: 'Yorumun', border: OutlineInputBorder())),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: (_yukleniyor || !_urunSecildi) ? null : _kaydetButonunaBasildi, style: ElevatedButton.styleFrom(backgroundColor: AppColors.turkuaz, foregroundColor: Colors.white), child: _yukleniyor ? const CircularProgressIndicator(color: Colors.white) : const Text("KAYDET"))),
          ],
        ),
      ),
    );
  }
}