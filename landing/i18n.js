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
      pt_BR: "HarborClick — o porto nunca dorme",
      en: "HarborClick — the port never sleeps",
      es: "HarborClick — el puerto nunca duerme",
      fr: "HarborClick — le port ne dort jamais",
      de: "HarborClick — der Hafen schläft nie",
      it: "HarborClick — il porto non dorme mai",
      ru: "HarborClick — порт никогда не спит",
      pl: "HarborClick — port nigdy nie śpi",
      tr: "HarborClick — liman hiç uyumaz",
    },
    "doc.desc": {
      pt_BR: "Um porto de contêineres em pixel art. Descarregue navios, compre máquinas e veja o terminal girar sozinho. Grátis, no navegador.",
      en: "A pixel-art container port. Unload ships, buy machines and watch the terminal run itself. Free, in your browser.",
      es: "Un puerto de contenedores en pixel art. Descarga barcos, compra máquinas y mira la terminal girar sola. Gratis, en el navegador.",
      fr: "Un port à conteneurs en pixel art. Déchargez des navires, achetez des machines et regardez le terminal tourner seul. Gratuit, dans le navigateur.",
      de: "Ein Containerhafen in Pixel Art. Schiffe löschen, Maschinen kaufen und dem Terminal beim Laufen zusehen. Kostenlos, im Browser.",
      it: "Un porto container in pixel art. Scarica navi, compra macchine e guarda il terminal girare da solo. Gratis, nel browser.",
      ru: "Контейнерный порт в пиксель-арте. Разгружайте суда, покупайте технику и смотрите, как терминал работает сам. Бесплатно, в браузере.",
      pl: "Port kontenerowy w pixel arcie. Rozładowuj statki, kupuj maszyny i patrz, jak terminal kręci się sam. Za darmo, w przeglądarce.",
      tr: "Piksel sanatıyla bir konteyner limanı. Gemileri boşalt, makine satın al ve terminalin kendi kendine dönüşünü izle. Ücretsiz, tarayıcıda.",
    },
    "skip": {
      pt_BR: "Pular para o conteúdo", en: "Skip to content",
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
    "hero.tagline": {
      pt_BR: "O PORTO NUNCA DORME", en: "THE PORT NEVER SLEEPS",
      es: "EL PUERTO NUNCA DUERME", fr: "LE PORT NE DORT JAMAIS",
      de: "DER HAFEN SCHLÄFT NIE", it: "IL PORTO NON DORME MAI",
      ru: "ПОРТ НИКОГДА НЕ СПИТ", pl: "PORT NIGDY NIE ŚPI",
      tr: "LİMAN HİÇ UYUMAZ",
    },
    "hero.pitch": {
      pt_BR: "Navios chegam a noite inteira. Cada caixa que desce é sua — e o cais só cresce.",
      en: "Ships come in all night. Every box that lands is yours — and the quay only grows.",
      es: "Los barcos llegan toda la noche. Cada caja que baja es tuya, y el muelle solo crece.",
      fr: "Les navires arrivent toute la nuit. Chaque caisse qui descend est à vous — et le quai ne fait que grandir.",
      de: "Die ganze Nacht kommen Schiffe. Jede Box, die runtergeht, gehört dir — und der Kai wächst weiter.",
      it: "Le navi arrivano tutta la notte. Ogni cassa che scende è tua — e la banchina non fa che crescere.",
      ru: "Суда приходят всю ночь. Каждый ящик, который сошёл на берег, — ваш, и причал только растёт.",
      pl: "Statki przychodzą całą noc. Każda skrzynia, która schodzi, jest twoja — a nabrzeże tylko rośnie.",
      tr: "Gemiler bütün gece gelir. İnen her kutu senindir — ve rıhtım yalnızca büyür.",
    },
    "hero.cta": {
      pt_BR: "JOGAR AGORA", en: "PLAY NOW", es: "JUGAR AHORA",
      fr: "JOUER MAINTENANT", de: "JETZT SPIELEN", it: "GIOCA ORA",
      ru: "ИГРАТЬ СЕЙЧАС", pl: "GRAJ TERAZ", tr: "HEMEN OYNA",
    },
    "hero.cue": {
      pt_BR: "DESÇA AO CAIS", en: "DOWN TO THE QUAY", es: "BAJA AL MUELLE",
      fr: "DESCENDRE AU QUAI", de: "RUNTER ZUM KAI", it: "SCENDI IN BANCHINA",
      ru: "ВНИЗ К ПРИЧАЛУ", pl: "ZEJDŹ NA NABRZEŻE", tr: "RIHTIMA İN",
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
    "hero.tag.mobile": {
      pt_BR: "FEITO PRA CELULAR", en: "BUILT FOR PHONES",
      es: "HECHO PARA MÓVIL", fr: "PENSÉ POUR MOBILE",
      de: "FÜRS HANDY GEBAUT", it: "PENSATO PER IL TELEFONO",
      ru: "СДЕЛАНО ДЛЯ ТЕЛЕФОНА", pl: "POD TELEFON", tr: "TELEFON İÇİN",
    },
    // The ticker: one string, split on "|" so a language can drop or reorder
    // an item without the markup changing.
    "wire": {
      pt_BR: "TERMINAL 01 ONLINE|NAVIO ATRACADO NO BERÇO 2|4 GUINDASTES ATIVOS|PÁTIO 62%|TURNO DA NOITE|NENHUMA PAUSA|NOVE IDIOMAS A BORDO",
      en: "TERMINAL 01 ONLINE|SHIP ALONGSIDE AT BERTH 2|4 CRANES WORKING|YARD 62%|NIGHT SHIFT|NO BREAKS|NINE LANGUAGES ABOARD",
      es: "TERMINAL 01 EN LÍNEA|BARCO ATRACADO EN EL PUESTO 2|4 GRÚAS ACTIVAS|PATIO 62%|TURNO DE NOCHE|SIN PAUSAS|NUEVE IDIOMAS A BORDO",
      fr: "TERMINAL 01 EN LIGNE|NAVIRE À QUAI AU POSTE 2|4 GRUES EN SERVICE|PARC 62%|ÉQUIPE DE NUIT|AUCUNE PAUSE|NEUF LANGUES À BORD",
      de: "TERMINAL 01 ONLINE|SCHIFF AN LIEGEPLATZ 2|4 KRÄNE IM EINSATZ|LAGER 62%|NACHTSCHICHT|KEINE PAUSE|NEUN SPRACHEN AN BORD",
      it: "TERMINAL 01 ONLINE|NAVE ORMEGGIATA ALL'ACCOSTO 2|4 GRU IN AZIONE|PIAZZALE 62%|TURNO DI NOTTE|NESSUNA PAUSA|NOVE LINGUE A BORDO",
      ru: "ТЕРМИНАЛ 01 ОНЛАЙН|СУДНО У ПРИЧАЛА 2|4 КРАНА В РАБОТЕ|ПЛОЩАДКА 62%|НОЧНАЯ СМЕНА|БЕЗ ПЕРЕРЫВОВ|ДЕВЯТЬ ЯЗЫКОВ НА БОРТУ",
      pl: "TERMINAL 01 ONLINE|STATEK PRZY NABRZEŻU 2|4 DŹWIGI W RUCHU|PLAC 62%|NOCNA ZMIANA|ŻADNEJ PRZERWY|DZIEWIĘĆ JĘZYKÓW NA POKŁADZIE",
      tr: "TERMİNAL 01 ÇEVRİMİÇİ|GEMİ 2 NOLU RIHTIMDA|4 VİNÇ ÇALIŞIYOR|SAHA %62|GECE VARDİYASI|MOLA YOK|GEMİDE DOKUZ DİL",
    },
    "loop.eyebrow": {
      pt_BR: "COMO O PORTO GIRA", en: "HOW THE PORT TURNS",
      es: "CÓMO GIRA EL PUERTO", fr: "COMMENT LE PORT TOURNE",
      de: "WIE DER HAFEN LÄUFT", it: "COME GIRA IL PORTO",
      ru: "КАК КРУТИТСЯ ПОРТ", pl: "JAK KRĘCI SIĘ PORT",
      tr: "LİMAN NASIL DÖNER",
    },
    "loop.title.a": {
      pt_BR: "UMA CAIXA VIRA", en: "ONE BOX BECOMES",
      es: "UNA CAJA SE VUELVE", fr: "UNE CAISSE DEVIENT",
      de: "AUS EINER BOX WIRD", it: "UNA CASSA DIVENTA",
      ru: "ОДИН ЯЩИК СТАНЕТ", pl: "JEDNA SKRZYNIA TO", tr: "BİR KUTU",
    },
    "loop.title.b": {
      pt_BR: "UM TERMINAL INTEIRO", en: "A WHOLE TERMINAL",
      es: "UNA TERMINAL ENTERA", fr: "UN TERMINAL ENTIER",
      de: "EIN GANZES TERMINAL", it: "UN TERMINAL INTERO",
      ru: "ЦЕЛЫМ ТЕРМИНАЛОМ", pl: "CAŁY TERMINAL",
      tr: "KOCA BİR TERMİNAL OLUR",
    },
    "step.1.title": {
      pt_BR: "DESCARREGUE", en: "UNLOAD", es: "DESCARGA", fr: "DÉCHARGEZ",
      de: "LÖSCHEN", it: "SCARICA", ru: "РАЗГРУЖАЙТЕ", pl: "ROZŁADUJ",
      tr: "BOŞALT",
    },
    "step.1.body": {
      pt_BR: "Toque no navio atracado. O guindaste desce, a caixa sobe no pátio e o dinheiro entra.",
      en: "Tap the berthed ship. The crane drops, the box lands in the yard, the money comes in.",
      es: "Toca el barco atracado. La grúa baja, la caja sube al patio y entra el dinero.",
      fr: "Touchez le navire à quai. La grue descend, la caisse monte au parc et l'argent rentre.",
      de: "Tipp das Schiff am Kai an. Der Kran senkt sich, die Box landet im Lager, das Geld kommt rein.",
      it: "Tocca la nave ormeggiata. La gru scende, la cassa sale sul piazzale e il denaro entra.",
      ru: "Нажмите на судно у причала. Кран опускается, ящик встаёт на площадку, деньги идут.",
      pl: "Dotknij zacumowanego statku. Dźwig schodzi, skrzynia ląduje na placu, a pieniądze wpadają.",
      tr: "Rıhtımdaki gemiye dokun. Vinç iner, kutu sahaya çıkar ve para girer.",
    },
    "step.2.title": {
      pt_BR: "AUTOMATIZE", en: "AUTOMATE", es: "AUTOMATIZA",
      fr: "AUTOMATISEZ", de: "AUTOMATISIEREN", it: "AUTOMATIZZA",
      ru: "АВТОМАТИЗИРУЙТЕ", pl: "ZAUTOMATYZUJ", tr: "OTOMATİKLEŞTİR",
    },
    "step.2.body": {
      pt_BR: "Compre pórtico, transtêiner, empilhadeira e caminhão. O pátio passa a andar sem você.",
      en: "Buy gantries, straddle carriers, reach stackers and trucks. The yard starts running without you.",
      es: "Compra pórticos, apiladoras, carretillas y camiones. El patio empieza a andar sin ti.",
      fr: "Achetez portiques, cavaliers, chariots et camions. Le parc se met à tourner sans vous.",
      de: "Kauf Portalkräne, Portalhubwagen, Stapler und Lkw. Das Lager läuft dann ohne dich.",
      it: "Compra portainer, gru semoventi, carrelli e camion. Il piazzale inizia ad andare senza di te.",
      ru: "Купите причальные краны, штабелёры, погрузчики и тягачи. Площадка поедет без вас.",
      pl: "Kup suwnice, układarki, wózki i ciągniki. Plac zacznie chodzić bez ciebie.",
      tr: "Rıhtım vinci, istifleyici, forklift ve kamyon al. Saha sensiz dönmeye başlar.",
    },
    "step.3.title": {
      pt_BR: "EXPANDA", en: "EXPAND", es: "EXPANDE", fr: "AGRANDISSEZ",
      de: "AUSBAUEN", it: "ESPANDI", ru: "РАСШИРЯЙТЕСЬ", pl: "ROZBUDUJ",
      tr: "BÜYÜT",
    },
    "step.3.body": {
      pt_BR: "Abra terreno, abra rota, abra porto novo. O mapa inteiro vira destino de carga.",
      en: "Open land, open routes, open new ports. The whole map turns into cargo destination.",
      es: "Abre terreno, abre rutas, abre puertos nuevos. Todo el mapa se vuelve destino de carga.",
      fr: "Ouvrez du terrain, des routes, de nouveaux ports. La carte entière devient une destination.",
      de: "Öffne Flächen, Routen, neue Häfen. Die ganze Karte wird zum Ziel.",
      it: "Apri terreni, apri rotte, apri porti nuovi. Tutta la mappa diventa destinazione.",
      ru: "Открывайте землю, маршруты, новые порты. Вся карта станет точкой назначения.",
      pl: "Otwieraj działki, trasy, nowe porty. Cała mapa staje się celem ładunku.",
      tr: "Arazi aç, rota aç, yeni liman aç. Harita bütünüyle yük varış noktası olur.",
    },
    "yard.eyebrow": {
      pt_BR: "O QUE TEM NO CAIS", en: "WHAT'S ON THE QUAY",
      es: "QUÉ HAY EN EL MUELLE", fr: "CE QU'IL Y A SUR LE QUAI",
      de: "WAS AM KAI STEHT", it: "COSA C'È IN BANCHINA",
      ru: "ЧТО ЕСТЬ НА ПРИЧАЛЕ", pl: "CO STOI NA NABRZEŻU",
      tr: "RIHTIMDA NE VAR",
    },
    "yard.title.a": {
      pt_BR: "UM TERMINAL", en: "A TERMINAL", es: "UNA TERMINAL",
      fr: "UN TERMINAL", de: "EIN TERMINAL", it: "UN TERMINAL",
      ru: "ТЕРМИНАЛ", pl: "TERMINAL", tr: "DURMAYAN",
    },
    "yard.title.b": {
      pt_BR: "QUE NÃO PARA", en: "THAT NEVER STOPS", es: "QUE NO PARA",
      fr: "QUI NE S'ARRÊTE PAS", de: "DAS NIE STILLSTEHT",
      it: "CHE NON SI FERMA", ru: "КОТОРЫЙ НЕ СТОИТ",
      pl: "KTÓRY NIE STOI", tr: "BİR TERMİNAL",
    },
    "yard.1.title": {
      pt_BR: "15 MÁQUINAS", en: "15 MACHINES", es: "15 MÁQUINAS",
      fr: "15 MACHINES", de: "15 MASCHINEN", it: "15 MACCHINE",
      ru: "15 МАШИН", pl: "15 MASZYN", tr: "15 MAKİNE",
    },
    "yard.1.body": {
      pt_BR: "Do reach stacker ao portal orbital. Cada terreno aberto libera a próxima.",
      en: "From the reach stacker to the orbital gate. Every plot you open unlocks the next one.",
      es: "De la apiladora al portal orbital. Cada parcela que abres libera la siguiente.",
      fr: "Du chariot élévateur au portail orbital. Chaque parcelle ouverte débloque la suivante.",
      de: "Vom Reachstacker bis zum Orbitaltor. Jede Fläche schaltet die nächste frei.",
      it: "Dal reach stacker al portale orbitale. Ogni lotto aperto sblocca il successivo.",
      ru: "От ричстакера до орбитальных ворот. Каждый открытый участок даёт следующую.",
      pl: "Od reachstackera po bramę orbitalną. Każda otwarta działka odblokowuje następną.",
      tr: "İstifleyiciden yörünge kapısına. Açtığın her parsel bir sonrakini açar.",
    },
    "yard.2.title": {
      pt_BR: "NOVE IDIOMAS", en: "NINE LANGUAGES", es: "NUEVE IDIOMAS",
      fr: "NEUF LANGUES", de: "NEUN SPRACHEN", it: "NOVE LINGUE",
      ru: "ДЕВЯТЬ ЯЗЫКОВ", pl: "DZIEWIĘĆ JĘZYKÓW", tr: "DOKUZ DİL",
    },
    "yard.2.body": {
      pt_BR: "Português, inglês, espanhol, francês, alemão, italiano, russo, polonês e turco.",
      en: "Portuguese, English, Spanish, French, German, Italian, Russian, Polish and Turkish.",
      es: "Portugués, inglés, español, francés, alemán, italiano, ruso, polaco y turco.",
      fr: "Portugais, anglais, espagnol, français, allemand, italien, russe, polonais et turc.",
      de: "Portugiesisch, Englisch, Spanisch, Französisch, Deutsch, Italienisch, Russisch, Polnisch und Türkisch.",
      it: "Portoghese, inglese, spagnolo, francese, tedesco, italiano, russo, polacco e turco.",
      ru: "Португальский, английский, испанский, французский, немецкий, итальянский, русский, польский и турецкий.",
      pl: "Portugalski, angielski, hiszpański, francuski, niemiecki, włoski, rosyjski, polski i turecki.",
      tr: "Portekizce, İngilizce, İspanyolca, Fransızca, Almanca, İtalyanca, Rusça, Lehçe ve Türkçe.",
    },
    "yard.3.title": {
      pt_BR: "ABRIR CAPITAL", en: "GO PUBLIC", es: "SALIR A BOLSA",
      fr: "ENTRER EN BOURSE", de: "AN DIE BÖRSE", it: "QUOTARSI",
      ru: "ВЫЙТИ НА БИРЖУ", pl: "WEJŚĆ NA GIEŁDĘ", tr: "HALKA AÇIL",
    },
    "yard.3.body": {
      pt_BR: "Reinicie o porto por ações douradas. Cada uma vale +2% para sempre.",
      en: "Reset the port for golden shares. Each one is worth +2% forever.",
      es: "Reinicia el puerto por acciones doradas. Cada una vale +2% para siempre.",
      fr: "Relancez le port contre des actions dorées. Chacune vaut +2 % pour toujours.",
      de: "Setz den Hafen für goldene Anteile zurück. Jeder bringt dauerhaft +2 %.",
      it: "Riavvia il porto per azioni dorate. Ognuna vale +2% per sempre.",
      ru: "Перезапустите порт ради золотых акций. Каждая даёт +2% навсегда.",
      pl: "Zresetuj port za złote akcje. Każda daje +2% na zawsze.",
      tr: "Limanı altın hisseler için sıfırla. Her biri kalıcı olarak +%2 değerinde.",
    },
    "yard.4.title": {
      pt_BR: "TUDO EM PIXEL", en: "ALL PIXELS", es: "TODO PÍXEL",
      fr: "TOUT EN PIXELS", de: "ALLES PIXEL", it: "TUTTO PIXEL",
      ru: "ВСЁ ИЗ ПИКСЕЛЕЙ", pl: "SAME PIKSELE", tr: "HEPSİ PİKSEL",
    },
    "yard.4.body": {
      pt_BR: "Sprites, fonte e som gerados por código. Nada de loja de assets.",
      en: "Sprites, font and sound generated by code. No asset store.",
      es: "Sprites, fuente y sonido generados por código. Nada de tienda de assets.",
      fr: "Sprites, police et sons générés par le code. Aucune banque d'assets.",
      de: "Sprites, Schrift und Ton per Code erzeugt. Kein Asset-Store.",
      it: "Sprite, font e suoni generati dal codice. Nessun asset store.",
      ru: "Спрайты, шрифт и звук созданы кодом. Никаких магазинов ассетов.",
      pl: "Sprite'y, font i dźwięk generowane kodem. Żadnego sklepu z assetami.",
      tr: "Sprite, yazı tipi ve ses kodla üretildi. Asset mağazası yok.",
    },
    "manifest.code": {
      pt_BR: "MANIFESTO HC-001", en: "MANIFEST HC-001",
      es: "MANIFIESTO HC-001", fr: "MANIFESTE HC-001",
      de: "MANIFEST HC-001", it: "MANIFESTO HC-001",
      ru: "МАНИФЕСТ HC-001", pl: "MANIFEST HC-001", tr: "MANİFESTO HC-001",
    },
    "manifest.title.a": {
      pt_BR: "O QUE ESTE PORTO", en: "WHAT THIS PORT",
      es: "LO QUE ESTE PUERTO", fr: "CE QUE CE PORT",
      de: "WAS DIESER HAFEN", it: "QUELLO CHE QUESTO PORTO",
      ru: "ЧЕГО ЭТОТ ПОРТ", pl: "CZEGO TEN PORT", tr: "BU LİMANIN SANA",
    },
    "manifest.title.b": {
      pt_BR: "NÃO FAZ COM VOCÊ", en: "WON'T DO TO YOU",
      es: "NO TE VA A HACER", fr: "NE VOUS FERA PAS",
      de: "NICHT MIT DIR MACHT", it: "NON TI FARÀ",
      ru: "С ВАМИ НЕ СДЕЛАЕТ", pl: "CI NIE ZROBI",
      tr: "YAPMAYACAĞI ŞEYLER",
    },
    "manifest.rule.1": {
      pt_BR: "Nenhuma espera artificial pra te vender pressa.",
      en: "No fake waiting, sold back to you as a shortcut.",
      es: "Ninguna espera falsa para venderte prisa.",
      fr: "Aucune attente artificielle pour vous vendre de la hâte.",
      de: "Kein künstliches Warten, das dir Eile verkauft.",
      it: "Nessuna attesa finta per venderti fretta.",
      ru: "Никакого искусственного ожидания, чтобы продать вам спешку.",
      pl: "Żadnego sztucznego czekania, żeby sprzedać ci pośpiech.",
      tr: "Sana acele satmak için yapay bekleme yok.",
    },
    "manifest.rule.2": {
      pt_BR: "Nenhum anúncio, nenhum cadastro, nenhuma conta.",
      en: "No ads, no sign-up, no account.",
      es: "Sin anuncios, sin registro, sin cuenta.",
      fr: "Aucune publicité, aucune inscription, aucun compte.",
      de: "Keine Werbung, keine Anmeldung, kein Konto.",
      it: "Nessuna pubblicità, nessuna registrazione, nessun account.",
      ru: "Ни рекламы, ни регистрации, ни аккаунта.",
      pl: "Żadnych reklam, rejestracji ani konta.",
      tr: "Reklam yok, kayıt yok, hesap yok.",
    },
    "manifest.rule.3": {
      pt_BR: "Salva sozinho, no seu próprio navegador.",
      en: "Saves itself, in your own browser.",
      es: "Se guarda solo, en tu propio navegador.",
      fr: "Se sauvegarde seul, dans votre propre navigateur.",
      de: "Speichert von selbst, in deinem eigenen Browser.",
      it: "Si salva da solo, nel tuo browser.",
      ru: "Сохраняется сам, в вашем браузере.",
      pl: "Zapisuje się sam, w twojej przeglądarce.",
      tr: "Kendi kendine kaydeder, kendi tarayıcında.",
    },
    "manifest.rule.4": {
      pt_BR: "Um gato mora no pátio. Ele fica.",
      en: "A cat lives in the yard. It stays.",
      es: "Un gato vive en el patio. Se queda.",
      fr: "Un chat vit sur le parc. Il reste.",
      de: "Eine Katze wohnt im Lager. Sie bleibt.",
      it: "Un gatto vive sul piazzale. Resta lì.",
      ru: "На площадке живёт кот. Он остаётся.",
      pl: "Na placu mieszka kot. Zostaje.",
      tr: "Sahada bir kedi yaşıyor. Kalıyor.",
    },
    "manifest.stamp": {
      pt_BR: "LIBERADO", en: "CLEARED", es: "LIBERADO", fr: "AUTORISÉ",
      de: "FREIGEGEBEN", it: "AUTORIZZATO", ru: "РАЗРЕШЕНО",
      pl: "ODPRAWIONE", tr: "ONAYLANDI",
    },
    "cta.coin": {
      pt_BR: "INSIRA A FICHA", en: "INSERT COIN", es: "INSERTA LA FICHA",
      fr: "INSÉREZ UN JETON", de: "MÜNZE EINWERFEN",
      it: "INSERISCI IL GETTONE", ru: "БРОСЬТЕ ЖЕТОН", pl: "WRZUĆ ŻETON",
      tr: "JETON AT",
    },
    "cta.title.a": {
      pt_BR: "SEU TURNO", en: "YOUR SHIFT", es: "TU TURNO",
      fr: "VOTRE QUART", de: "DEINE SCHICHT", it: "IL TUO TURNO",
      ru: "ВАША СМЕНА", pl: "TWOJA ZMIANA", tr: "VARDİYAN",
    },
    "cta.title.b": {
      pt_BR: "COMEÇA AGORA", en: "STARTS NOW", es: "EMPIEZA YA",
      fr: "COMMENCE ICI", de: "BEGINNT JETZT", it: "INIZIA ORA",
      ru: "НАЧИНАЕТСЯ СЕЙЧАС", pl: "ZACZYNA SIĘ TERAZ",
      tr: "ŞİMDİ BAŞLIYOR",
    },
    "cta.body": {
      pt_BR: "Abre em segundos. Nada pra baixar.",
      en: "Opens in seconds. Nothing to download.",
      es: "Abre en segundos. Nada que descargar.",
      fr: "Ouvre en quelques secondes. Rien à télécharger.",
      de: "In Sekunden offen. Nichts zum Herunterladen.",
      it: "Si apre in pochi secondi. Niente da scaricare.",
      ru: "Открывается за секунды. Ничего не нужно скачивать.",
      pl: "Otwiera się w kilka sekund. Nic do pobrania.",
      tr: "Saniyeler içinde açılır. İndirilecek bir şey yok.",
    },
    "cta.button": {
      pt_BR: "ENTRAR NO PORTO", en: "ENTER THE PORT", es: "ENTRAR AL PUERTO",
      fr: "ENTRER DANS LE PORT", de: "IN DEN HAFEN", it: "ENTRA NEL PORTO",
      ru: "ВОЙТИ В ПОРТ", pl: "WEJDŹ DO PORTU", tr: "LİMANA GİR",
    },
    "footer.made": {
      pt_BR: "HARBORCLICK © 2026 · FEITO EM PIXELS",
      en: "HARBORCLICK © 2026 · MADE OF PIXELS",
      es: "HARBORCLICK © 2026 · HECHO DE PÍXELES",
      fr: "HARBORCLICK © 2026 · FAIT DE PIXELS",
      de: "HARBORCLICK © 2026 · AUS PIXELN GEMACHT",
      it: "HARBORCLICK © 2026 · FATTO DI PIXEL",
      ru: "HARBORCLICK © 2026 · СДЕЛАНО ИЗ ПИКСЕЛЕЙ",
      pl: "HARBORCLICK © 2026 · ZROBIONE Z PIKSELI",
      tr: "HARBORCLICK © 2026 · PİKSELLERDEN YAPILDI",
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
