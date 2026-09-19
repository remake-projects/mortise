# Kurulum

Sıfırdan Mortise hub'ı ayağa kaldırma. Hedef sunucu: Ubuntu 24.04, Docker
Compose v2+. Adımlar `~/scripts/remote.sh "komut"` ile çalıştırılır.

> Durum: adımlar 2026-09-20'de canlıda uygulandı ve çalıştı. Adım 3'e kadar
> olan kısım doğrulanmış kayıttır; 4-8 arası GUI'den yapılır.

## 0. Ön kontrol

Kuruluma başlamadan iki değişken şeyi tazele:

```bash
df -h /            # hub senkronlanan her şeyin tam kopyasını tutar
docker ps          # 22000 veya 8384 başkası tarafından tutuluyor mu
```

Kök disk %85'in üstündeyse **önce yer aç**. Hub dolu diske yazmaya
çalışırsa yalnız Mortise değil, sunucudaki bütün stack'ler birlikte düşer.

## 1. Dizin, depo ve veri klasörleri

`/opt/mortise` hem depo kökü hem veri köküdür. `data/` ve `config/`
`.gitignore`'da — sunucuda çalışan kopyada kalırlar, asla commit'lenmezler.

`/opt` root'a ait ama sunucuda **şifresiz sudo yok**. Kullanıcı `docker`
grubunda olduğu için dizini Docker üzerinden açmak daha pratik:

```bash
docker run --rm -v /opt:/mnt alpine \
  sh -c "mkdir -p /mnt/mortise && chown $(id -u):$(id -g) /mnt/mortise"

git clone https://github.com/remake-projects/mortise.git /opt/mortise
```

Şifresiz sudo olan bir sunucuda aynı iş: `sudo mkdir -p /opt/mortise &&
sudo chown "$(id -u):$(id -g)" /opt/mortise`

### Veri klasörlerini ÖNCEDEN oluştur — atlanırsa container crash loop'a girer

```bash
mkdir -p /opt/mortise/config /opt/mortise/data
```

Bu adım kozmetik değil. Bind mount kaynağı yoksa **Docker onu `root:root`
olarak oluşturur**, container ise `PUID=1000` ile çalışır ve config'e
yazamaz. Sonuç sessiz değil ama kafa karıştırıcıdır:

```
WRN Failed to correct directory permissions (chmod /var/syncthing/config: operation not permitted)
ERR Failed to acquire lock (open /var/syncthing/config/syncthing.lock: permission denied)
ERR Too many restarts; not retrying further
```

Bu hataya düşüldüyse düzeltmesi:

```bash
cd /opt/mortise && docker compose down
docker run --rm -v /opt/mortise:/mnt alpine chown -R 1000:1000 /mnt/config /mnt/data
docker compose up -d
```

## 2. Ortam dosyası

```bash
cd /opt/mortise
cp .env.example .env
# PUID/PGID'yi bu sunucudaki gerçek değerlerle doldur:
sed -i "s/^PUID=.*/PUID=$(id -u)/; s/^PGID=.*/PGID=$(id -g)/" .env
```

## 3. Stack'i kaldır

```bash
cd /opt/mortise
docker compose up -d
docker compose ps          # health: healthy bekleniyor
docker compose logs --tail 30
```

Doğrula: `8384` yalnızca `127.0.0.1`'e, `22000` `0.0.0.0`'a bağlı olmalı,
`21027` hiç görünmemeli.

```bash
docker compose port syncthing 8384
ss -lntup | grep -E '8384|22000|21027'
```

## 4. GUI'ye bağlan ve kilitle

Yerel makinenden:

```bash
./scripts/tunnel.sh          # http://127.0.0.1:8385
```

GUI açılır açılmaz, **başka hiçbir şey yapmadan önce**:

- **Actions → Settings → GUI** altında kullanıcı adı + güçlü parola kur.
  GUI localhost'a bağlı olsa da sunucuda ~30 container dönüyor; biri ele
  geçerse localhost artık güvenli bir sınır değil.
Syncthing 2.x artık varsayılan `~/Sync` klasörü oluşturmuyor — silinecek
bir şey yok, config klasörsüz başlar.

## 5. Hub varsayılanlarını uygula — atlanamaz adım

```bash
cd /opt/mortise && ./scripts/apply-defaults.sh
```

Syncthing'in kendi varsayılanları hub topolojisi için güvensiz; script
ikisini birden düzeltir:

- **staggered versioning, maxAge 30 gün.** Varsayılan bırakılırsa
  versiyonlama tamamen kapalıdır: hub'da silinen dosyanın geri dönüşü
  olmaz. Açıp sınırsız bırakmak ise ters uçta aynı derecede kötü — her
  sürüm süresiz birikir, 5 GB sessizce 15 GB olur.
- **minDiskFree 5 GB.** Syncthing'in varsayılanı %1, yani 50 GB'lık diskte
  500 MB; o eşiğe kadar yazmaya devam eder. Disk riskinin doğru sahibi
  burasıdır — harici bir cron değil, Syncthing'in kendi mekanizması.
  Boş alan eşiğin altına inince klasöre yazmayı durdurur ve sunucudaki
  diğer stack'lere nefes alanı bırakır.

Değerler env ile geçilebilir:

```bash
MORTISE_MAX_AGE_DAYS=60 MORTISE_MIN_DISK_FREE_GB=8 ./scripts/apply-defaults.sh
```

Ayarlar **yeni eklenen** klasörlere uygulanır. Script'ten önce eklenmiş bir
klasör varsa onu GUI'den ayrıca düzeltmek gerekir.

## 6. İlk düğümü eşle

Hub ve laptop birbirinin device ID'sini ekler (GUI → Add Remote Device).
Hub tarafında o cihazı işaretle:

- **Introducer**: açık. Hub'ın tanıdığı diğer cihazlar yeni düğüme otomatik
  tanıtılır — "hub'a katıl, ağdaki herkesi gör" akışı bununla çalışır.
- **Auto Accept Folders**: açık. Bir düğümün paylaştığı yeni vault hub'da
  elle onay beklemez. Bunun çalışması adım 5'e bağlıdır: `defaults/folder.path`
  boşsa klasör kök dizine açılmaya çalışılır ve `mkdir /<ad>: permission
  denied` ile sessizce düşer — cihaz bağlı görünür, klasör hiç gelmez.

Otomatik kabul edilen klasör, adı klasörün **label**'ından alır; boşluklu
bir label boşluklu bir dizin adı üretir.

## 7. Pilot vault

Vault köküne ignore profilini koy:

```bash
cp profiles/obsidian.stignore /yol/vault/.stignore
```

> **Her düğümde ayrı kurulur.** Syncthing `.stignore`'u senkronlamaz —
> `.stfolder`/`.stversions` gibi kendi iç dosyası sayar, çünkü her düğümün
> kendi kuralları olabilir. Hub'a koymak yetmez; vault'u bağlayan her
> düğümde ayrıca kurulmalı. Atlanan düğüm `.obsidian/workspace.json`'ı
> senkronlamaya başlar ve dakikalar içinde `sync-conflict` üretir.

Doğrulama: laptop'ta bir not oluştur → hub'da belirsin → hub'da düzenle →
laptop'ta belirsin. `.obsidian/workspace.json` **iki tarafta da farklı
kalmalı** ve çakışma dosyası doğmamalı.

Bu akış 2026-09-20'de sunucuda geçici ikinci bir Syncthing düğümüyle
doğrulandı: otomatik klasör kabulü, iki yönlü senkron (hub→düğüm 2 sn,
düğüm→hub 10 sn) ve `workspace.json`'ın gerçekten dışarıda kaldığı test
edildi.

## 8. Disk izleme

Diskin asıl koruması adım 5'te kuruldu: `minDiskFree = 5 GB`. Syncthing
boş alan o eşiğin altına inince klasöre yazmayı kendi durdurur — Mortise'ın
diğer stack'leri düşürmesini bu engeller.

Buradaki izleme onun yerine geçmez, **haberdar olmak** içindir: yazma
durduğunda senkron sessizce durur ve fark edilmezse günlerce öyle kalır.

```bash
df -h /                                    # anlık
docker exec mortise-syncthing curl -fksS \
  -H "X-API-Key: $API" 127.0.0.1:8384/rest/system/error   # sessiz hatalar
```

## Yedekleme

Yedeklenmesi gereken tek dizin `/opt/mortise/config`. Hub'ın device ID'si
ve özel anahtarı burada; kaybolursa hub yeni bir kimlik alır ve **bütün
eşlemeler kopar**. `data/` yedeklenmek zorunda değil — tanımı gereği
düğümlerde kopyası var.
