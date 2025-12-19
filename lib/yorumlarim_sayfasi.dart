import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yorum_pusulas/app_colors.dart';
import 'package:yorum_pusulas/urun_detay_sayfasi.dart';

class YorumlarimSayfasi extends StatelessWidget {
  const YorumlarimSayfasi({super.key});

  // Ürün adına göre sabit bir renk üreten fonksiyon
  Color _urunRengiVer(String urunAdi) {
    List<Color> renkler = [
      Colors.blueAccent, Colors.redAccent, Colors.orangeAccent,
      Colors.purpleAccent, Colors.teal, Colors.pinkAccent,
      Colors.indigoAccent, Colors.green
    ];
    return renkler[urunAdi.length % renkler.length];
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Değerlendirmelerim",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('userId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.turkuaz));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.turkuaz.withOpacity(0.2), blurRadius: 20)],
                    ),
                    child: Icon(Icons.rate_review_outlined, size: 60, color: AppColors.turkuaz.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Henüz renkli dünyana\nbir yorum katmadın!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          // Sıralama
          var docs = snapshot.data!.docs;
          docs.sort((a, b) {
            var aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            var bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var yorumDoc = docs[index];
              var data = yorumDoc.data() as Map<String, dynamic>;

              String urunAdi = data['productName'] ?? "Ürün Adı Yok";
              String yorumMetni = data['reviewText'] ?? "";
              String resimUrl = data['imageUrl'] ?? "";
              String urunId = data['productId'] ?? "";
              int puan = data['rating'] ?? 0;

              // Her ürüne özel canlı renk
              Color temaRengi = _urunRengiVer(urunAdi);

              String tarih = "Tarih yok";
              if (data['createdAt'] != null) {
                DateTime dt = (data['createdAt'] as Timestamp).toDate();
                tarih = "${dt.day}.${dt.month}.${dt.year}";
              }

              return Dismissible(
                key: Key(yorumDoc.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.redAccent, Colors.red]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10)]
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text("Siliniyor", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      SizedBox(width: 10),
                      Icon(Icons.delete_outline, color: Colors.white),
                    ],
                  ),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      title: const Text("Yorumu Sil"),
                      content: const Text("Bu renkli anıyı silmek istediğine emin misin?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç", style: TextStyle(color: Colors.grey))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sil", style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) {
                  yorumDoc.reference.delete();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Yorum silindi."), backgroundColor: temaRengi));
                },
                child: GestureDetector(
                  onTap: () {
                    if (urunId.isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => UrunDetaySayfasi(urunId: urunId)));
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: temaRengi.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // --- SOL TARAFTAKİ RENKLİ ŞERİT ---
                            Container(width: 8, color: temaRengi),

                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // --- ÜRÜN RESMİ VEYA AVATARI ---
                                    Container(
                                      width: 75,
                                      height: 75,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(15),
                                        color: temaRengi.withOpacity(0.1), // Resim yoksa arkası renkli
                                        image: resimUrl.isNotEmpty
                                            ? DecorationImage(image: NetworkImage(resimUrl), fit: BoxFit.cover)
                                            : null,
                                      ),
                                      child: resimUrl.isEmpty
                                          ? Center(child: Text(urunAdi[0].toUpperCase(), style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: temaRengi)))
                                          : null,
                                    ),

                                    const SizedBox(width: 15),

                                    // --- BİLGİLER ---
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Başlık ve Tarih Rozeti
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  urunAdi,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.griYazi),
                                                ),
                                              ),
                                              // Renkli Tarih Kutusu
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: temaRengi.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(tarih, style: TextStyle(fontSize: 10, color: temaRengi, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),

                                          // Yıldızlar
                                          Row(
                                            children: List.generate(5, (index) => Icon(
                                                index < puan ? Icons.star_rounded : Icons.star_outline_rounded,
                                                size: 16,
                                                color: index < puan ? Colors.amber : Colors.grey.shade300
                                            )),
                                          ),

                                          const SizedBox(height: 8),

                                          // Yorum Metni
                                          Text(
                                            yorumMetni,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}