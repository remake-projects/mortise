// Mortise marka katmanı — arayüz metinlerinde upstream adını değiştirir.
//
// Arayüzdeki görünen metinlerin neredeyse tamamı çeviri tablolarından
// geliyor (assets/lang/lang-*.json, 60 dil). Upstream adı bu tabloların
// değerlerinde geçiyor. Tabloları tek tek fork'lamak 60 dosyayı her upstream
// sürümünde yeniden birleştirmek demek; bunun yerine tabloyu yükleyen katman
// sarmalanıyor ve değerler yüklenirken dönüştürülüyor. Upstream'in dil
// dosyalarına hiç dokunulmuyor, yeni eklenen metinler de kendiliğinden
// kapsanıyor.
//
// Anahtarlara dokunulmuyor: şablonlar metni anahtar olarak kullanıyor
// (`<span translate>...Syncthing...</span>`) ve anahtar değişirse eşleşme
// kopar. Görünen şey değer olduğu için değeri değiştirmek yetiyor.
//
// Bu dosya app.js'ten SONRA yüklenmeli: aynı modüle kaydedilen config
// blokları sırayla çalışıyor ve buradaki yükleyici, app.js'in kurduğu
// statik yükleyicinin üstüne yazıyor.

(function () {
    'use strict';

    var BRAND = 'Mortise';
    var SOURCE_URL = 'https://github.com/remake-projects/mortise';

    // Sıra önemli: önce adresler, sonra ad. Tersi olsa "syncthing.net"
    // adresi "mortise.net" olurdu.
    //
    // Ad büyük/küçük harfe duyarsız aranıyor (bazı çevirilerde küçük harfle
    // geçiyor) ve harf büyüklüğü korunuyor. "inotify" ile devam edenler hariç:
    // biri `{{syncthingInotify}}` adlı bir çeviri parametresi — değişirse
    // parametre eşleşmez ve metnin o kısmı boş görünür; diğeri ayrı bir
    // aracın adı.
    function rebrand(text) {
        return text
            .replace(/https?:\/\/(?:www\.)?syncthing\.net\/?/gi, SOURCE_URL)
            .replace(/syncthing(?!-?inotify)/gi, function (match) {
                return match[0] === 'S' ? BRAND : BRAND.toLowerCase();
            });
    }

    // Değeri bir parametreyle upstream adresini taşıyan anahtarlar. Adres
    // çeviri tablosundan değil, controller'dan parametre olarak geliyor
    // (`{url: "https://syncthing.net"}`); o yüzden parametrenin yeri kendi
    // adresimizle dolduruluyor ve gelen değer yok sayılıyor.
    var VALUE_OVERRIDES = {
        'Learn more at {%url%}': function (value) {
            return value.replace(/\{\{\s*url\s*\}\}/g, SOURCE_URL);
        }
    };

    angular.module('syncthing')
        .factory('mortiseTranslationLoader', ['$translateStaticFilesLoader', function ($translateStaticFilesLoader) {
            return function (options) {
                return $translateStaticFilesLoader(options).then(function (table) {
                    var out = {};
                    Object.keys(table).forEach(function (key) {
                        var value = rebrand(String(table[key]));
                        var override = VALUE_OVERRIDES[key];
                        out[key] = override ? override(value) : value;
                    });
                    return out;
                });
            };
        }])
        .config(['$translateProvider', function ($translateProvider) {
            // app.js ile aynı ayarlar; yalnızca yükleyici değişiyor.
            $translateProvider.useLoader('mortiseTranslationLoader', {
                prefix: 'assets/lang/lang-',
                suffix: '.json'
            });
        }]);
})();
