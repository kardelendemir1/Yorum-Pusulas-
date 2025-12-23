import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

class APIServisi {
  // --- 1. YEREL CSV VERİLERİ (Trendyol, Amazon, Turkish Ecommerce) ---
  static Future<List<Map<String, dynamic>>> yerelCSVVerisiAra(String query) async {
    // Taranacak dosyaların tam listesi
    final List<String> dosyaListesi = [
      'assets/trendyol.csv',
      'assets/Amazon_Reviews.csv',
      'assets/turkish_ecommerce_reviews.csv',
    ];

    List<Map<String, dynamic>> tumSonuclar = [];

    for (String dosyaYolu in dosyaListesi) {
      try {
        final String hamMetin = await rootBundle.loadString(dosyaYolu);

        // CSV Ayırıcı Kontrolü:
        // Genellikle Türkçe setler ';' (noktalı virgül),
        // Amazon gibi global setler ',' (virgül) kullanır.
        String ayirici = dosyaYolu.contains('Amazon') ? ',' : ';';

        final converter = CsvToListConverter(
            fieldDelimiter: ayirici,
            eol: '\n',
            shouldParseNumbers: false
        );

        List<List<dynamic>> satirlar = converter.convert(hamMetin);

        // İlk satırı (başlıklar) atlayıp verileri tarıyoruz
        for (var i = 1; i < satirlar.length; i++) {
          if (satirlar[i].length < 2) continue;

          String urunAdi = satirlar[i][0].toString().toLowerCase();
          String yorum = satirlar[i][1].toString();

          if (urunAdi.contains(query.toLowerCase())) {
            // Kaynak ismini dosya adından türet (Örn: Amazon_Reviews)
            String kaynakIsmi = dosyaYolu.split('/').last.replaceAll('.csv', '');

            tumSonuclar.add({
              'type': 'api',
              'title': satirlar[i][0].toString(),
              'image': "https://via.placeholder.com/150",
              'category': "Kullanıcı Yorumu",
              'source': kaynakIsmi,
              'description': yorum,
            });
          }
        }
      } catch (e) {
        print("$dosyaYolu okunurken hata oluştu: $e");
        // Bir dosya hatalıysa diğerlerine devam etmesi için hata yutulur
        continue;
      }
    }

    // Sonuçları karıştır (farklı kaynaklar harmanlanmış görünsün)
    tumSonuclar.shuffle();
    // Performans için en alakalı ilk 30 sonucu döndür
    return tumSonuclar.take(30).toList();
  }

  // --- 2. MARKET ÜRÜNLERİ (Open Food Facts API) ---
  static Future<List<Map<String, dynamic>>> marketUrunuAra(String query) async {
    final url = Uri.parse(
        'https://tr.openfoodfacts.org/cgi/search.pl?search_terms=$query&search_simple=1&action=process&json=1&page_size=20&fields=product_name_tr,product_name,image_front_url,knowledge_panels,ingredients_text_tr'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> products = data['products'] ?? [];

        return products.map((item) {
          String inceleme = "Ürün besin değerleri ve sağlık standartları açısından incelenmiştir.";
          if (item['ingredients_text_tr'] != null) {
            inceleme = "İçerik Analizi: ${item['ingredients_text_tr']}";
          }

          return {
            'type': 'api',
            'title': item['product_name_tr'] ?? item['product_name'] ?? "Bilinmeyen Ürün",
            'image': item['image_front_url'] ?? "https://via.placeholder.com/150",
            'category': "Gıda / Market",
            'source': "Open Food Facts",
            'description': inceleme
          };
        }).toList();
      }
    } catch (e) {
      print("Market API Hatası: $e");
    }
    return [];
  }

  // --- 3. MAKYAJ ÜRÜNLERİ (Makeup API) ---
  static Future<List<Map<String, dynamic>>> makyajUrunuAra(String query) async {
    final url = Uri.parse('http://makeup-api.herokuapp.com/api/v1/products.json?product_type=$query');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.take(15).map((item) {
          return {
            'type': 'api',
            'title': "${item['brand']?.toString().toUpperCase() ?? 'GENEL'} - ${item['name']}",
            'image': item['image_link'] ?? "https://via.placeholder.com/150",
            'category': "Makyaj / Kozmetik",
            'source': "Makeup API",
            'link': item['product_link'],
            'description': item['description'] ?? "Ürün açıklaması bulunmuyor."
          };
        }).toList();
      }
    } catch (e) {
      print("Makyaj API Hatası: $e");
    }
    return [];
  }

  // --- 4. TEKNOLOJİ ÜRÜNLERİ (Open ICEcat API) ---
  static Future<List<Map<String, dynamic>>> teknolojiUrunuAra(String query) async {
    final url = Uri.parse('https://live.icecat.biz/api/?shopname=openIcecat-live&lang=tr&content=summary&brand=&partnumber=$query');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          var item = data['data'];
          return [{
            'type': 'api',
            'title': "${item['GeneralInfo']['Brand']} - ${item['GeneralInfo']['ProductName']}",
            'image': item['GeneralInfo']['MainImageURL'] ?? "https://via.placeholder.com/150",
            'category': "Teknoloji / Elektronik",
            'source': "Open ICEcat",
            'link': "https://icecat.biz/tr/p/${item['GeneralInfo']['IcecatId']}",
            'description': "Teknik özet ve uzman incelemeleri için kaynağa gidin."
          }];
        }
      }
    } catch (e) {
      print("Teknoloji API Hatası: $e");
    }
    return [];
  }
}