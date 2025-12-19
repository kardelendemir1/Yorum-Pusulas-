import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yorum_pusulas/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class UrunDetaySayfasi extends StatefulWidget {
  final String urunId;
  const UrunDetaySayfasi({super.key, required this.urunId});

  @override
  State<UrunDetaySayfasi> createState() => _UrunDetaySayfasiState();
}

class _UrunDetaySayfasiState extends State<UrunDetaySayfasi> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _yorumController = TextEditingController();
  int _secilenPuan = 0;
  bool _yukleniyor = false;

  Future<void> _disPlatformdaAra(String platformAdi, String urunAdi) async {
    String url = "";
    if (platformAdi == "Google") url = "https://www.google.com/search?q=$urunAdi yorumları";
    else if (platformAdi == "Trendyol") url = "https://www.trendyol.com/sr?q=$urunAdi";
    else if (platformAdi == "YouTube") url = "https://www.youtube.com/results?search_query=$urunAdi inceleme";

    final Uri uri = Uri.parse(Uri.encodeFull(url));
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (e) { debugPrint("Hata: $e"); }
  }

  Future<void> _yorumYap(String urunAdi, String resimLinki) async {
    if (_yorumController.text.isEmpty || _secilenPuan == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen puan verip yorum yazın.")));
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final user = _auth.currentUser!;
      await FirebaseFirestore.instance.collection('urunler').doc(widget.urunId).collection('yorumlar').add({
        'yorum': _yorumController.text.trim(), 'puan': _secilenPuan, 'kullaniciId': user.uid, 'kullaniciEmail': user.email, 'tarih': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('reviews').add({
        'userId': user.uid, 'productId': widget.urunId, 'productName': urunAdi, 'imageUrl': resimLinki, 'reviewText': _yorumController.text.trim(), 'rating': _secilenPuan, 'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('urunler').doc(widget.urunId).update({'toplamOySayisi': FieldValue.increment(1)});

      _yorumController.clear();
      setState(() { _secilenPuan = 0; _yukleniyor = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yorumunuz eklendi!"), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _yukleniyor = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context))),
      extendBodyBehindAppBar: true,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('urunler').doc(widget.urunId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator(color: AppColors.turkuaz));
          var data = snapshot.data!.data() as Map<String, dynamic>;
          return SingleChildScrollView(
            child: Column(children: [
              SizedBox(height: 300, width: double.infinity, child: Image.network(data['resimLinki'] ?? "", fit: BoxFit.cover, errorBuilder: (c,o,s)=>const Icon(Icons.image))),
              Padding(padding: const EdgeInsets.all(20), child: Column(children: [
                Text(data['urunAdi'] ?? "", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(data['aciklama'] ?? ""),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  ElevatedButton(onPressed: () => _disPlatformdaAra("Google", data['urunAdi']), child: const Text("Google")),
                  ElevatedButton(onPressed: () => _disPlatformdaAra("Trendyol", data['urunAdi']), child: const Text("Trendyol")),
                ]),
                const Divider(height: 40),
                const Text("Yorum Yap", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(icon: Icon(i < _secilenPuan ? Icons.star : Icons.star_border, color: Colors.amber), onPressed: () => setState(() => _secilenPuan = i + 1)))),
                TextField(controller: _yorumController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Yorumunuz...")),
                ElevatedButton(onPressed: _yukleniyor ? null : () => _yorumYap(data['urunAdi'], data['resimLinki']), child: const Text("Gönder"))
              ]))
            ]),
          );
        },
      ),
    );
  }
}