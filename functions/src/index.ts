import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {ImageAnnotatorClient} from "@google-cloud/vision";

admin.initializeApp();
const visionClient = new ImageAnnotatorClient();

export const urunAnalizEt = onCall(async (request) => {
  // 1. Güvenlik Kontrolü
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Giriş yapmalısınız.");
  }

  const resimBase64 = request.data.resim;
  if (!resimBase64) {
    throw new HttpsError("invalid-argument", "Resim verisi yok.");
  }

  try {
    // 2. Google Vision'a "Web Detection" İsteği (İnterneti Tara)
    const [result] = await visionClient.webDetection({
      image: {content: resimBase64},
    });

    const webDetection = result.webDetection;

    if (webDetection) {
      // --- DEDEKTİF MODU BAŞLIYOR ---

      // A. Hedeflediğimiz Kaliteli Siteler (Türkiye Odaklı)
      const hedefSiteler = [
        "trendyol.com", "hepsiburada.com", "amazon.com.tr", "n11.com",
        "ciceksepeti.com", "watsons.com.tr", "gratistr.com",
        "sephora.com.tr", "boyner.com.tr", "rossmann.com.tr"
      ];

      let bulunanUrunAdi = "";
      let bulunanLinkler: any[] = [];

      // B. Eşleşen Sayfaları Tara
      const sayfalar = webDetection.pagesWithMatchingImages || [];

      // C. Hedef sitelerden birinde bu ürün var mı?
      const satisSayfasi = sayfalar.find(page =>
        page.url && page.pageTitle && hedefSiteler.some(site => page.url!.includes(site))
      );

      if (satisSayfasi) {
        // BINGO! Ürünü bir satış sitesinde bulduk.
        // Sayfa başlığı genellikle "Ürün Adı - Site Adı" şeklindedir.
        // Örn: "Maybelline New York Sky High Maskara - Trendyol"

        let hamBaslik = satisSayfasi.pageTitle || "";

        // Başlığı temizle (Gereksiz ekleri at)
        bulunanUrunAdi = hamBaslik
          .replace(/ - Trendyol.*/i, "")
          .replace(/ \| Hepsiburada.*/i, "")
          .replace(/ : Amazon.com.tr.*/i, "")
          .replace(/ \| Watsons.*/i, "")
          .replace(/ Fiyatı.*/i, "")
          .replace(/ Satın Al.*/i, "")
          .replace(/ Yorumları.*/i, "")
          .trim();
      } else {
        // Eğer satış sitesi bulamazsa, Google'ın "En İyi Tahmin" etiketini kullan
        // (Ama genelde bu sadece kategori adı olur: "Mascara")
        bulunanUrunAdi = webDetection.bestGuessLabels?.[0]?.label || "Tanımlanamadı";
      }

      // D. Linkleri Listele (Flutter'da göstermek için)
      bulunanLinkler = sayfalar
        .filter(page => page.url && hedefSiteler.some(site => page.url!.includes(site)))
        .slice(0, 3) // En iyi 3 linki al
        .map(page => ({
          site: new URL(page.url!).hostname.replace("www.", ""),
          url: page.url,
          baslik: page.pageTitle
        }));

      // 3. Benzersiz ID Oluştur (Slug)
      // "L'Oreal Paris Panorama" -> "loreal-paris-panorama"
      const benzersizID = bulunanUrunAdi
        .toLowerCase()
        .replace(/ı/g, "i").replace(/ğ/g, "g").replace(/ü/g, "u")
        .replace(/ş/g, "s").replace(/ö/g, "o").replace(/ç/g, "c")
        .replace(/[^a-z0-9\s]/g, "")
        .replace(/\s+/g, "-");

      return {
        basari: true,
        urunAdi: bulunanUrunAdi, // Artık tam marka model dönecek
        benzersizID: benzersizID,
        linkler: bulunanLinkler // Bulunan satış linkleri
      };

    } else {
      return { basari: false, mesaj: "Görselle ilgili veri bulunamadı." };
    }

  } catch (error) {
    console.error("AI Hatası:", error);
    throw new HttpsError("internal", "Analiz sırasında hata oluştu.");
  }
});
// --- BURADAN ÖNCESİ SENİN MEVCUT KODLARIN ---

// Yeni Eklenen: Yorum Kaydetme Fonksiyonu
export const yorumKaydet = onCall(async (request) => {
  // 1. Güvenlik Kontrolü: Kullanıcı giriş yapmış mı?
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Yorum yapabilmek için giriş yapmalısınız."
    );
  }

  // 2. Flutter'dan gelen verileri al
  const veri = request.data;

  // Basit doğrulama (Validation)
  if (!veri.productName || !veri.reviewText || !veri.rating) {
     throw new HttpsError("invalid-argument", "Eksik bilgi gönderildi.");
  }

  try {
    // 3. Kullanıcı Bilgilerini Hazırla
    // request.auth.token içinden bilgileri güvenle alıyoruz
    const userId = request.auth.uid;
    const userName = request.auth.token.name || "Anonim Kullanıcı";
    const userAvatar = request.auth.token.picture || null;

    // 4. Kaydedilecek Veri Paketi
    const reviewData = {
      userId: userId,                // Profil sayfası için kritik
      userName: userName,            // Yorum kartında gözükecek isim
      userAvatar: userAvatar,        // Yorum kartında gözükecek resim
      productName: veri.productName, // Ürün adı
      reviewText: veri.reviewText,   // Yorum metni
      rating: veri.rating,           // Puan (1-5)
      imageUrl: veri.imageUrl || null, // Varsa resim
      createdAt: admin.firestore.FieldValue.serverTimestamp(), // Sunucu saati
    };

    // 5. Firestore 'reviews' koleksiyonuna ekle
    const result = await admin.firestore().collection("reviews").add(reviewData);

    return {
      basari: true,
      mesaj: "Yorum başarıyla kaydedildi.",
      reviewId: result.id
    };

  } catch (error) {
    console.error("Yorum Kayıt Hatası:", error);
    throw new HttpsError("internal", "Veri tabanı hatası oluştu.");
  }
});