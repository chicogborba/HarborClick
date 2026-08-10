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

}
