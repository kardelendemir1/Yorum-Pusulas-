/* -----------------------------------------------------------------------------
  GEREKLİ KÜTÜPHANELERİ (ALET ÇANTALARINI) İÇE AKTARMA (import)
  -----------------------------------------------------------------------------
*/

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yorum_pusulas/app_colors.dart'; // Renkler için eklendi

/*
  -----------------------------------------------------------------------------
  KAYIT SAYFASININ İSKELETİ (StatefulWidget)
  -----------------------------------------------------------------------------
*/
class KayitSayfasi extends StatefulWidget {
  const KayitSayfasi({super.key});

  @override
  State<KayitSayfasi> createState() => _KayitSayfasiState();
}

/*
  -----------------------------------------------------------------------------
  KAYIT SAYFASININ BEYNİ (State Sınıfı)
  -----------------------------------------------------------------------------
*/
class _KayitSayfasiState extends State<KayitSayfasi> {
  /*
    DEĞİŞKENLER (Variables)
    -----------------------
  */
  final TextEditingController _isimSoyisimController = TextEditingController();
  final TextEditingController _kullaniciAdiController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _mesajGoster(String mesaj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj)));
  }

  /*
    ANA FONKSİYON: KAYIT OLMA (Core Logic)
    ---------------------------------
  */
  Future<void> _kayitOl() async {
    // --- BÖLÜM 1: DOĞRULAMA (Validation) ---
    if (_isimSoyisimController.text.isEmpty ||
        _kullaniciAdiController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _passwordConfirmController.text.isEmpty) {
      _mesajGoster("Lütfen tüm zorunlu alanları doldurun.");
      return;
    }

    if (_passwordController.text != _passwordConfirmController.text) {
      _mesajGoster("Girdiğiniz şifreler eşleşmiyor.");
      return;
    }

    // --- BÖLÜM 2: FIREBASE İŞLEMLERİ (Güvenlik Ağı) ---
    try {
      final kullaniciAdi = _kullaniciAdiController.text.trim();

      final querySnapshot = await _firestore
          .collection('kullanicilar')
          .where('kullaniciAdi', isEqualTo: kullaniciAdi)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        _mesajGoster("Bu kullanıcı adı zaten alınmış. Lütfen başka bir tane deneyin.");
        return;
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        await _firestore.collection('kullanicilar').doc(user.uid).set({
          'isimSoyisim': _isimSoyisimController.text.trim(),
          'kullaniciAdi': kullaniciAdi,
          'email': user.email,
          'telefon': _telefonController.text.trim(),
          'olusturmaTarihi': Timestamp.now(),
        });

        await user.sendEmailVerification();

        _mesajGoster("Kayıt başarılı! Lütfen e-postanızı kontrol ederek hesabınızı doğrulayın.");

        if (mounted) Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      _mesajGoster("Kayıt başarısız: ${e.message}");
    }
  }

  /*
    ANA ARAYÜZ (UI) OLUŞTURMA FONKSİYONU
    ---------------------------------
  */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar'ı şeffaf yaparak gradyanın arkadan devam etmesini sağlıyoruz
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // Profil sayfanızdaki renk geçişi
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF38A3A5), // Turkuaz
              Color(0xFFE29587), // Pembe/Şeftali
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 80.0),
            child: Column(
              children: [
                const Text(
                  "Yeni Hesap",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                // --- KAYIT FORMU (ŞEFFAF BEYAZ KART) ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9), // Hafif şeffaf kart
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTextField(_isimSoyisimController, 'İsim Soyisim', Icons.person),
                      const SizedBox(height: 12),
                      _buildTextField(_kullaniciAdiController, 'Kullanıcı Adı', Icons.account_circle),
                      const SizedBox(height: 12),
                      _buildTextField(_emailController, 'E-posta', Icons.email, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 12),
                      _buildTextField(_telefonController, 'Telefon (İsteğe Bağlı)', Icons.phone, keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      _buildTextField(_passwordController, 'Şifre', Icons.lock, obscureText: true),
                      const SizedBox(height: 12),
                      _buildTextField(_passwordConfirmController, 'Şifre Tekrar', Icons.lock_outline, obscureText: true),
                      const SizedBox(height: 25),
                      // --- HESAP OLUŞTUR BUTONU ---
                      ElevatedButton(
                        onPressed: _kayitOl,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38A3A5),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          'HESAP OLUŞTUR',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    );
  }

  // Ortak TextField Tasarımı
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscureText = false, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF38A3A5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }
}