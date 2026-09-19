# Agent Handoff

## Görev özeti

`mortise`, kendi VDS'imiz üzerinde çalışacak, Syncthing tabanlı merkezi dosya
senkronizasyon kurulumudur. VDS 7/24 açık **hub** düğümü olur; laptop ve
telefonlar ona bağlanır.

İkinci ve şimdilik ertelenmiş bir hedef daha var: Syncthing'i kendimize özel bir
forma sokmak (rebrand ve/veya davranış değişikliği). Bu yüzden depo MPL-2.0 ile
lisanslandı ve mimari baştan fork'a geçişi ucuzlatacak şekilde kurgulanıyor.
**Ama ilk sürümde fork yok** — gerekçesi aşağıda "Fork stratejisi" bölümünde.

Bu depo yalnızca **konfigürasyon** tutar. Senkronlanan veri ve Syncthing'in
kendi config'i sunucuda repo dışında, `/opt/mortise/` altında durur.

## Mevcut durum

- Aktif branch: `main`, remote `github.com/remake-projects/mortise`
- Tek commit var: `3b94a8c Initial commit` (yalnızca `LICENSE` + `.gitattributes`)
- **Henüz hiç kurulum yapılmadı.** Sunucuda Syncthing kurulu değil.
- Bu handoff, bir önceki oturumda yapılan sunucu keşfi ve alınan kararların
  kaydıdır. Kod yazımı bir sonraki oturumda başlayacak.

## Doğrulanmış sunucu envanteri

2026-09-20 tarihinde `~/scripts/remote.sh` üzerinden salt okunur olarak toplandı.
Yeniden türetmeye gerek yok, ama **disk ve container listesi değişken** — kuruluma
başlamadan önce o ikisini tazele.

| | |
|---|---|
| OS | Ubuntu 24.04.4 LTS, x86_64 |
| CPU / RAM | 4 vCPU / 7.8 GiB (hub için fazlasıyla yeterli) |
| Disk `/` | 50 GB toplam, 38 GB dolu, **9.1 GB boş — %81**|
| Docker | 29.7.2, Compose v5.5.0 |
| Reverse proxy | `remake-caddy-1` → `0.0.0.0:80`, `0.0.0.0:443` (tcp+udp). **Caddy, nginx değil.** |
| Firewall | `ufw` kurulu değil |
| Syncthing | kurulu değil |

Sunucuda ~30 container dönüyor (`remake-*`, `salivra-*`, `gdgdeu-*`, `dovetail-*`,
`emirk-portfolio-*`) ve 5 ayrı Postgres örneği var. Mortise bu ekosisteme
**dokunmadan** yanına kurulmalı.

## Kararlar

Hepsi kullanıcı onayıyla alındı; yeniden tartışmaya gerek yok.

1. **İsim `mortise`.** Marangozlukta dişi yuva. Fork dağıtılırsa "Syncthing"
   adı kullanılamayacağı için isim aynı zamanda marka.
2. **Docker Compose ile kurulum, apt ile değil.** Sunucudaki her şey zaten
   compose ile yönetiliyor; ayrıca fork'a geçişte `image:` satırı tek adımda
   değişiyor. (Bilgi: apt yolu gerekirse güncel kanal `stable-v2`,
   repo `https://apt.syncthing.net/`.)
3. **Topoloji: VDS = merkezi hub.** Untrusted/şifreli düğüm değil, kapalı ağ da
   değil (kendi discovery/relay sunucumuzu şimdilik kurmuyoruz).
4. **GUI yalnızca SSH tüneli ile.** `127.0.0.1:8384`'e bind edilir, Caddy'ye
   hiç dokunulmaz.
5. **Veri hacmi hedefi 5 GB altı.** Mevcut diske sığar.

## Ağ planı

| Port | Bind | Gerekçe |
|---|---|---|
| 8384 (GUI) | `127.0.0.1` | Sadece SSH tüneli: `ssh -L 8384:127.0.0.1:8384 vds` |
| 22000 tcp+udp | `0.0.0.0` | Cihaz senkronu. Cihaz ID'li TLS ile korunuyor, şifresiz yüzey değil. |
| 21027/udp | **açılmaz** | LAN keşfi; VDS'te işe yaramaz, gereksiz saldırı yüzeyi. |

GUI localhost'a bağlı olsa bile **ayrıca kullanıcı/şifre kurulacak**. Sunucuda
30 container var; biri ele geçerse localhost artık güvenli bir sınır değil.

## Riskler

### 1. Disk — en kritik madde

Kök disk **%81 dolu, 9.1 GB boş**. Hub topolojisi senkronlanan her şeyin tam
kopyasını VDS'te tutar ve bu alan 5 ayrı Postgres ile paylaşılıyor. Disk
dolarsa Mortise değil, **sunucudaki bütün stack'ler** birlikte yere yatar.

Bu yüzden iki şey zorunlu:

- **Dosya versiyonlama varsayılanla bırakılmayacak.** `staggered` +
  `maxAge` sınırı ile kurulacak; yoksa silinen/değişen her sürüm birikir ve
  5 GB sessizce 15 GB olur.
- Kurulumdan sonra disk için bir uyarı/izleme eşiği konacak.

### 2. Depoya veri sızması

Syncthing'in veri ve config dizini **repo içine konmayacak**. `/opt/mortise/`
altında duracak, `.gitignore` da `data/` ile ikinci bir savunma hattı tutacak.
Aksi halde ilk `git status`'ta binlerce dosya çıkar ve bir gün commit'lenir.

### 3. Mortise dışı, ama açık: Postgres internete açık

```
remake-postgres-1   0.0.0.0:5432->5432/tcp      ufw: yok
```

`remake-postgres-1` 5432'yi tüm internete publish ediyor ve sunucuda firewall
yok. **Bu Mortise'ın sorunu değil**, ayrı bir iş — ama kaydı burada dursun.
Düzeltmesi `remake` deposunda compose'daki binding'i `127.0.0.1:5432:5432`
yapıp container'ı yeniden başlatmak. Not: Docker `ufw`'yi bypass ettiği için
sonradan firewall kurmak tek başına bu sorunu çözmez.

## Fork stratejisi — kademeli, şimdilik fork yok

Fork'un asıl maliyeti kod değil, **rebase**. Syncthing ayda bir stable çıkarıyor;
upstream'den erken ayrılan her satır kalıcı bakım yükü. Sıra şu:

1. **Şimdi:** upstream `syncthing/syncthing` imajı + üstüne kendi script'lerimiz
   (REST API, `X-API-Key`). İhtiyaçların çoğu burada biter.
2. **Sonra, gerekirse:** yalnızca `gui/` klasörünü fork'la, rebrand et, kendi
   imajını build et. `compose.yml`'de tek satır değişir.
3. **En son, gerçekten şartsa:** protokol/davranış fork'u. MPL-2.0 buna izin
   veriyor — değiştirdiğin **mevcut** dosyaları yayınlaman yeterli, yanına
   eklediğin yeni dosyalar sana kalır.

`docs/fork-notes.md` **1. adımda bile açılacak**. Upstream'den sapmaların kaydı
ilk günden tutulmazsa üçüncü ayda kimse neyin neden değiştiğini bilmiyor.

> Fork'a fiilen girmeden önce şunlar zaten var mı diye bak — sık sık "bunun için
> fork lazım" denen özelliklerin çoğu Syncthing'de mevcut: `send-only` /
> `receive-only` klasörler, **untrusted device** (uçtan uca şifreli, sunucu
> içeriği göremez), dosya versiyonlama, ignore pattern'leri, cihaz başına
> rate limit.

## Sıradaki oturum: Faz 1 — kurulum

Hedeflenen depo yapısı:

```
compose.yml          # syncthing/syncthing, GUI 127.0.0.1'e bind
.env.example         # PUID/PGID, veri yolu, GUI portu
scripts/
  tunnel.sh          # ssh -L 8384 kısayolu
  pair.sh            # REST API ile cihaz ekleme
docs/
  setup.md           # sıfırdan kurulum
  fork-notes.md      # upstream'den sapmalar
```

Adımlar:

1. **Disk ve container durumunu tazele** (`df -h /`, `docker ps`). 9.1 GB
   rakamı bu handoff yazıldığı andaki değer; hâlâ geçerli mi doğrula.
2. Syncthing'in **güncel Docker imaj etiketini ve upstream `LICENSE` dosyasını**
   resmî kaynaktan doğrula. Lisansın MPL-2.0 olduğu bu handoff'a bilgi olarak
   yazıldı ama fork/dağıtım kararına dayanak yapılmadan önce upstream'deki
   dosyadan teyit edilmeli.
3. `compose.yml` + `.env.example` yaz. Bind'ler yukarıdaki ağ planına uysun.
4. Sunucuda `/opt/mortise/` dizinini aç, stack'i kaldır.
5. GUI'ye SSH tüneliyle bağlan, kullanıcı/şifre kur, `staggered` versiyonlamayı
   `maxAge` ile ayarla.
6. İlk cihazı (laptop) eşle, küçük bir pilot klasörle uçtan uca senkronu doğrula.
7. `docs/setup.md` ve `docs/fork-notes.md`'yi yaz.

## Kullanıcıya sorulacak açık madde

**Fork'taki "spesifik form" tam olarak neydi?** Kullanıcı ilk mesajda Syncthing'i
"modifiye edip bize özel bir formunu yapmak" ilgisini çektiğini söyledi, ama
somut olarak neyi değiştirmek istediği henüz konuşulmadı. Faz 1 bu cevap
olmadan da yürür (upstream imaj kullanılıyor), fakat **Faz 2'ye geçmeden önce
bu netleşmeli** — aksi halde neyi fork'ladığımız belirsiz kalır.

## Çalışma notları

- Sunucu erişimi: [`serverconnect.md`](serverconnect.md). Bu dosya
  `.gitignore`'da — commit'leme.
- Kullanıcı Türkçe konuşuyor; yanıtlar Türkçe olmalı.
- Sunucu komutları `~/scripts/remote.sh "komut"` ile çalıştırılır. Argümansız
  çağırma — interaktif shell açar ve takılırsın.
