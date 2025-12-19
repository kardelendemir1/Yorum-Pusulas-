import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Resim yüklemek için
import 'package:image_picker/image_picker.dart'; // Galeriden seçmek için
import 'package:yorum_pusulas/app_colors.dart';
import 'package:yorum_pusulas/favoriler_sayfasi.dart';
import 'package:yorum_pusulas/yorumlarim_sayfasi.dart';
import 'package:yorum_pusulas/giris_sayfasi.dart';

class ProfilSayfasi extends StatefulWidget {
  const ProfilSayfasi({super.key});

  @override
  State<ProfilSayfasi> createState() => _ProfilSayfasiState();
}

class _ProfilSayfasiState extends State<ProfilSayfasi> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  bool _yukleniyor = false; // Yükleme animasyonu için

  // --- 1. RESİM SEÇ VE YÜKLE ---
  Future<void> _profilResmiDegistir() async {
    // 1. Galeriden resim seç
    final XFile? secilen = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (secilen == null) return;

    setState(() => _yukleniyor = true);

    try {
      File resimDosyasi = File(secilen.path);
      String userId = _auth.currentUser!.uid;

      // 2. Storage'a yükle (profil_resimleri/kullaniciID.jpg olarak)
      Reference ref = _storage.ref().child('profil_resimleri').child('$userId.jpg');
      await ref.putFile(resimDosyasi);

      // 3. Resmin linkini al
      String indirmeLinki = await ref.getDownloadURL();

      // 4. Firestore'a linki kaydet
      await _firestore.collection('kullanicilar').doc(userId).update({
        'profilResmi': indirmeLinki
      });

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil fotoğrafı güncellendi!"), backgroundColor: Colors.green));
        Navigator.pop(context); // Paneli kapat
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _yukleniyor = false);
    }
  }

  // --- 2. ŞİFRE GÜNCELLEME ---
  Future<void> _sifreGuncelle(String yeniSifre) async {
    try {
      await _auth.currentUser!.updatePassword(yeniSifre);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şifreniz başarıyla değiştirildi!"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata: Şifre değişimi için yeniden giriş yapmanız gerekebilir."), backgroundColor: Colors.red));
    }
  }

  // --- 3. MODERN DÜZENLEME PANELİ (BOTTOM SHEET) ---
  void _duzenlemePaneliniAc(String mevcutIsim, String? mevcutBio, String? mevcutResim) {
    TextEditingController isimController = TextEditingController(text: mevcutIsim);
    TextEditingController bioController = TextEditingController(text: mevcutBio ?? "");
    TextEditingController sifreController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Klavye açılınca yukarı kayması için
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85, // Ekranın %85'ini kapla
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Tutamaç Çizgisi
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),

            const Text("Profili Düzenle", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.griYazi)),
            const SizedBox(height: 20),

            Expanded(
              child: ListView(
                children: [
                  // --- FOTOĞRAF ALANI ---
                  Center(
                    child: GestureDetector(
                      onTap: _profilResmiDegistir,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.turkuaz.withOpacity(0.1),
                            backgroundImage: (mevcutResim != null && mevcutResim.isNotEmpty)
                                ? NetworkImage(mevcutResim)
                                : null,
                            child: (mevcutResim == null || mevcutResim.isEmpty)
                                ? const Icon(Icons.person, size: 50, color: AppColors.turkuaz)
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: AppColors.turkuaz, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(child: Text("Fotoğrafı Değiştir", style: TextStyle(color: AppColors.turkuaz, fontWeight: FontWeight.bold))),

                  const SizedBox(height: 30),

                  // --- İSİM ALANI ---
                  TextField(
                    controller: isimController,
                    decoration: InputDecoration(
                        labelText: "Kullanıcı Adı",
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        filled: true, fillColor: Colors.grey.shade50
                    ),
                  ),
                  const SizedBox(height: 15),

                  // --- BİO (HAKKIMDA) ALANI ---
                  TextField(
                    controller: bioController,
                    maxLines: 3,
                    decoration: InputDecoration(
                        labelText: "Hakkımda / Bio",
                        alignLabelWithHint: true,
                        prefixIcon: const Icon(Icons.info_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        filled: true, fillColor: Colors.grey.shade50
                    ),
                  ),
                  const SizedBox(height: 30),

                  const Divider(),
                  const Text("Güvenlik", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 15),

                  // --- ŞİFRE DEĞİŞTİRME ---
                  TextField(
                    controller: sifreController,
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: "Yeni Şifre (İsteğe Bağlı)",
                        helperText: "Değiştirmek istemiyorsanız boş bırakın",
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        filled: true, fillColor: Colors.grey.shade50
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- KAYDET BUTONU ---
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.turkuaz,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5
                      ),
                      onPressed: () async {
                        setState(() => _yukleniyor = true);

                        try {
                          // 1. Bilgileri Güncelle
                          await _firestore.collection('kullanicilar').doc(_auth.currentUser!.uid).update({
                            'kullaniciAdi': isimController.text.trim(),
                            'bio': bioController.text.trim(),
                          });

                          // 2. Şifre Doluysa Güncelle
                          if (sifreController.text.isNotEmpty) {
                            if (sifreController.text.length >= 6) {
                              await _sifreGuncelle(sifreController.text.trim());
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şifre en az 6 karakter olmalı.")));
                            }
                          }

                          if(mounted) {
                            Navigator.pop(context); // Kapat
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil kaydedildi! ✅"), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
                        } finally {
                          if(mounted) setState(() => _yukleniyor = false);
                        }
                      },
                      child: _yukleniyor
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Değişiklikleri Kaydet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20), // Klavye payı
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    if (user == null) return const Center(child: Text("Giriş yapılmamış"));

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('kullanicilar').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        String kullaniciAdi = user.email!.split('@')[0];
        String? bio;
        String? profilResmi;

        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          kullaniciAdi = data['kullaniciAdi'] ?? kullaniciAdi;
          bio = data['bio'];
          profilResmi = data['profilResmi'];
        }

        return Scaffold(
          backgroundColor: AppColors.arkaPlan,
          body: SingleChildScrollView(
            child: Column(
              children: [
                // --- ÜST KISIM (GRADYAN & AVATAR) ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 60, bottom: 30),
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [AppColors.turkuaz, AppColors.softPembe],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.white,
                          backgroundImage: (profilResmi != null) ? NetworkImage(profilResmi) : null,
                          child: (profilResmi == null) ? const Icon(Icons.person, size: 50, color: AppColors.turkuaz) : null,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(kullaniciAdi, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      if (bio != null && bio.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(bio, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ),
                      const SizedBox(height: 5),
                      Text(user.email ?? "", style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),

                // --- MENÜLER ---
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // PROFİL DÜZENLEME BUTONU (Artık Bottom Sheet Açıyor)
                      _menuOgesi(
                        icon: Icons.edit,
                        text: "Profili Düzenle",
                        aciklama: "Fotoğraf, isim, şifre...",
                        onTap: () => _duzenlemePaneliniAc(kullaniciAdi, bio, profilResmi),
                      ),
                      const SizedBox(height: 15),
                      _menuOgesi(icon: Icons.favorite, text: "Favorilerim", renk: Colors.redAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FavorilerSayfasi()))),
                      const SizedBox(height: 15),
                      _menuOgesi(icon: Icons.comment, text: "Yorumlarım", renk: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const YorumlarimSayfasi()))),
                      const SizedBox(height: 15),
                      _menuOgesi(icon: Icons.logout, text: "Çıkış Yap", renk: Colors.grey, onTap: () async { await _auth.signOut(); if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const GirisSayfasi())); }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuOgesi({required IconData icon, required String text, String? aciklama, required VoidCallback onTap, Color renk = AppColors.turkuazKoyu}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: renk.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: renk)),
        title: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: aciklama != null ? Text(aciklama, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey.shade300),
        onTap: onTap,
      ),
    );
  }
}