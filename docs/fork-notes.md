# Fork notları

Upstream `syncthing/syncthing`'den her sapmanın kaydı. Dosya **Faz 1'de,
henüz hiçbir sapma yokken** açıldı: kayıt ilk günden tutulmazsa üçüncü ayda
kimse neyin neden değiştiğini bilmez.

## Şu anki durum

| | |
|---|---|
| Upstream sürüm | `v2.1.5` (2026-09-08) |
| Kullanılan imaj | `syncthing/syncthing:2.1.5` — değiştirilmemiş upstream |
| Kod sapması | **yok** |
| Upstream lisans | MPL-2.0 — 2026-09-20'de upstream `LICENSE` ile karşılaştırıldı, depodaki kopya bir karakter dışında (boilerplate'teki `http://` → `https://`) birebir aynı |

Bugün Mortise = upstream imaj + kendi compose/konfigürasyonumuz. Konfigürasyon
sapma sayılmaz; bu tablo yalnızca **kod** sapmalarını izler.

## Kademeli fork planı

Fork'un asıl maliyeti kod yazmak değil, **rebase**. Syncthing ayda bir stable
çıkarıyor; upstream'den erken ayrılan her satır kalıcı bakım yükü. Sıra:

1. **Şimdi (Faz 1):** upstream imaj, sapma yok. Özelleştirme REST API
   üzerinden (`X-API-Key`) yapılır.
2. **Faz 2:** `gui/` klasörünü fork'la, rebrand et, kendi imajını build et.
   `compose.yml`'de yalnızca `image:` satırı değişir — o satır dosyada
   "FORK NOKTASI" yorumuyla işaretli.
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

## Sapma kaydı

Yeni bir sapma girildiğinde buraya satır eklenir. Boş kalması iyi bir
işarettir.

| Tarih | Dosya / alan | Ne değişti | Neden | Upstream'e önerildi mi |
|---|---|---|---|---|
| — | — | henüz sapma yok | — | — |
