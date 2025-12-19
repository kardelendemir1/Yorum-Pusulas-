/* -----------------------------------------------------------------------------\
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
      backgroundColor: AppColors.arkaPlan, // Genel arka plan rengi
      appBar: AppBar(
        title: const Text(
          'Yeni Hesap Oluştur',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.turkuaz,
        foregroundColor: AppColors.beyaz,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _isimSoyisimController,
              decoration: InputDecoration(
                labelText: 'İsim Soyisim',
                filled: true,
                fillColor: AppColors.beyaz,
                prefixIcon: Icon(Icons.person, color: AppColors.turkuazKoyu),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.turkuaz, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Colors.grey[300]!,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kullaniciAdiController,
              decoration: InputDecoration(
                labelText: 'Kullanıcı Adı',
                filled: true,
                fillColor: AppColors.beyaz,
                prefixIcon: Icon(Icons.account_circle, color: AppColors.turkuazKoyu),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.turkuaz, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Colors.grey[300]!,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'E-posta',
                filled: true,
                fillColor: AppColors.beyaz,
                prefixIcon: Icon(Icons.email, color: AppColors.turkuazKoyu),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.turkuaz, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Colors.grey[300]!,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telefonController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Telefon Numarası (İsteğe Bağlı)',
                filled: true,
                fillColor: AppColors.beyaz,
                prefixIcon: Icon(Icons.phone, color: AppColors.softPembeKoyu),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.softPembe, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Colors.grey[300]!,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Şifre',
                filled: true,
                fillColor: AppColors.beyaz,
                prefixIcon: Icon(Icons.lock, color: AppColors.turkuazKoyu),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.turkuaz, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(
                    color: Colors.grey[300]!,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordConfirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Şifre Tekrar',
                filled: true,
                fillColor: AppColors.beyaz,
                prefixIcon: Icon(Icons.lock_outline, color: AppColors.turkuazKoyu),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.turkuaz, width: 2),
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
            ElevatedButton(
              onPressed: _kayitOl,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.turkuaz,
                foregroundColor: AppColors.beyaz,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Hesap Oluştur',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}