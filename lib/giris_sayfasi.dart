/* -----------------------------------------------------------------------------
  GEREKLİ KÜTÜPHELERİ (ALET ÇANTALARINI) İÇE AKTARMA (import)
  -----------------------------------------------------------------------------
*/

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yorum_pusulas/kayit_sayfasi.dart';
import 'package:yorum_pusulas/app_colors.dart'; // Renkler için eklendi

/*
  -----------------------------------------------------------------------------
  GİRİŞ SAYFASININ İSKELETİ (Stateful vs. Stateful)
  -----------------------------------------------------------------------------
*/
class GirisSayfasi extends StatefulWidget {
  const GirisSayfasi({super.key});

  @override
  State<GirisSayfasi> createState() => _GirisSayfasiState();
}

/*
  -----------------------------------------------------------------------------
  GİRİŞ SAYFASININ BEYNİ (State Sınıfı)
  -----------------------------------------------------------------------------
*/
class _GirisSayfasiState extends State<GirisSayfasi> {
  /*
    DEĞİŞKENLER (Variables)
    -----------------------
  */
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /*
    YARDIMCI FONKSİYONLAR (Helper Functions)
    ---------------------------------
  */

  void _mesajGoster(String mesaj) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj)));
  }

  /*
    ANA FONKSİYONLAR (Core Logic)
    -------------------------------
  */

  Future<void> _girisYap() async {
    try {
      FocusScope.of(context).unfocus();
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String hataMesaji = 'E-posta veya şifre yanlış.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        hataMesaji = 'E-posta ya da şifreniz yanlış.';
      } else if (e.code == 'invalid-email') {
        hataMesaji = 'Geçersiz bir e-posta adresi girdiniz.';
      }
      _mesajGoster(hataMesaji);
    } catch (e) {
      _mesajGoster("Beklenmedik bir hata oluştu: $e");
    }
  }

  Future<void> _sifremiUnuttum() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _mesajGoster("Lütfen şifresini unuttuğunuz e-posta adresini girin.");
      return;
    }

    try {
      FocusScope.of(context).unfocus();
      await _auth.sendPasswordResetEmail(email: email);
      _mesajGoster("Şifre sıfırlama linki e-postanıza gönderildi.");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _mesajGoster("Bu e-posta adresi ile kayıtlı bir kullanıcı bulunamadı.");
      } else {
        _mesajGoster("Bir hata oluştu: ${e.message}");
      }
    }
  }

  /*
    ANA ARAYÜZ (UI) OLUŞTURMA FONKSİYONU
    ---------------------------------
  */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar'ı kaldırdık çünkü gradyanın tüm ekranı kaplaması daha şık durur
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              // --- LOGO / İKON ---
              const Icon(Icons.explore_outlined, size: 100, color: Colors.white),
              const SizedBox(height: 15),
              const Text(
                "Yorum Pusulası",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 50),

              // --- FORM ALANI (Hafif Şeffaf Beyaz Kart) ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9), // Gradyanı öldürmeyen hafif şeffaflık
                  borderRadius: BorderRadius.circular(20),
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
                    // --- E-POSTA METİN KUTUSU ---
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: const Icon(Icons.email, color: Color(0xFF38A3A5)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- ŞİFRE METİN KUTUSU ---
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock, color: Color(0xFF38A3A5)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- GİRİŞ YAP BUTONU ---
                    ElevatedButton(
                      onPressed: _girisYap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38A3A5),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Giriş Yap',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- YENİ HESAP OLUŞTUR BUTONU ---
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const KayitSayfasi()),
                  );
                },
                child: const Text(
                  'Hesabın yok mu? Yeni Hesap Oluştur',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),

              // --- ŞİFREMİ UNUTTUM BUTONU ---
              TextButton(
                onPressed: _sifremiUnuttum,
                child: const Text(
                  'Şifremi Unuttum',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}