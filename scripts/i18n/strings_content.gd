class_name LocStringsContent
## The game's content strings: the things the port is made of, rather than the
## chrome around them. Same shape as `LocStringsUi` — see its header.
##
## Place names are left alone. "Rio Grande - Itajaí" is where the ships actually
## go, and translating a port's name would make the chart wrong rather than
## friendlier. What gets translated is everything written *about* them.

const STRINGS := {

# ------------------------------------------------------------------- routes

"route.cabotagem.name": {
	"pt_BR": "Cabotagem Sul", "en": "Southern Coastal Run",
	"es": "Cabotaje Sur", "fr": "Cabotage Sud", "de": "Südküstenroute",
	"it": "Cabotaggio Sud", "ru": "Южный каботаж",
	"pl": "Żegluga przybrzeżna Południe", "tr": "Güney Kıyı Hattı"},
"route.cabotagem.desc": {
	"pt_BR": "Curta e constante. Sempre tem navio.",
	"en": "Short and steady. There is always a ship.",
	"es": "Corta y constante. Siempre hay barco.",
	"fr": "Courte et constante. Il y a toujours un navire.",
	"de": "Kurz und beständig. Es gibt immer ein Schiff.",
	"it": "Breve e costante. C'è sempre una nave.",
	"ru": "Короткий и постоянный. Судно есть всегда.",
	"pl": "Krótka i stała. Zawsze jest jakiś statek.",
	"tr": "Kısa ve sürekli. Her zaman bir gemi vardır."},

"route.prata.name": {
	"pt_BR": "Bacia do Prata", "en": "River Plate Basin",
	"es": "Cuenca del Plata", "fr": "Bassin du Río de la Plata",
	"de": "Río-de-la-Plata-Becken", "it": "Bacino del Río de la Plata",
	"ru": "Бассейн Ла-Платы", "pl": "Zlewnia Río de la Plata",
	"tr": "Río de la Plata Havzası"},
"route.prata.desc": {
	"pt_BR": "Mais volume sem sair de casa.",
	"en": "More volume without leaving home.",
	"es": "Más volumen sin salir de casa.",
	"fr": "Plus de volume sans quitter la maison.",
	"de": "Mehr Volumen, ohne von zu Hause wegzugehen.",
	"it": "Più volume senza uscire di casa.",
	"ru": "Больше объёма без дальних плаваний.",
	"pl": "Więcej wolumenu bez oddalania się od domu.",
	"tr": "Evden uzaklaşmadan daha fazla hacim."},

"route.caribe.name": {
	"pt_BR": "Corredor do Caribe", "en": "Caribbean Corridor",
	"es": "Corredor del Caribe", "fr": "Corridor des Caraïbes",
	"de": "Karibik-Korridor", "it": "Corridoio dei Caraibi",
	"ru": "Карибский коридор", "pl": "Korytarz Karaibski",
	"tr": "Karayip Koridoru"},
"route.caribe.desc": {
	"pt_BR": "Panamax começa a encostar no berço.",
	"en": "Panamax hulls start tying up alongside.",
	"es": "El Panamax empieza a atracar en el muelle.",
	"fr": "Le Panamax commence à accoster au quai.",
	"de": "Panamax-Schiffe beginnen am Kai anzulegen.",
	"it": "Le navi Panamax iniziano ad attraccare in banchina.",
	"ru": "Панамаксы уже начинают вставать к причалу.",
	"pl": "Statki Panamax zaczynają cumować przy nabrzeżu.",
	"tr": "Panamax gemileri rıhtıma yanaşmaya başlıyor."},

"route.atlantico.name": {
	"pt_BR": "Travessia Atlântica", "en": "Atlantic Crossing",
	"es": "Travesía Atlántica", "fr": "Traversée de l'Atlantique",
	"de": "Atlantiküberquerung", "it": "Traversata Atlantica",
	"ru": "Трансатлантический переход", "pl": "Przeprawa przez Atlantyk",
	"tr": "Atlantik Geçişi"},
"route.atlantico.desc": {
	"pt_BR": "Escala longa, frete alto, berço ocupado.",
	"en": "Long call, high freight, berth tied up.",
	"es": "Escala larga, flete alto, muelle ocupado.",
	"fr": "Longue escale, fret élevé, quai occupé.",
	"de": "Langer Anlauf, hohe Fracht, Kai belegt.",
	"it": "Scalo lungo, nolo alto, banchina occupata.",
	"ru": "Долгий заход, высокий фрахт, причал занят надолго.",
	"pl": "Długi postój, wysoki fracht, zajęte nabrzeże.",
	"tr": "Uzun uğrak, yüksek navlun, dolu rıhtım."},

"route.cabo.name": {
	"pt_BR": "Rota do Cabo", "en": "Cape Route", "es": "Ruta del Cabo",
	"fr": "Route du Cap", "de": "Kap-Route", "it": "Rotta del Capo",
	"ru": "Маршрут через мыс", "pl": "Trasa przez Przylądek",
	"tr": "Ümit Burnu Rotası"},
"route.cabo.desc": {
	"pt_BR": "A mais longa que um porto deste tamanho aguenta.",
	"en": "The longest run a port this size can carry.",
	"es": "La más larga que un puerto de este tamaño aguanta.",
	"fr": "La plus longue qu'un port de cette taille puisse tenir.",
	"de": "Die längste Route, die ein Hafen dieser Größe verkraftet.",
	"it": "La più lunga che un porto di queste dimensioni possa reggere.",
	"ru": "Самый долгий маршрут, который может выдержать порт такого размера.",
	"pl": "Najdłuższa trasa, jaką może udźwignąć port tej wielkości.",
	"tr": "Bu büyüklükteki bir limanın kaldırabileceği en uzun rota."},

"route.transpacifico.name": {
	"pt_BR": "Transpacífico", "en": "Transpacific", "es": "Transpacífico",
	"fr": "Transpacifique", "de": "Transpazifik", "it": "Transpacifico",
	"ru": "Транстихоокеанский маршрут", "pl": "Trasa Transpacyficzna",
	"tr": "Transpasifik"},
"route.transpacifico.desc": {
	"pt_BR": "New Panamax e ULCV. O porto vira referência.",
	"en": "New Panamax and ULCVs. The port becomes a name.",
	"es": "New Panamax y ULCV. El puerto se vuelve referencia.",
	"fr": "New Panamax et porte-conteneurs géants. Le port devient une référence.",
	"de": "New Panamax und ULCV. Der Hafen wird zu einem Begriff.",
	"it": "New Panamax e ULCV. Il porto diventa un punto di riferimento.",
	"ru": "Нью-Панамаксы и ULCV. Порт становится именем нарицательным.",
	"pl": "New Panamax i ULCV. Port staje się punktem odniesienia.",
	"tr": "New Panamax ve ULCV. Liman artık bir referans noktası."},

# --------------------------------------------------------- standing orders

"order.route.mistura.label": {
	"pt_BR": "MISTURA", "en": "ROTATE", "es": "MEZCLA", "fr": "ROTATION",
	"de": "WECHSEL", "it": "ALTERNANZA", "ru": "ЧЕРЕДОВАНИЕ",
	"pl": "ROTACJA", "tr": "DÖNÜŞÜMLÜ"},
"order.route.mistura.blurb": {
	"pt_BR": "As rotas se revezam. Frete e cadência ficam na média de tudo que o porto tem.",
	"en": "The routes take turns. Freight and cadence both land on the average of everything you own.",
	"es": "Las rutas se turnan. Flete y cadencia quedan en el promedio de todo lo que tiene el puerto.",
	"fr": "Les routes se relaient. Fret et cadence restent dans la moyenne de tout ce que possède le port.",
	"de": "Die Routen wechseln sich ab. Fracht und Taktzeit landen im Durchschnitt von allem, was der Hafen besitzt.",
	"it": "Le rotte si alternano. Nolo e cadenza restano nella media di tutto ciò che il porto possiede.",
	"ru": "Маршруты чередуются по очереди. Фрахт и интервал усредняются по всему, чем владеет порт.",
	"pl": "Trasy zmieniają się kolejno. Fracht i odstęp trafiają na średnią wszystkiego, co ma port.",
	"tr": "Rotalar sırayla değişir. Navlun ve sıklık, limanın sahip olduğu her şeyin ortalamasında kalır."},
"order.route.frete.label": {
	"pt_BR": "MAIOR FRETE", "en": "BEST FREIGHT", "es": "MAYOR FLETE",
	"fr": "MEILLEUR FRET", "de": "BESTE FRACHT", "it": "MIGLIOR NOLO",
	"ru": "ЛУЧШИЙ ФРАХТ", "pl": "NAJLEPSZY FRACHT", "tr": "EN İYİ NAVLUN"},
"order.route.frete.blurb": {
	"pt_BR": "Sempre a rota que paga mais. Cascos maiores, menos escalas, berço parado por mais tempo.",
	"en": "Always the best-paying route. Bigger hulls, fewer calls, and the berth stands empty longer.",
	"es": "Siempre la ruta que más paga. Cascos mayores, menos escalas, muelle parado más tiempo.",
	"fr": "Toujours la route la mieux payée. Coques plus grandes, moins d'escales, le quai reste vide plus longtemps.",
	"de": "Immer die bestbezahlte Route. Größere Schiffe, weniger Anläufe, der Kai bleibt länger leer.",
	"it": "Sempre la rotta che paga di più. Scafi più grandi, meno scali, la banchina resta vuota più a lungo.",
	"ru": "Всегда самый прибыльный маршрут. Крупнее суда, реже заходы, причал дольше простаивает пустым.",
	"pl": "Zawsze najlepiej płacąca trasa. Większe kadłuby, mniej zawinięć, nabrzeże dłużej stoi puste.",
	"tr": "Her zaman en iyi ödeyen rota. Daha büyük gemiler, daha az uğrak, rıhtım daha uzun süre boş kalır."},
"order.route.cadencia.label": {
	"pt_BR": "MAIS ESCALAS", "en": "MORE CALLS", "es": "MÁS ESCALAS",
	"fr": "PLUS D'ESCALES", "de": "MEHR ANLÄUFE", "it": "PIÙ SCALI",
	"ru": "ЧАЩЕ ЗАХОДЫ", "pl": "WIĘCEJ ZAWINIĘĆ", "tr": "DAHA SIK UĞRAK"},
"order.route.cadencia.blurb": {
	"pt_BR": "Sempre a rota que volta antes. Cascos pequenos, trabalho constante, bônus de partida mais vezes.",
	"en": "Always the route that books again soonest. Small hulls, constant work, the departure bonus more often.",
	"es": "Siempre la ruta que vuelve antes. Cascos pequeños, trabajo constante, bono de salida más veces.",
	"fr": "Toujours la route qui revient le plus vite. Petites coques, travail constant, la prime de départ plus souvent.",
	"de": "Immer die Route, die am schnellsten wieder anlegt. Kleine Schiffe, ständige Arbeit, der Abfahrtsbonus öfter.",
	"it": "Sempre la rotta che torna prima. Scafi piccoli, lavoro costante, il bonus di partenza più spesso.",
	"ru": "Всегда маршрут с самым быстрым возвратом. Мелкие суда, постоянная работа, бонус за отправление чаще.",
	"pl": "Zawsze trasa, która wraca najszybciej. Małe kadłuby, stała praca, bonus za odjazd częściej.",
	"tr": "Her zaman en çabuk dönen rota. Küçük gemiler, sürekli iş, kalkış bonusu daha sık."},


# --------------------------------------------------------- flags of registry
# The fleet's flags (`FleetDB.FLAGS`), named for the album card.

"country.br": {
	"pt_BR": "Brasil", "en": "Brazil", "es": "Brasil", "fr": "Brésil",
	"de": "Brasilien", "it": "Brasile", "ru": "Бразилия", "pl": "Brazylia",
	"tr": "Brezilya"},
"country.us": {
	"pt_BR": "EUA", "en": "USA", "es": "EE. UU.", "fr": "États-Unis", "de": "USA",
	"it": "USA", "ru": "США", "pl": "USA", "tr": "ABD"},
"country.cn": {
	"pt_BR": "China", "en": "China", "es": "China", "fr": "Chine", "de": "China",
	"it": "Cina", "ru": "Китай", "pl": "Chiny", "tr": "Çin"},
"country.nl": {
	"pt_BR": "Países Baixos", "en": "Netherlands", "es": "Países Bajos",
	"fr": "Pays-Bas", "de": "Niederlande", "it": "Paesi Bassi", "ru": "Нидерланды",
	"pl": "Holandia", "tr": "Hollanda"},
"country.sg": {
	"pt_BR": "Singapura", "en": "Singapore", "es": "Singapur", "fr": "Singapour",
	"de": "Singapur", "it": "Singapore", "ru": "Сингапур", "pl": "Singapur",
	"tr": "Singapur"},
"country.ae": {
	"pt_BR": "Emirados Árabes", "en": "UAE", "es": "Emiratos Árabes",
	"fr": "Émirats arabes unis", "de": "VAE", "it": "Emirati Arabi", "ru": "ОАЭ",
	"pl": "ZEA", "tr": "BAE"},
"country.pa": {
	"pt_BR": "Panamá", "en": "Panama", "es": "Panamá", "fr": "Panama", "de": "Panama",
	"it": "Panama", "ru": "Панама", "pl": "Panama", "tr": "Panama"},
"country.lr": {
	"pt_BR": "Libéria", "en": "Liberia", "es": "Liberia", "fr": "Liberia",
	"de": "Liberia", "it": "Liberia", "ru": "Либерия", "pl": "Liberia", "tr": "Liberya"},
"country.mh": {
	"pt_BR": "Ilhas Marshall", "en": "Marshall Islands", "es": "Islas Marshall",
	"fr": "Îles Marshall", "de": "Marshallinseln", "it": "Isole Marshall",
	"ru": "Маршалловы Острова", "pl": "Wyspy Marshalla", "tr": "Marshall Adaları"},
"country.mt": {
	"pt_BR": "Malta", "en": "Malta", "es": "Malta", "fr": "Malte", "de": "Malta",
	"it": "Malta", "ru": "Мальта", "pl": "Malta", "tr": "Malta"},
"country.gr": {
	"pt_BR": "Grécia", "en": "Greece", "es": "Grecia", "fr": "Grèce",
	"de": "Griechenland", "it": "Grecia", "ru": "Греция", "pl": "Grecja",
	"tr": "Yunanistan"},
"country.dk": {
	"pt_BR": "Dinamarca", "en": "Denmark", "es": "Dinamarca", "fr": "Danemark",
	"de": "Dänemark", "it": "Danimarca", "ru": "Дания", "pl": "Dania",
	"tr": "Danimarka"},
"country.de": {
	"pt_BR": "Alemanha", "en": "Germany", "es": "Alemania", "fr": "Allemagne",
	"de": "Deutschland", "it": "Germania", "ru": "Германия", "pl": "Niemcy",
	"tr": "Almanya"},
"country.fr": {
	"pt_BR": "França", "en": "France", "es": "Francia", "fr": "France",
	"de": "Frankreich", "it": "Francia", "ru": "Франция", "pl": "Francja",
	"tr": "Fransa"},
"country.it": {
	"pt_BR": "Itália", "en": "Italy", "es": "Italia", "fr": "Italie", "de": "Italien",
	"it": "Italia", "ru": "Италия", "pl": "Włochy", "tr": "İtalya"},
"country.es": {
	"pt_BR": "Espanha", "en": "Spain", "es": "España", "fr": "Espagne",
	"de": "Spanien", "it": "Spagna", "ru": "Испания", "pl": "Hiszpania",
	"tr": "İspanya"},
"country.gb": {
	"pt_BR": "Reino Unido", "en": "United Kingdom", "es": "Reino Unido",
	"fr": "Royaume-Uni", "de": "Vereinigtes Königreich", "it": "Regno Unito",
	"ru": "Великобритания", "pl": "Wielka Brytania", "tr": "Birleşik Krallık"},
"country.jp": {
	"pt_BR": "Japão", "en": "Japan", "es": "Japón", "fr": "Japon", "de": "Japan",
	"it": "Giappone", "ru": "Япония", "pl": "Japonia", "tr": "Japonya"},
"country.kr": {
	"pt_BR": "Coreia do Sul", "en": "South Korea", "es": "Corea del Sur",
	"fr": "Corée du Sud", "de": "Südkorea", "it": "Corea del Sud",
	"ru": "Южная Корея", "pl": "Korea Płd.", "tr": "Güney Kore"},
"country.no": {
	"pt_BR": "Noruega", "en": "Norway", "es": "Noruega", "fr": "Norvège",
	"de": "Norwegen", "it": "Norvegia", "ru": "Норвегия", "pl": "Norwegia",
	"tr": "Norveç"},
"country.pt": {
	"pt_BR": "Portugal", "en": "Portugal", "es": "Portugal", "fr": "Portugal",
	"de": "Portugal", "it": "Portogallo", "ru": "Португалия", "pl": "Portugalia",
	"tr": "Portekiz"},
"country.in": {
	"pt_BR": "Índia", "en": "India", "es": "India", "fr": "Inde", "de": "Indien",
	"it": "India", "ru": "Индия", "pl": "Indie", "tr": "Hindistan"},
"country.ar": {
	"pt_BR": "Argentina", "en": "Argentina", "es": "Argentina", "fr": "Argentine",
	"de": "Argentinien", "it": "Argentina", "ru": "Аргентина", "pl": "Argentyna",
	"tr": "Arjantin"},
"country.mx": {
	"pt_BR": "México", "en": "Mexico", "es": "México", "fr": "Mexique",
	"de": "Mexiko", "it": "Messico", "ru": "Мексика", "pl": "Meksyk", "tr": "Meksika"},
"country.ru": {
	"pt_BR": "Rússia", "en": "Russia", "es": "Rusia", "fr": "Russie",
	"de": "Russland", "it": "Russia", "ru": "Россия", "pl": "Rosja", "tr": "Rusya"},
"country.pl": {
	"pt_BR": "Polônia", "en": "Poland", "es": "Polonia", "fr": "Pologne",
	"de": "Polen", "it": "Polonia", "ru": "Польша", "pl": "Polska", "tr": "Polonya"},
"country.tr": {
	"pt_BR": "Turquia", "en": "Türkiye", "es": "Turquía", "fr": "Turquie",
	"de": "Türkei", "it": "Turchia", "ru": "Турция", "pl": "Turcja", "tr": "Türkiye"},
"country.cl": {
	"pt_BR": "Chile", "en": "Chile", "es": "Chile", "fr": "Chili", "de": "Chile",
	"it": "Cile", "ru": "Чили", "pl": "Chile", "tr": "Şili"},
"country.ca": {
	"pt_BR": "Canadá", "en": "Canada", "es": "Canadá", "fr": "Canada", "de": "Kanada",
	"it": "Canada", "ru": "Канада", "pl": "Kanada", "tr": "Kanada"},
"country.se": {
	"pt_BR": "Suécia", "en": "Sweden", "es": "Suecia", "fr": "Suède",
	"de": "Schweden", "it": "Svezia", "ru": "Швеция", "pl": "Szwecja", "tr": "İsveç"},

}
