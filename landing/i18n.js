/* The landing page in the nine languages the game itself speaks.
 *
 * The table is deliberately the same shape as `scripts/i18n/strings_ui.gd`:
 * one row per key, one column per language, no file to fetch. A landing that
 * asked the network for its own copy would show an empty hero on the slow
 * connection it is most trying to win over.
 *
 * The picker writes `harborclick.lang` to localStorage; with nothing stored,
 * `navigator.languages` decides — the same rule as the game's `Loc` autoload,
 * where "follow the device" is the default rather than the absence of a
 * choice. `?lang=en` overrides both, so a link can point at one.
 */
(() => {
  "use strict";

  // code, the two letters the picker shows, and the name written in itself:
  // a language list you can only read in a language you don't have is useless.
  const LANGUAGES = [
    ["pt_BR", "PT", "Português", "pt-BR"],
    ["en", "EN", "English", "en"],
    ["es", "ES", "Español", "es"],
    ["fr", "FR", "Français", "fr"],
    ["de", "DE", "Deutsch", "de"],
    ["it", "IT", "Italiano", "it"],
    ["ru", "RU", "Русский", "ru"],
    ["pl", "PL", "Polski", "pl"],
    ["tr", "TR", "Türkçe", "tr"],
  ];

  // Device language prefix -> what we serve it, mirroring Loc.DEVICE_MAP.
  const DEVICE = {
    pt: "pt_BR", en: "en", es: "es", gl: "es", fr: "fr",
    de: "de", it: "it", ru: "ru", pl: "pl", tr: "tr",
  };

  const FALLBACK = "en";

  const S = {
    "doc.title": {
      pt_BR: "HarborClick: clicker de porto",
      en: "HarborClick: a port clicker",
      es: "HarborClick: clicker de puerto",
      fr: "HarborClick : clicker de port",
      de: "HarborClick: Hafen-Clicker",
      it: "HarborClick: clicker di porto",
      ru: "HarborClick: кликер про порт",
      pl: "HarborClick: klikacz o porcie",
      tr: "HarborClick: liman clicker'ı",
    },
    "doc.desc": {
      pt_BR: "Clicker de porto em pixel art. Clica no navio, compra guindaste, o pátio anda sozinho. Grátis, no navegador.",
      en: "A pixel-art port clicker. Tap the ship, buy a crane, the yard runs itself. Free, in your browser.",
      es: "Clicker de puerto en pixel art. Toca el barco, compra una grúa, el patio anda solo. Gratis, en el navegador.",
      fr: "Un clicker de port en pixel art. Touche le bateau, achète une grue, le parc tourne seul. Gratuit, dans le navigateur.",
      de: "Ein Hafen-Clicker in Pixel Art. Tipp aufs Schiff, kauf einen Kran, das Lager läuft allein. Kostenlos, im Browser.",
      it: "Un clicker di porto in pixel art. Tocca la nave, compra una gru, il piazzale gira da solo. Gratis, nel browser.",
      ru: "Кликер про порт в пиксель-арте. Жми на судно, покупай кран, площадка едет сама. Бесплатно, в браузере.",
      pl: "Klikacz o porcie w pixel arcie. Kliknij statek, kup dźwig, plac chodzi sam. Za darmo, w przeglądarce.",
      tr: "Piksel sanatı liman clicker'ı. Gemiye dokun, vinç al, saha kendi döner. Ücretsiz, tarayıcıda.",
    },
    "skip": {
      pt_BR: "Pular pro conteúdo", en: "Skip to content",
      es: "Saltar al contenido", fr: "Aller au contenu",
      de: "Zum Inhalt springen", it: "Vai al contenuto",
      ru: "Перейти к содержимому", pl: "Przejdź do treści",
      tr: "İçeriğe geç",
    },
    "hud.state": {
      pt_BR: "PORTO ONLINE", en: "PORT ONLINE", es: "PUERTO EN LÍNEA",
      fr: "PORT EN LIGNE", de: "HAFEN ONLINE", it: "PORTO ONLINE",
      ru: "ПОРТ ОНЛАЙН", pl: "PORT ONLINE", tr: "LİMAN ÇEVRİMİÇİ",
    },
    "hud.play": {
      pt_BR: "JOGAR", en: "PLAY", es: "JUGAR", fr: "JOUER", de: "SPIELEN",
      it: "GIOCA", ru: "ИГРАТЬ", pl: "GRAJ", tr: "OYNA",
    },
    "lang.label": {
      pt_BR: "Idioma", en: "Language", es: "Idioma", fr: "Langue",
      de: "Sprache", it: "Lingua", ru: "Язык", pl: "Język", tr: "Dil",
    },
    // The tagline is the instruction, not a slogan: it is genuinely the whole
    // verb of the game.
    "hero.tagline": {
      pt_BR: "CLICA NO NAVIO", en: "TAP THE SHIP", es: "TOCA EL BARCO",
      fr: "TOUCHE LE BATEAU", de: "TIPP AUFS SCHIFF", it: "TOCCA LA NAVE",
      ru: "ЖМИ НА СУДНО", pl: "KLIKNIJ STATEK", tr: "GEMİYE DOKUN",
    },
    "hero.pitch": {
      pt_BR: "Clicker de porto. Compra guindaste, o pátio anda sozinho, os números incham.",
      en: "A port clicker. Buy a crane, the yard runs itself, the numbers get silly.",
      es: "Un clicker de puerto. Compra una grúa, el patio anda solo, los números se inflan.",
      fr: "Un clicker de port. Achète une grue, le parc tourne seul, les chiffres gonflent.",
      de: "Ein Hafen-Clicker. Kauf einen Kran, das Lager läuft allein, die Zahlen platzen.",
      it: "Un clicker di porto. Compra una gru, il piazzale gira da solo, i numeri esplodono.",
      ru: "Кликер про порт. Купи кран, площадка едет сама, числа пухнут.",
      pl: "Klikacz o porcie. Kup dźwig, plac chodzi sam, liczby puchną.",
      tr: "Liman clicker'ı. Vinç al, saha kendi döner, sayılar şişer.",
    },
    "hero.cta": {
      pt_BR: "JOGAR", en: "PLAY", es: "JUGAR", fr: "JOUER", de: "SPIELEN",
      it: "GIOCA", ru: "ИГРАТЬ", pl: "GRAJ", tr: "OYNA",
    },
    "hero.cue": {
      pt_BR: "TEM MAIS EMBAIXO", en: "MORE BELOW", es: "HAY MÁS ABAJO",
      fr: "Y'EN A PLUS BAS", de: "MEHR WEITER UNTEN", it: "C'È ALTRO SOTTO",
      ru: "НИЖЕ ЕЩЁ ЕСТЬ", pl: "NIŻEJ JEST WIĘCEJ", tr: "AŞAĞIDA DAHA VAR",
    },
    "hero.tag.free": {
      pt_BR: "GRÁTIS", en: "FREE", es: "GRATIS", fr: "GRATUIT",
      de: "KOSTENLOS", it: "GRATIS", ru: "БЕСПЛАТНО", pl: "ZA DARMO",
      tr: "ÜCRETSİZ",
    },
    "hero.tag.noinstall": {
      pt_BR: "SEM INSTALAR", en: "NO INSTALL", es: "SIN INSTALAR",
      fr: "SANS INSTALLATION", de: "OHNE INSTALLATION",
      it: "SENZA INSTALLARE", ru: "БЕЗ УСТАНОВКИ", pl: "BEZ INSTALACJI",
      tr: "KURULUM YOK",
    },
    "hero.tag.genre": {
      pt_BR: "CLICKER", en: "CLICKER", es: "CLICKER", fr: "CLICKER",
      de: "CLICKER", it: "CLICKER", ru: "CLICKER", pl: "CLICKER",
      tr: "CLICKER",
    },
    // The ticker: one string, split on "|" so a language can drop or reorder
    // an item without the markup changing. It is the night shift talking to
    // itself, so the last two lines are not about the game at all.
    "wire": {
      pt_BR: "TERMINAL 01 ONLINE|NAVIO NO BERÇO 2|PÁTIO 62%|TURNO DA NOITE|O GATO DORMIU NO CONTÊINER|NINGUÉM FOI EMBORA",
      en: "TERMINAL 01 ONLINE|SHIP AT BERTH 2|YARD 62%|NIGHT SHIFT|THE CAT SLEPT IN A CONTAINER|NOBODY WENT HOME",
      es: "TERMINAL 01 EN LÍNEA|BARCO EN EL PUESTO 2|PATIO 62%|TURNO DE NOCHE|EL GATO DURMIÓ EN UN CONTENEDOR|NADIE SE FUE",
      fr: "TERMINAL 01 EN LIGNE|NAVIRE AU POSTE 2|PARC 62%|ÉQUIPE DE NUIT|LE CHAT A DORMI DANS UN CONTENEUR|PERSONNE N'EST RENTRÉ",
      de: "TERMINAL 01 ONLINE|SCHIFF AN LIEGEPLATZ 2|LAGER 62%|NACHTSCHICHT|DIE KATZE SCHLIEF IM CONTAINER|NIEMAND IST HEIM",
      it: "TERMINAL 01 ONLINE|NAVE ALL'ACCOSTO 2|PIAZZALE 62%|TURNO DI NOTTE|IL GATTO HA DORMITO IN UN CONTAINER|NESSUNO È ANDATO A CASA",
      ru: "ТЕРМИНАЛ 01 ОНЛАЙН|СУДНО У ПРИЧАЛА 2|ПЛОЩАДКА 62%|НОЧНАЯ СМЕНА|КОТ СПАЛ В КОНТЕЙНЕРЕ|НИКТО НЕ УШЁЛ ДОМОЙ",
      pl: "TERMINAL 01 ONLINE|STATEK PRZY NABRZEŻU 2|PLAC 62%|NOCNA ZMIANA|KOT SPAŁ W KONTENERZE|NIKT NIE POSZEDŁ DO DOMU",
      tr: "TERMİNAL 01 ÇEVRİMİÇİ|GEMİ 2 NOLU RIHTIMDA|SAHA %62|GECE VARDİYASI|KEDİ KONTEYNERDE UYUDU|KİMSE EVE GİTMEDİ",
    },
    "loop.title": {
      pt_BR: "COMO FUNCIONA", en: "HOW IT WORKS", es: "CÓMO FUNCIONA",
      fr: "COMMENT ÇA MARCHE", de: "WIE ES LÄUFT", it: "COME FUNZIONA",
      ru: "КАК ЭТО РАБОТАЕТ", pl: "JAK TO DZIAŁA", tr: "NASIL İŞLİYOR",
    },
    "step.1.title": {
      pt_BR: "CLICA", en: "TAP", es: "TOCA", fr: "CLIQUE", de: "TIPPEN",
      it: "TOCCA", ru: "ЖМИ", pl: "KLIKAJ", tr: "DOKUN",
    },
    "step.1.body": {
      pt_BR: "Cada caixa que desce vira dinheiro.",
      en: "Every box that comes down is money.",
      es: "Cada caja que baja es dinero.",
      fr: "Chaque caisse qui descend, c'est de l'argent.",
      de: "Jede Box, die runterkommt, ist Geld.",
      it: "Ogni cassa che scende è denaro.",
      ru: "Каждый ящик — это деньги.",
      pl: "Każda skrzynia to pieniądze.",
      tr: "İnen her kutu para.",
    },
    "step.2.title": {
      pt_BR: "COMPRA", en: "BUY", es: "COMPRA", fr: "ACHÈTE", de: "KAUFEN",
      it: "COMPRA", ru: "ПОКУПАЙ", pl: "KUPUJ", tr: "SATIN AL",
    },
    "step.2.body": {
      pt_BR: "Guindaste, empilhadeira, caminhão. Aí anda sozinho.",
      en: "Cranes, stackers, trucks. Then it runs itself.",
      es: "Grúas, apiladoras, camiones. Y anda solo.",
      fr: "Grues, chariots, camions. Et ça tourne tout seul.",
      de: "Kräne, Stapler, Lkw. Dann läuft es allein.",
      it: "Gru, carrelli, camion. Poi va da solo.",
      ru: "Краны, погрузчики, тягачи. Дальше само.",
      pl: "Dźwigi, wózki, ciągniki. Potem samo chodzi.",
      tr: "Vinç, istifleyici, kamyon. Sonra kendi döner.",
    },
    "step.3.title": {
      pt_BR: "CRESCE", en: "GROW", es: "CRECE", fr: "AGRANDIS",
      de: "WACHSEN", it: "CRESCI", ru: "РАСТИ", pl: "ROŚNIJ", tr: "BÜYÜT",
    },
    "step.3.body": {
      pt_BR: "Terreno, rota, porto novo. Os números incham.",
      en: "Land, routes, new ports. The numbers get silly.",
      es: "Terreno, rutas, puertos nuevos. Los números se inflan.",
      fr: "Terrain, routes, nouveaux ports. Les chiffres gonflent.",
      de: "Flächen, Routen, neue Häfen. Die Zahlen platzen.",
      it: "Terreni, rotte, porti nuovi. I numeri esplodono.",
      ru: "Земля, маршруты, новые порты. Числа пухнут.",
      pl: "Działki, trasy, nowe porty. Liczby puchną.",
      tr: "Arazi, rota, yeni liman. Sayılar şişer.",
    },
    "yard.title": {
      pt_BR: "O QUE TEM DENTRO", en: "WHAT'S IN IT", es: "QUÉ TIENE DENTRO",
      fr: "CE QU'IL Y A DEDANS", de: "WAS DRIN IST", it: "COSA C'È DENTRO",
      ru: "ЧТО ВНУТРИ", pl: "CO JEST W ŚRODKU", tr: "İÇİNDE NE VAR",
    },
    "yard.1.title": {
      pt_BR: "15 MÁQUINAS", en: "15 MACHINES", es: "15 MÁQUINAS",
      fr: "15 MACHINES", de: "15 MASCHINEN", it: "15 MACCHINE",
      ru: "15 МАШИН", pl: "15 MASZYN", tr: "15 MAKİNE",
    },
    "yard.1.body": {
      pt_BR: "Da empilhadeira ao portal orbital.",
      en: "From a forklift to an orbital gate.",
      es: "De la carretilla al portal orbital.",
      fr: "Du chariot au portail orbital.",
      de: "Vom Stapler bis zum Orbitaltor.",
      it: "Dal carrello al portale orbitale.",
      ru: "От погрузчика до орбитальных ворот.",
      pl: "Od wózka po bramę orbitalną.",
      tr: "Forkliftten yörünge kapısına.",
    },
    "yard.2.title": {
      pt_BR: "PRESTÍGIO", en: "PRESTIGE", es: "PRESTIGIO", fr: "PRESTIGE",
      de: "PRESTIGE", it: "PRESTIGIO", ru: "ПРЕСТИЖ", pl: "PRESTIŻ",
      tr: "PRESTİJ",
    },
    "yard.2.body": {
      pt_BR: "Recomeça e ganha +2% pra sempre.",
      en: "Start over, keep +2% forever.",
      es: "Empieza de nuevo, +2% para siempre.",
      fr: "Recommence, +2 % à vie.",
      de: "Von vorn, dauerhaft +2 %.",
      it: "Ricominci e tieni +2% per sempre.",
      ru: "Начни заново, +2% навсегда.",
      pl: "Zacznij od nowa, +2% na zawsze.",
      tr: "Baştan başla, kalıcı +%2.",
    },
    "yard.3.title": {
      pt_BR: "9 IDIOMAS", en: "9 LANGUAGES", es: "9 IDIOMAS", fr: "9 LANGUES",
      de: "9 SPRACHEN", it: "9 LINGUE", ru: "9 ЯЗЫКОВ", pl: "9 JĘZYKÓW",
      tr: "9 DİL",
    },
    "yard.3.body": {
      pt_BR: "Pega o do seu celular.",
      en: "It picks your phone's.",
      es: "Coge el de tu móvil.",
      fr: "Il prend celle de ton téléphone.",
      de: "Nimmt die deines Handys.",
      it: "Prende quella del telefono.",
      ru: "Берёт язык твоего телефона.",
      pl: "Bierze ten z telefonu.",
      tr: "Telefonunkini alır.",
    },
    "yard.4.title": {
      pt_BR: "UM GATO", en: "A CAT", es: "UN GATO", fr: "UN CHAT",
      de: "EINE KATZE", it: "UN GATTO", ru: "КОТ", pl: "KOT",
      tr: "BİR KEDİ",
    },
    "yard.4.body": {
      pt_BR: "Mora no pátio. Pode clicar nele.",
      en: "Lives in the yard. You can tap it.",
      es: "Vive en el patio. Puedes tocarlo.",
      fr: "Il vit sur le parc. Tu peux le toucher.",
      de: "Wohnt im Lager. Du darfst sie antippen.",
      it: "Vive sul piazzale. Puoi toccarlo.",
      ru: "Живёт на площадке. Его можно тыкать.",
      pl: "Mieszka na placu. Można go klikać.",
      tr: "Sahada yaşıyor. Dokunabilirsin.",
    },
    "manifest.title": {
      pt_BR: "O COMBINADO", en: "THE DEAL", es: "EL TRATO", fr: "LE DEAL",
      de: "DIE ABMACHUNG", it: "IL PATTO", ru: "УГОВОР", pl: "UMOWA",
      tr: "ANLAŞMA",
    },
    "manifest.rule.1": {
      pt_BR: "Anúncio nenhum.", en: "No ads.", es: "Ningún anuncio.",
      fr: "Aucune pub.", de: "Keine Werbung.", it: "Zero pubblicità.",
      ru: "Никакой рекламы.", pl: "Zero reklam.", tr: "Reklam yok.",
    },
    "manifest.rule.2": {
      pt_BR: "Cadastro nenhum.", en: "No sign-up.", es: "Ningún registro.",
      fr: "Aucune inscription.", de: "Keine Anmeldung.",
      it: "Nessuna registrazione.", ru: "Никакой регистрации.",
      pl: "Żadnej rejestracji.", tr: "Kayıt yok.",
    },
    "manifest.rule.3": {
      pt_BR: "Salva sozinho no navegador.",
      en: "Saves itself in your browser.",
      es: "Se guarda solo en tu navegador.",
      fr: "Ça sauvegarde tout seul dans le navigateur.",
      de: "Speichert von selbst im Browser.",
      it: "Si salva da solo nel browser.",
      ru: "Сохраняется само в браузере.",
      pl: "Zapisuje się samo w przeglądarce.",
      tr: "Tarayıcında kendi kaydeder.",
    },
    "manifest.rule.4": {
      pt_BR: "O gato fica.", en: "The cat stays.", es: "El gato se queda.",
      fr: "Le chat reste.", de: "Die Katze bleibt.", it: "Il gatto resta.",
      ru: "Кот остаётся.", pl: "Kot zostaje.", tr: "Kedi kalıyor.",
    },
    "manifest.stamp": {
      pt_BR: "OK", en: "OK", es: "OK", fr: "OK", de: "OK", it: "OK",
      ru: "OK", pl: "OK", tr: "OK",
    },
    "cta.coin": {
      pt_BR: "INSIRA A FICHA", en: "INSERT COIN", es: "INSERTA LA FICHA",
      fr: "INSÉREZ UN JETON", de: "MÜNZE EINWERFEN",
      it: "INSERISCI IL GETTONE", ru: "БРОСЬТЕ ЖЕТОН", pl: "WRZUĆ ŻETON",
      tr: "JETON AT",
    },
    "cta.title": {
      pt_BR: "BORA JOGAR", en: "GO ON, PLAY IT", es: "VENGA, JUEGA",
      fr: "ALLEZ, JOUE", de: "LOS, SPIEL", it: "DAI, GIOCA",
      ru: "НУ, ИГРАЙ", pl: "NO TO GRAJ", tr: "HADİ OYNA",
    },
    "cta.body": {
      pt_BR: "Não precisa baixar nada.", en: "Nothing to download.",
      es: "No hay que bajar nada.", fr: "Rien à télécharger.",
      de: "Nichts herunterladen.", it: "Niente da scaricare.",
      ru: "Ничего скачивать не надо.", pl: "Nic nie trzeba pobierać.",
      tr: "İndirilecek bir şey yok.",
    },
    "cta.button": {
      pt_BR: "JOGAR", en: "PLAY", es: "JUGAR", fr: "JOUER", de: "SPIELEN",
      it: "GIOCA", ru: "ИГРАТЬ", pl: "GRAJ", tr: "OYNA",
    },
    "footer.made": {
      pt_BR: "HARBORCLICK · FEITO EM CASA, EM PIXELS",
      en: "HARBORCLICK · MADE AT HOME, IN PIXELS",
      es: "HARBORCLICK · HECHO EN CASA, EN PÍXELES",
      fr: "HARBORCLICK · FAIT MAISON, EN PIXELS",
      de: "HARBORCLICK · ZU HAUSE GEMACHT, AUS PIXELN",
      it: "HARBORCLICK · FATTO IN CASA, A PIXEL",
      ru: "HARBORCLICK · СДЕЛАНО ДОМА, ИЗ ПИКСЕЛЕЙ",
      pl: "HARBORCLICK · ZROBIONE W DOMU, Z PIKSELI",
      tr: "HARBORCLICK · EVDE YAPILDI, PİKSELLERDEN",
    },
  };

  const codes = LANGUAGES.map((entry) => entry[0]);
  const meta = (code) => LANGUAGES[codes.indexOf(code)];

  const t = (key, code) => {
    const row = S[key];
    if (!row) return key;
    return row[code] || row[FALLBACK] || key;
  };

  function fromDevice() {
    const wanted = navigator.languages || [navigator.language || ""];
    for (const tag of wanted) {
      const hit = DEVICE[String(tag).toLowerCase().split("-")[0]];
      if (hit) return hit;
    }
    return FALLBACK;
  }

  function stored() {
    try {
      return localStorage.getItem("harborclick.lang");
    } catch (error) {
      return null;                      // private mode, or storage disabled
    }
  }

  function remember(code) {
    try {
      localStorage.setItem("harborclick.lang", code);
    } catch (error) {
      /* a language that cannot be saved is still a language worth showing */
    }
  }

  // ------------------------------------------------------------------ apply
  function apply(code) {
    const entry = meta(code);
    if (!entry) return;
    const [, tag, native, htmlLang] = entry;

    document.documentElement.lang = htmlLang;
    document.title = t("doc.title", code);
    const description = document.querySelector('meta[name="description"]');
    if (description) description.content = t("doc.desc", code);

    document.querySelectorAll("[data-i18n]").forEach((node) => {
      node.textContent = t(node.dataset.i18n, code);
    });
    document.querySelectorAll("[data-i18n-label]").forEach((node) => {
      node.setAttribute("aria-label", t(node.dataset.i18nLabel, code));
    });

    // The marquee is two identical halves so it can loop seamlessly; both are
    // rebuilt from the same list.
    const items = t("wire", code).split("|");
    document.querySelectorAll("[data-wire]").forEach((tape) => {
      tape.innerHTML = "";
      items.forEach((item) => {
        const line = document.createElement("span");
        line.textContent = item;
        tape.append(line, Object.assign(document.createElement("i"), {
          className: "mark m-dia", ariaHidden: "true",
        }));
      });
    });

    document.querySelectorAll("[data-lang-tag]").forEach((node) => {
      node.textContent = tag;
    });
    const button = document.getElementById("lang-btn");
    if (button) {
      button.setAttribute("aria-label", `${t("lang.label", code)}: ${native}`);
    }
    document.querySelectorAll("#lang-list [data-code]").forEach((option) => {
      option.setAttribute("aria-selected", String(option.dataset.code === code));
    });
    document.documentElement.dataset.lang = code;
  }

  // ----------------------------------------------------------------- picker
  function buildPicker(current, choose) {
    const list = document.getElementById("lang-list");
    const button = document.getElementById("lang-btn");
    if (!list || !button) return;

    LANGUAGES.forEach(([code, tag, native]) => {
      const option = document.createElement("li");
      option.role = "option";
      option.tabIndex = -1;
      option.dataset.code = code;
      option.setAttribute("aria-selected", String(code === current));
      option.innerHTML = `<b>${tag}</b><span>${native}</span>`;
      option.addEventListener("click", () => {
        choose(code);
        close(true);
      });
      list.append(option);
    });

    const open = () => {
      list.hidden = false;
      button.setAttribute("aria-expanded", "true");
      const selected = list.querySelector('[aria-selected="true"]') ||
        list.firstElementChild;
      selected.focus();
    };

    function close(refocus) {
      list.hidden = true;
      button.setAttribute("aria-expanded", "false");
      if (refocus) button.focus();
    }

    button.addEventListener("click", () => {
      if (list.hidden) open(); else close(true);
    });

    list.addEventListener("keydown", (event) => {
      const options = [...list.children];
      const index = options.indexOf(document.activeElement);
      if (event.key === "ArrowDown" || event.key === "ArrowUp") {
        event.preventDefault();
        const step = event.key === "ArrowDown" ? 1 : -1;
        options[(index + step + options.length) % options.length].focus();
      } else if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        document.activeElement.click();
      } else if (event.key === "Escape") {
        close(true);
      } else if (event.key === "Home" || event.key === "End") {
        event.preventDefault();
        options[event.key === "Home" ? 0 : options.length - 1].focus();
      }
    });

    document.addEventListener("pointerdown", (event) => {
      if (!list.hidden && !event.target.closest(".lang")) close(false);
    });
    document.addEventListener("focusin", (event) => {
      if (!list.hidden && !event.target.closest(".lang")) close(false);
    });
  }

  // ------------------------------------------------------------------ start
  const asked = new URLSearchParams(location.search).get("lang");
  const start = [asked, stored(), fromDevice()]
    .find((code) => code && codes.includes(code)) || FALLBACK;

  buildPicker(start, (code) => {
    remember(code);
    apply(code);
  });
  apply(start);
})();
