import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yorum_pusulas/app_colors.dart';
import 'package:yorum_pusulas/urun_detay_sayfasi.dart';

class FavorilerSayfasi extends StatefulWidget {
  const FavorilerSayfasi({super.key});

  @override
  State<FavorilerSayfasi> createState() => _FavorilerSayfasiState();
}

class _FavorilerSayfasiState extends State<FavorilerSayfasi> {
  String _aramaKelimesi = "";
  String _secilenKategori = "Tümü";
  final TextEditingController _searchController = TextEditingController();

  // Kategori Listesi (Ürün ekle sayfasıyla uyumlu)
  final List<String> _kategoriler = [
    "Tümü",
    "Teknoloji",
    "Giyim & Moda",
    "Kozmetik",
    "Ev & Yaşam",
    "Spor & Outdoor",
    "Kitap & Hobi",
    "Yiyecek & İçecek",
    "Diğer"
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true, // Arka planın en tepeye kadar çıkmasını sağlar
      appBar: AppBar(
        title: const Text(
          "Favori Koleksiyonum",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 22),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // --- ARKA PLAN: RENKLİ GRADIENT ---
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.turkuaz,   // Sol üst turkuaz
              Color(0xFFF8BBD0),   // Sağ alt tatlı pembe
            ],
          ),
        ),
        child: Column(
          children: [
            // AppBar'ın altında kalmasın diye üstten boşluk bırakıyoruz
            SizedBox(height: MediaQuery.of(context).padding.top + 56),

            // --- 1. ARAMA ÇUBUĞU ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _aramaKelimesi = val),
                  decoration: InputDecoration(
                    hintText: 'Favorilerimde ara...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.turkuaz),
                    suffixIcon: _aramaKelimesi.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _aramaKelimesi = "";
                        });
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // --- 2. YATAY KATEGORİ LİSTESİ ---
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _kategoriler.length,
                itemBuilder: (context, index) {
                  String kategori = _kategoriler[index];
                  bool secili = _secilenKategori == kategori;

                  return GestureDetector(
                    onTap: () => setState(() => _secilenKategori = kategori),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: secili ? Colors.white : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: secili ? null : Border.all(color: Colors.white.withOpacity(0.5)),
                      ),
                      child: Center(
                        child: Text(
                          kategori,
                          style: TextStyle(
                            color: secili ? AppColors.turkuaz : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // --- 3. ÜRÜN LİSTESİ (STREAM BUILDER) ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .collection('favoriler')
                    .orderBy('eklenmeTarihi', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Yükleniyor
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }

                  // Veri Yoksa veya Filtre Sonucu Boşsa kontrolü aşağıda yapılacak
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _bosDurumGoster("Henüz favori ürünün yok.");
                  }

                  // --- FİLTRELEME MANTIĞI ---
                  var docs = snapshot.data!.docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String ad = (data['urunAdi'] ?? '').toString().toLowerCase();
                    String kat = (data['kategori'] ?? '').toString();

                    bool aramaUyumu = ad.contains(_aramaKelimesi.toLowerCase());
                    bool kategoriUyumu = _secilenKategori == "Tümü" || kat == _secilenKategori;

                    return aramaUyumu && kategoriUyumu;
                  }).toList();

                  // Filtreleme sonucu boşsa
                  if (docs.isEmpty) {
                    return _bosDurumGoster("Aradığınız kriterde favori yok.");
                  }

                  // --- IZGARA (GRID) GÖRÜNÜMÜ ---
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // Yan yana 2 ürün
                      childAspectRatio: 0.75, // Kart oranı
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var doc = docs[index];
                      var data = doc.data() as Map<String, dynamic>;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => UrunDetaySayfasi(urunId: doc.id)),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // --- RESİM ---
                                  Expanded(
                                    flex: 4,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                      child: data['resimLinki'] != ""
                                          ? Image.network(data['resimLinki'], fit: BoxFit.cover)
                                          : Container(
                                        color: Colors.grey[100],
                                        child: const Icon(Icons.image, color: Colors.grey),
                                      ),
                                    ),
                                  ),

                                  // --- BİLGİ ALANI ---
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            data['urunAdi'] ?? "İsimsiz",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppColors.griYazi,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          // Kategori Etiketi
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.softPembe.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              data['kategori'] ?? "Genel",
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.softPembeKoyu,
                                                  fontWeight: FontWeight.bold
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // --- SİLME BUTONU (Yüzen) ---
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    doc.reference.delete();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("💔 Favorilerden kaldırıldı"),
                                        duration: Duration(milliseconds: 800),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.9),
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                    ),
                                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Boş durum widget'ı
  Widget _bosDurumGoster(String mesaj) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border_rounded, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text(
            mesaj,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}