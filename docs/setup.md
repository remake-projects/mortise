# Kurulum

Sıfırdan Mortise hub'ı ayağa kaldırma. Hedef sunucu: Ubuntu 24.04, Docker
Compose v2+. Adımlar `~/scripts/remote.sh "komut"` ile çalıştırılır.

> Durum: bu doküman Faz 1 kurulumu sırasında doğrulanacak. Henüz canlıda
> uygulanmadıysa adımlar tasarım niyetidir, çalıştırılmış kayıt değil.

## 0. Ön kontrol

Kuruluma başlamadan iki değişken şeyi tazele:

```bash
df -h /            # hub senkronlanan her şeyin tam kopyasını tutar
docker ps          # 22000 veya 8384 başkası tarafından tutuluyor mu
```

Kök disk %85'in üstündeyse **önce yer aç**. Hub dolu diske yazmaya
çalışırsa yalnız Mortise değil, sunucudaki bütün stack'ler birlikte düşer.

## 1. Dizin ve depo

`/opt/mortise` hem depo kökü hem veri köküdür. `data/` ve `config/`
`.gitignore`'da — sunucuda çalışan kopyada kalırlar, asla commit'lenmezler.

```bash
sudo mkdir -p /opt/mortise
sudo chown "$(id -u):$(id -g)" /opt/mortise
git clone git@github.com:remake-projects/mortise.git /opt/mortise
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
- Varsayılan "Default Folder"ı (`~/Sync`) sil. İşe yaramaz, karışıklık
  yaratır.

## 5. Versiyonlamayı sınırla — atlanamaz adım

Varsayılan ayarla her silinen ve değiştirilen sürüm süresiz birikir; 5 GB
sessizce 15 GB olur ve disk zaten dar. Her klasör için:

**File Versioning → Staggered File Versioning**, `Maximum Age` = `30` gün.

Obsidian vault'ları küçük olduğu için 30 gün rahat sığar; asıl amaç üst
sınırın *var olması*.

## 6. İlk düğümü eşle

Hub ve laptop birbirinin device ID'sini ekler (GUI → Add Remote Device).
Hub tarafında o cihazı işaretle:

- **Introducer**: açık. Hub'ın tanıdığı diğer cihazlar yeni düğüme otomatik
  tanıtılır — "hub'a katıl, ağdaki herkesi gör" akışı bununla çalışır.
- **Auto Accept Folders**: açık. Bir düğümün paylaştığı yeni vault hub'da
  elle onay beklemez.

## 7. Pilot vault

Küçük bir test vault'uyla uçtan uca doğrula. Vault köküne ignore profilini
koy:

```bash
cp profiles/obsidian.stignore /yol/vault/.stignore
```

Doğrulama: laptop'ta bir not oluştur → hub'da belirsin → hub'da düzenle →
laptop'ta belirsin. `.obsidian/workspace.json` **iki tarafta da farklı
kalmalı** ve çakışma dosyası doğmamalı.

## 8. Disk eşiği

Kurulumdan sonra kök disk için bir uyarı eşiği kur. Bu, Mortise'ın diğer
stack'leri düşürmesini önleyen son savunma hattı.

## Yedekleme

Yedeklenmesi gereken tek dizin `/opt/mortise/config`. Hub'ın device ID'si
ve özel anahtarı burada; kaybolursa hub yeni bir kimlik alır ve **bütün
eşlemeler kopar**. `data/` yedeklenmek zorunda değil — tanımı gereği
düğümlerde kopyası var.
