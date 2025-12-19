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
      backgroundColor: AppColors.arkaPlan, // Genel arka plan rengi
      appBar: AppBar(
        title: const Text(
          'Giriş Yap',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.turkuaz,
        foregroundColor: AppColors.beyaz,
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- E-POSTA METİN KUTUSU ---
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'E-posta',
                filled: true,
                fillColor: AppColors.beyaz,
                prefixIcon: Icon(Icons.email, color: AppColors.turkuazKoyu),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: AppColors.turkuaz,
                    width: 2.0,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Colors.grey[300]!,
                  ),
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
                filled: true,
                fillColor: AppColors.beyaz,
                prefixIcon: Icon(Icons.lock, color: AppColors.turkuazKoyu),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: AppColors.turkuaz,
                    width: 2.0,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Colors.grey[300]!,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- GİRİŞ YAP BUTONU ---
            ElevatedButton(
              onPressed: _girisYap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.turkuaz,
                foregroundColor: AppColors.beyaz,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Giriş Yap',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            // --- YENİ HESAP OLUŞTUR BUTONU ---
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const KayitSayfasi()),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.softPembeKoyu, // Soft pembe rengi kullanıldı
              ),
              child: const Text('Hesabın yok mu? Yeni Hesap Oluştur'),
            ),

            // --- ŞİFREMİ UNUTTUM BUTONU ---
            TextButton(
              onPressed: _sifremiUnuttum,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: const Text('Şifremi Unuttum'),
            ),
          ],
        ),
      ),
    );
  }
}