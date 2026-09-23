# Fork notları

Upstream `syncthing/syncthing`'den her sapmanın kaydı. Dosya **Faz 1'de,
henüz hiçbir sapma yokken** açıldı: kayıt ilk günden tutulmazsa üçüncü ayda
kimse neyin neden değiştiğini bilmez.

## Şu anki durum

| | |
|---|---|
| Upstream sürüm | `v2.1.5` (2026-09-08) |
| Kullanılan imaj | `syncthing/syncthing:2.1.5` — değiştirilmemiş upstream |
| Kod sapması | **arayüz** (`gui/`) — motor değiştirilmedi |
| Upstream lisans | MPL-2.0 — 2026-09-20'de upstream `LICENSE` ile karşılaştırıldı, depodaki kopya bir karakter dışında (boilerplate'teki `http://` → `https://`) birebir aynı |

Bugün Mortise = upstream imaj + kendi compose/konfigürasyonumuz. Konfigürasyon
sapma sayılmaz; bu tablo yalnızca **kod** sapmalarını izler.

## Kademeli fork planı

Fork'un asıl maliyeti kod yazmak değil, **rebase**. Syncthing ayda bir stable
çıkarıyor; upstream'den erken ayrılan her satır kalıcı bakım yükü. Sıra:

1. **Şimdi (Faz 1):** upstream imaj, sapma yok. Özelleştirme REST API
   üzerinden (`X-API-Key`) yapılır.
2. **Faz 2 — yapıldı (2026-09-23):** arayüz fork'u. Beklenenden ucuz çıktı:
   kendi imajını build etmek **gerekmedi**. Motor `STGUIASSETS` dizinini
   dosya bazlı bir üst katman olarak kullanıyor — bir dosya orada varsa o,
   yoksa binary'ye gömülü upstream sürümü sunuluyor
   (`lib/api/api_statics.go`). Yani yalnızca değişen dosyalar taşınıyor ve
   `image:` satırı upstream'de kalabiliyor.

   **Karar (2026-09-20):** panel sıfırdan yazılmayacak. Syncthing'in kendi
   arayüzü fork'lanıp bizim kullanım senaryomuza — Obsidian vault'ları
   paylaşan küçük, güvenilen bir düğüm ağı — göre sadeleştirilecek.
   "Ayrı panel uygulaması" diye bir kavram yok; REST API üstüne bağımsız
   bir arayüz yazma seçeneği değerlendirildi ve **reddedildi**. Bunun
   bedeli bilinçli olarak kabul edildi: her upstream sürümünde `gui/`
   için rebase yükü doğar, bu dosyanın var olma sebebi de budur.
3. **En son, gerçekten şartsa:** protokol/davranış fork'u.

## Fork'a girmeden önce kontrol listesi

"Bunun için fork lazım" denen özelliklerin çoğu Syncthing'de zaten var. Yeni
bir sapmaya karar vermeden önce şunlara bak:

- `send-only` / `receive-only` klasörler
- **untrusted device** — uçtan uca şifreli, sunucu içeriği göremez
- dosya versiyonlama (staggered, trashcan, external)
- ignore pattern'leri (`.stignore`)
- cihaz başına rate limit
- `introducer` cihaz — hub'ın tanıdıklarını yeni düğüme otomatik tanıtır
- `autoAcceptFolders`
- REST API — GUI'nin yaptığı her şeyi programatik yapar

Mortise'ın hub topolojisi ve "hub'a katıl, herkesi gör" akışı bu listedeki
`introducer` + `autoAcceptFolders` ile karşılanıyor; protokol değişikliği
gerektirmiyor.

## MPL-2.0 yükümlülüğü

Fork dağıtılırsa: **değiştirilen mevcut dosyaların** kaynağı yayınlanmalı.
Yanına eklenen yeni dosyalar bu yükümlülüğün dışında. Ayrıca "Syncthing"
adı ve logosu kullanılamaz — Mortise adının marka olmasının sebebi bu.

## Arayüz fork'u — nasıl kurulu

```
gui/default/                         STGUIASSETS kökü (upstream'in gui/ ile aynı düzen)
  index.html                         FORK
  assets/css/theme.css               FORK — bilerek boş
  assets/img/logo-horizontal.svg     FORK — Mortise logosu (emniyet)
  syncthing/core/aboutModalView.html FORK
  assets/mortise/                    BİZİM — upstream'de karşılığı yok
    css/  tokens fonts base topbar panels controls overlays upstream
    js/brand.js                      çeviri tablolarında ad dönüşümü
    fonts/ img/
```

Bizim dosyalar `assets/` altında, `mortise/` kökünde değil: parola açıkken
motor oturumsuz isteklere yalnızca `/assets/`, `/syncthing/`, `/vendor/`,
`/theme-assets/` öneklerini açıyor (`lib/api/api_auth.go`, `isNoAuthPath`).
Başka bir yerde dursalardı giriş ekranı stilsiz ve markasız yüklenirdi.

Dağıtım: hub'da `./gui` container'a salt okunur bağlı (`compose.yml`),
düğümde `node-setup.sh` onu `~/.mortise/gui`'ye kopyalıyor.

### Rebase — yeni upstream sürümünde

1. `MORTISE_VERSION`'ı yükselt.
2. Yeni sürümün `gui/default/` altındaki **fork'lanan 4 dosyasını** indir.
3. Bizim sapmamız tam olarak `git diff a62c426 -- gui/default/index.html
   gui/default/assets/css/theme.css gui/default/assets/img/logo-horizontal.svg
   gui/default/syncthing/core/aboutModalView.html` — bunu yeni dosyalara
   yeniden uygula. `a62c426` upstream v2.1.5'in değiştirilmemiş kopyası.
4. `assets/mortise/` rebase gerektirmez; yalnızca upstream CSS sınıf adlarını
   değiştirdiyse stil kuralları gözden geçirilir.
5. Doğrulama: arayüzün görünen metninde upstream adı aranır (giriş ekranı
   dahil — parolalı bir düğümde).

## Sapma kaydı

| Tarih | Dosya / alan | Ne değişti | Neden | Upstream'e önerildi mi |
|---|---|---|---|---|
| 2026-09-23 | `index.html` | başlık, marka, sekme ikonu, yardım menüsü, stil ve `brand.js` bağlantıları | rebrand; yardım menüsü upstream sitesine/forumuna gidiyordu | hayır — markaya özgü |
| 2026-09-23 | `aboutModalView.html` | marka, kod adı, derleme etiketleri ve katkıda bulunanlar sekmesi kaldırıldı; upstream telif bildirimi kaynakta yorum olarak korundu | rebrand | hayır |
| 2026-09-23 | `assets/css/theme.css` | boşaltıldı | kendi açık/koyu modumuz token'lardan; upstream koyu teması özgüllük yarışına girerdi | hayır |
| 2026-09-23 | `assets/img/logo-horizontal.svg` | Mortise logosu | kaçan bir referans upstream logosu göstermesin | hayır |
| 2026-09-23 | çeviri tabloları (dosyaya dokunulmadı) | `brand.js` yükleyiciyi sarmalayıp değerleri dönüştürüyor | 57 dil dosyasını fork'lamamak için | hayır |
| 2026-09-23 | upstream'e giden bağlantılar (dosyaya dokunulmadı) | `upstream.css` tek seçiciyle gizliyor | 3800 satırlık controller'ı fork'lamamak için | hayır |
| 2026-09-23 | ayarlar (kod değil) | kullanım ve çökme raporu kapalı, düğümde `STNOUPGRADE` | adı değiştirilmiş arayüzde "Mortise rapor gönderir" yanlış olurdu; yükseltme sürümü hub'dan koparırdı | — |

### Kalan: motorun kendi çıktıları

Upstream adı arayüzde görünmüyor ama motorun kendisinde duruyor ve bunlar
konfigürasyonla değişmiyor, binary fork'u gerektiriyor (3. kademe):

- `mortise --version` → `syncthing v2.1.5 …`
- log satırları, HTTP başlıkları (`X-Syncthing-Version`), iç yollar
  (`/var/syncthing/…`)
- arayüzün yeniden başlatma/hata sırasında gösterdiği, sunucudan gelen ham
  hata metinleri (nadir)
