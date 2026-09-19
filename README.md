# Mortise

Obsidian vault'larını kendi sunucumuz üzerinden senkronize eden merkezi
senkron sistemi. Masaüstü uygulaması yok; yönetim web arayüzünden yapılır.

*Mortise*, marangozlukta dişi yuva — geçmenin oturduğu yer.

## Ne yapar

Bir VDS'i 7/24 açık **hub** düğümü olarak çalıştırır; laptop ve masaüstü
düğümleri ona ve birbirine bağlanır. Hub trafiği yönlendiren bir aracı
değildir — ağdaki diğer düğümler gibi bir düğümdür, tek farkı hiç kapanmaması:

- Laptop kapalıyken telefondan yazdığın not hub'a gider, laptop açılınca
  oradan çeker.
- Sunucusu olmayan iki düğüm birbirine doğrudan (P2P) bağlanır; hub olmadan
  da senkron olurlar, sadece ikisi de aynı anda açık olmalıdır.

Veri uçtan uca TLS ile taşınır ve her cihaz kendi ID'siyle doğrulanır.

## Mortise ne ekliyor

Altta çalışan senkron motoru bu topolojiyi zaten destekliyor; Mortise onu
**Obsidian için doğru ayarlanmış** halde paketler:

| | Motor varsayılanı | Mortise |
|---|---|---|
| Versiyonlama | kapalı — silinen dosya geri gelmez | `staggered`, 30 gün |
| `minDiskFree` | %1 (50 GB diskte 500 MB) | 5 GB |
| `defaults/folder.path` | boş — otomatik kabul edilen klasör kök dizine açılmaya çalışır ve düşer | `/var/syncthing/data` |
| Ignore profili | yok | `profiles/obsidian.stignore` |

Bu dördü ayarlanmadan Obsidian vault'u senkronlamak ya sürekli çakışma
üretir ya da diski sessizce doldurur.

## Kurulum

Ayrıntılı ve doğrulanmış adımlar: **[`docs/setup.md`](docs/setup.md)**

```bash
# sunucuda
git clone https://github.com/remake-projects/mortise.git /opt/mortise
cd /opt/mortise
mkdir -p config data          # atlanırsa Docker bunları root:root açar, container crash loop'a girer
cp .env.example .env
docker compose up -d
./scripts/apply-defaults.sh   # güvenli varsayılanlar
```

GUI dışarı açılmaz; erişim SSH tüneliyle:

```bash
./scripts/tunnel.sh           # http://127.0.0.1:8385
```

### Düğüm (macOS)

Her makine kendi Mortise düğümünü çalıştırır — hub'la aynı katmanlama:
altta senkron motoru, üstünde Mortise'ın yapılandırması.

```bash
./scripts/node-setup.sh
```

Script motoru `~/.mortise/bin/mortise` olarak kurar (paket yöneticisine
dokunmaz), config'i `~/.mortise` altına açar, login'de açılan bir
LaunchAgent tanımlar ve hub'dakiyle **aynı** `apply-defaults.sh` ile
güvenli varsayılanları uygular. Servis, process ve komut adı `mortise`.

### Ağa katılma

Düğüm yalnızca hub ile eşleşir; hub `introducer` olduğu için ağdaki diğer
düğümleri otomatik tanır. Herkesin herkesle tek tek eşleşmesi gerekmez.

İki taraf da birbirini tanımadan bağlantı kurulmaz, o yüzden akış iki
parçalı:

```bash
# 1) Yeni düğümde — hub'ı ekler, kendi device ID'sini yazdırır
./scripts/join.sh <hub-ip> <hub-device-id>

# 2) Hub'da — düğümü tanıtır ve klasörleri onunla paylaşır
./scripts/add-node.sh <device-id> <isim>
```

Sıra önemli değil: hangisi önce çalışırsa çalışsın, ikinci taraf
eklendiği anda bağlantı kendiliğinden kurulur. Her iki script de
idempotent, tekrar çalıştırmak zarar vermez.

> Katılan düğümde vault'un ignore profili **ayrıca** kurulmalı
> (`cp profiles/obsidian.stignore <vault>/.stignore`). Klasör otomatik
> gelir ama `.stignore` senkronlanmaz; atlanırsa o düğüm
> `.obsidian/workspace.json`'ı paylaşmaya başlar.

## Ağ planı

| Port | Bind | Gerekçe |
|---|---|---|
| 8384 (GUI) | `127.0.0.1` | yalnızca SSH tüneli |
| 22000 tcp+udp | `0.0.0.0` | cihaz senkronu; cihaz ID'li TLS ile korunur |
| 21027/udp | **açılmaz** | LAN keşfi — VDS'te karşılıksız saldırı yüzeyi |

Reverse proxy'ye (Caddy) hiç dokunulmaz; Mortise sunucudaki diğer
stack'lerin yanına temassız kurulur.

## Ortak vault ve çakışma

Vault ortaktır: aynı klasöre birden fazla kişi yazar. Çakışma bir kusur
değil, dosya senkronunun doğasıdır — iki düğümde **aynı dosya**
birbirinden habersiz değişirse satır bazlı merge yapılamaz, kaybeden taraf
`Notum.sync-conflict-<tarih>-<cihaz>.md` olarak saklanır.

Önemli ayrım: çakışma aynı **notta** olur, vault'ta değil.

| Durum | Çakışma |
|---|---|
| Farklı notlar düzenleniyor | olmaz |
| Aynı not, arada senkron geçmiş | olmaz |
| Aynı not, birkaç saniye içinde | olur |
| Biri offline'ken ikisi de aynı notu düzenlemiş | olur |

Mortise bunu üç şekilde ele alır:

1. **`fsWatcherDelayS = 3`** (motor varsayılanı 10). Değişiklik daha
   hızlı yayılır, çakışma penceresi daralır.
2. **Çakışma kopyaları ignore edilmez.** Ignore etmek onları yok etmez,
   yalnızca tek makinede görünmez kılar; kaybedilen düzenleme fark
   edilmeden orada kalır.
3. Geriye teknik olmayan bir kural kalır: aynı notu aynı anda
   düzenlememek.

Mutlak garanti isteniyorsa dosya senkronu yanlış araçtır — canlı ortak
düzenleme CRDT tabanlı bir sistem gerektirir.

## Obsidian notu — her düğümde ayrı kurulur

`profiles/obsidian.stignore` vault kökünde `.stignore` olarak durur:

```bash
cp profiles/obsidian.stignore /yol/vault/.stignore
```

**`.stignore` senkronlanmaz** (motor onu kendi iç dosyası sayar, çünkü her
düğümün kendi kuralları olabilir). Yani profili hub'a koymak yetmez —
vault'u bağlayan **her düğümde** ayrı ayrı kurmak gerekir. Atlanırsa o
düğüm `.obsidian/workspace.json`'ı senkronlamaya başlar ve dakikalar içinde
`sync-conflict` dosyaları üretir.

## Depo yapısı

```
compose.yml                  hub tanımı; fork'a geçişte değişecek tek satır işaretli
.env.example                 PUID/PGID, veri yolu, imaj etiketi
scripts/
  tunnel.sh                  GUI'ye SSH tüneli
  apply-defaults.sh          güvenli klasör varsayılanlarını uygular
profiles/
  obsidian.stignore          vault ignore profili
docs/
  setup.md                   sıfırdan kurulum
  fork-notes.md              upstream'den sapmaların kaydı
```

Senkronlanan veri ve motorun kendi config'i **repo dışındadır**:
sunucuda `/opt/mortise/{data,config}`, `.gitignore` ikinci savunma hattı.

## Durum

**Faz 1 — kurulum: tamam.** Hub canlıda çalışıyor. Geçici ikinci bir
düğümle uçtan uca doğrulandı: otomatik klasör kabulü, iki yönlü
senkron ve ignore profilinin `workspace.json`'ı gerçekten dışarıda tuttuğu
test edildi.

**Faz 2 — web arayüzü:** mevcut arayüz fork'lanıp Mortise'a dönüştürülecek.
Bugün arayüzde ve motorun kendi çıktılarında upstream adı hâlâ görünür;
bunu kaldırmak fork gerektiriyor.
Gerekçe ve kademeli plan: [`docs/fork-notes.md`](docs/fork-notes.md).

Yol haritasında: kullanıcının kendi sunucusuna kurup ağa katılmasını
kolaylaştıran eşleme akışı.

## Lisans

[MPL-2.0](LICENSE) — Mortise, Syncthing motoru üzerine kuruludur ve onunla
aynı lisansı taşır. Fork dağıtılırsa
değiştirilen mevcut dosyaların kaynağı yayınlanır; "Syncthing" adı ve
logosu kullanılamaz.
