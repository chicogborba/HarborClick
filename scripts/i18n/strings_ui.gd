class_name LocStringsUi
## Every string the interface says, in every language the game speaks.
##
## One row per key, one column per language, so a missing translation is visible
## by looking at the row rather than by diffing two files that drifted apart.
## `tests/i18n_test_runner.gd` fails the build if any row is short a language.
##
## `{name}` slots are filled by `Loc.t(key, {"name": ...})`. They are named, not
## positional, because word order is exactly the thing that changes between
## languages — "12 minutes long" and "dura 12 minutos" do not put the number in
## the same place.
##
## The voice is the game's: dry, concrete, a bit of a joke where a joke fits.
## Translations match that register rather than flattening it into manual prose.
##
## Nine languages as of 2026-08: pt_BR, en, es, fr, de, it, ru, pl, tr. All fit
## the bitmap font's Latin+Cyrillic glyph set — see `tools/sprites/gen_font.py`.
## `Loc.tn()` only knows a "one"/"other" plural split; Russian and Polish both
## have a third form (the 2-4 count) that this collapses into "other". That is
## a known, accepted gap, not an oversight — see the README roadmap.

const STRINGS := {

# ------------------------------------------------------------------ generic

"common.on": {
	"pt_BR": "LIGADO", "en": "ON", "es": "ACTIVO", "fr": "ACTIVÉ", "de": "AN",
	"it": "ATTIVO", "ru": "ВКЛ", "pl": "WŁĄCZ.", "tr": "AÇIK"},
"common.off": {
	"pt_BR": "DESLIGADO", "en": "OFF", "es": "INACTIVO", "fr": "DÉSACTIVÉ",
	"de": "AUS", "it": "DISATTIVO", "ru": "ВЫКЛ", "pl": "WYŁĄCZ.",
	"tr": "KAPALI"},
"common.close": {
	"pt_BR": "FECHAR", "en": "CLOSE", "es": "CERRAR", "fr": "FERMER",
	"de": "SCHLIESSEN", "it": "CHIUDI", "ru": "ЗАКРЫТЬ", "pl": "ZAMKNIJ",
	"tr": "KAPAT"},
"common.close_hint": {
	"pt_BR": "Fechar (Esc)", "en": "Close (Esc)", "es": "Cerrar (Esc)",
	"fr": "Fermer (Échap)", "de": "Schließen (Esc)", "it": "Chiudi (Esc)",
	"ru": "Закрыть (Esc)", "pl": "Zamknij (Esc)", "tr": "Kapat (Esc)"},
"common.back": {
	"pt_BR": "VOLTAR", "en": "BACK", "es": "VOLVER", "fr": "RETOUR",
	"de": "ZURÜCK", "it": "INDIETRO", "ru": "НАЗАД", "pl": "WSTECZ",
	"tr": "GERİ"},
"common.yes": {
	"pt_BR": "SIM", "en": "YES", "es": "SÍ", "fr": "OUI", "de": "JA",
	"it": "SÌ", "ru": "ДА", "pl": "TAK", "tr": "EVET"},
"common.no": {
	"pt_BR": "NÃO", "en": "NO", "es": "NO", "fr": "NON", "de": "NEIN",
	"it": "NO", "ru": "НЕТ", "pl": "NIE", "tr": "HAYIR"},
"common.teus": {
	# A genuine shipping-industry acronym (Twenty-foot Equivalent Unit), not an
	# English word — it stays TEU in every language rather than being invented
	# a local translation nobody in a real port would use.
	"pt_BR": "TEUs", "en": "TEUs", "es": "TEUs", "fr": "TEU", "de": "TEU",
	"it": "TEU", "ru": "TEU", "pl": "TEU", "tr": "TEU"},

# ----------------------------------------------------------------- settings

"settings.title": {
	"pt_BR": "AJUSTES", "en": "SETTINGS", "es": "AJUSTES", "fr": "RÉGLAGES",
	"de": "EINSTELLUNGEN", "it": "IMPOSTAZIONI", "ru": "НАСТРОЙКИ",
	"pl": "USTAWIENIA", "tr": "AYARLAR"},
"settings.close_name": {
	"pt_BR": "Fechar os ajustes", "en": "Close settings",
	"es": "Cerrar los ajustes", "fr": "Fermer les réglages",
	"de": "Einstellungen schließen", "it": "Chiudi le impostazioni",
	"ru": "Закрыть настройки", "pl": "Zamknij ustawienia",
	"tr": "Ayarları kapat"},

"settings.section.sound": {
	"pt_BR": "SOM", "en": "SOUND", "es": "SONIDO", "fr": "SON", "de": "TON",
	"it": "AUDIO", "ru": "ЗВУК", "pl": "DŹWIĘK", "tr": "SES"},
"settings.section.language": {
	"pt_BR": "IDIOMA", "en": "LANGUAGE", "es": "IDIOMA", "fr": "LANGUE",
	"de": "SPRACHE", "it": "LINGUA", "ru": "ЯЗЫК", "pl": "JĘZYK",
	"tr": "DİL"},
"settings.section.display": {
	"pt_BR": "APRESENTAÇÃO", "en": "DISPLAY", "es": "PRESENTACIÓN",
	"fr": "AFFICHAGE", "de": "ANZEIGE", "it": "PRESENTAZIONE",
	"ru": "ОТОБРАЖЕНИЕ", "pl": "WYŚWIETLANIE", "tr": "GÖRÜNÜM"},
"settings.section.port": {
	"pt_BR": "PORTO", "en": "PORT", "es": "PUERTO", "fr": "PORT",
	"de": "HAFEN", "it": "PORTO", "ru": "ПОРТ", "pl": "PORT",
	"tr": "LİMAN"},
"settings.section.save": {
	"pt_BR": "PROGRESSO", "en": "SAVE DATA", "es": "PROGRESO",
	"fr": "SAUVEGARDE", "de": "SPEICHERSTAND", "it": "SALVATAGGIO",
	"ru": "СОХРАНЕНИЕ", "pl": "ZAPIS", "tr": "KAYIT"},
"settings.section.danger": {
	"pt_BR": "ZONA DE RISCO", "en": "DANGER ZONE", "es": "ZONA DE RIESGO",
	"fr": "ZONE DANGEREUSE", "de": "GEFAHRENZONE", "it": "ZONA PERICOLOSA",
	"ru": "ОПАСНАЯ ЗОНА", "pl": "STREFA RYZYKA", "tr": "TEHLİKELİ BÖLGE"},

"settings.music": {
	"pt_BR": "Música", "en": "Music", "es": "Música", "fr": "Musique",
	"de": "Musik", "it": "Musica", "ru": "Музыка", "pl": "Muzyka",
	"tr": "Müzik"},
"settings.sfx": {
	"pt_BR": "Efeitos", "en": "Sound effects", "es": "Efectos",
	"fr": "Effets sonores", "de": "Soundeffekte", "it": "Effetti sonori",
	"ru": "Звуковые эффекты", "pl": "Efekty dźwiękowe",
	"tr": "Ses efektleri"},
"settings.volume_name": {
	"pt_BR": "Volume: {label}", "en": "{label} volume",
	"es": "Volumen: {label}", "fr": "Volume : {label}",
	"de": "{label}-Lautstärke", "it": "Volume: {label}",
	"ru": "Громкость: {label}", "pl": "Głośność: {label}",
	"tr": "{label} sesi"},
"settings.volume_hint": {
	"pt_BR": "Arraste ou use as setas para mudar o volume.",
	"en": "Drag, or use the arrow keys, to change the volume.",
	"es": "Arrastre o use las flechas para cambiar el volumen.",
	"fr": "Glissez, ou utilisez les flèches, pour régler le volume.",
	"de": "Ziehen Sie, oder nutzen Sie die Pfeiltasten, um die Lautstärke zu ändern.",
	"it": "Trascina, o usa le frecce, per cambiare il volume.",
	"ru": "Перетащите ползунок или используйте стрелки, чтобы изменить громкость.",
	"pl": "Przeciągnij lub użyj strzałek, aby zmienić głośność.",
	"tr": "Ses düzeyini değiştirmek için sürükleyin veya ok tuşlarını kullanın."},
"settings.mute_name": {
	"pt_BR": "Silenciar {label}", "en": "Mute {label}",
	"es": "Silenciar {label}", "fr": "Couper {label}",
	"de": "{label} stummschalten", "it": "Disattiva {label}",
	"ru": "Выключить {label}", "pl": "Wycisz {label}",
	"tr": "{label} sesini kapat"},
"settings.unmute_name": {
	"pt_BR": "Reativar {label}", "en": "Unmute {label}",
	"es": "Reactivar {label}", "fr": "Réactiver {label}",
	"de": "{label} wieder einschalten", "it": "Riattiva {label}",
	"ru": "Включить {label}", "pl": "Włącz {label}",
	"tr": "{label} sesini aç"},
"settings.muted": {
	"pt_BR": "MUDO", "en": "MUTED", "es": "MUDO", "fr": "MUET",
	"de": "STUMM", "it": "MUTO", "ru": "БЕЗ ЗВУКА", "pl": "WYCISZ.",
	"tr": "SESSİZ"},

"settings.language.auto": {
	"pt_BR": "Automático", "en": "Automatic", "es": "Automático",
	"fr": "Automatique", "de": "Automatisch", "it": "Automatico",
	"ru": "Автоматически", "pl": "Automatycznie", "tr": "Otomatik"},
"settings.language.auto_tag": {
	# Exactly two characters in every language, matching every real language
	# tag beside it (PT/EN/ES/...) — the segmented row reads as one consistent
	# strip of codes rather than one wide tile among many narrow ones. At ten
	# segments across a 320px board there is no width left to spare: a longer
	# tag here does not wrap, it clips ("AUTO" silently became "AU").
	"pt_BR": "AU", "en": "AU", "es": "AU", "fr": "AU", "de": "AU",
	"it": "AU", "ru": "АВ", "pl": "AU", "tr": "OT"},
"settings.language.auto_hint": {
	"pt_BR": "Segue o idioma do aparelho.",
	"en": "Follows the device language.",
	"es": "Sigue el idioma del dispositivo.",
	"fr": "Suit la langue de l'appareil.",
	"de": "Folgt der Gerätesprache.",
	"it": "Segue la lingua del dispositivo.",
	"ru": "Следует языку устройства.",
	"pl": "Podąża za językiem urządzenia.",
	"tr": "Cihazın dilini takip eder."},
"settings.language.name": {
	"pt_BR": "Idioma: {label}", "en": "Language: {label}",
	"es": "Idioma: {label}", "fr": "Langue : {label}",
	"de": "Sprache: {label}", "it": "Lingua: {label}",
	"ru": "Язык: {label}", "pl": "Język: {label}", "tr": "Dil: {label}"},
"settings.language.current": {
	"pt_BR": "Mostrando em {label}.", "en": "Showing in {label}.",
	"es": "Mostrando en {label}.", "fr": "Affiché en {label}.",
	"de": "Angezeigt auf {label}.", "it": "Mostrato in {label}.",
	"ru": "Показано на языке: {label}.", "pl": "Wyświetlane w: {label}.",
	"tr": "{label} olarak gösteriliyor."},

"settings.motion": {
	"pt_BR": "Movimento", "en": "Motion", "es": "Movimiento",
	"fr": "Mouvement", "de": "Bewegung", "it": "Movimento", "ru": "Движение",
	"pl": "Ruch", "tr": "Hareket"},
"settings.motion.normal": {
	"pt_BR": "NORMAL", "en": "NORMAL", "es": "NORMAL", "fr": "NORMAL",
	"de": "NORMAL", "it": "NORMALE", "ru": "ОБЫЧНО", "pl": "NORMALNY",
	"tr": "NORMAL"},
"settings.motion.reduced": {
	"pt_BR": "REDUZIDO", "en": "REDUCED", "es": "REDUCIDO", "fr": "RÉDUIT",
	"de": "REDUZIERT", "it": "RIDOTTO", "ru": "СНИЖЕНО", "pl": "OGRANICZ.",
	"tr": "AZALTILMIŞ"},
"settings.motion.hint": {
	"pt_BR": "Reduzido corta animações e tremores da tela.",
	"en": "Reduced cuts animations and screen shake.",
	"es": "Reducido quita animaciones y sacudidas de pantalla.",
	"fr": "Réduit coupe les animations et les tremblements d'écran.",
	"de": "Reduziert schaltet Animationen und Bildschirmwackeln ab.",
	"it": "Ridotto elimina animazioni e tremolii dello schermo.",
	"ru": "Режим «снижено» убирает анимации и тряску экрана.",
	"pl": "Tryb ograniczony wyłącza animacje i drgania ekranu.",
	"tr": "Azaltılmış mod animasyonları ve ekran sarsıntısını kaldırır."},
"settings.numbers": {
	"pt_BR": "Números flutuantes", "en": "Floating numbers",
	"es": "Números flotantes", "fr": "Nombres flottants",
	"de": "Schwebende Zahlen", "it": "Numeri fluttuanti",
	"ru": "Всплывающие числа", "pl": "Unoszące się liczby",
	"tr": "Yüzen sayılar"},
"settings.numbers.hint": {
	"pt_BR": "O ganho de cada toque sobe pela tela.",
	"en": "Each tap's earnings float up the screen.",
	"es": "La ganancia de cada toque sube por la pantalla.",
	"fr": "Le gain de chaque tape flotte vers le haut de l'écran.",
	"de": "Der Gewinn jedes Tipps schwebt über den Bildschirm.",
	"it": "Il guadagno di ogni tocco sale sullo schermo.",
	"ru": "Доход от каждого нажатия всплывает на экране.",
	"pl": "Zysk z każdego dotknięcia unosi się na ekranie.",
	"tr": "Her dokunuşun kazancı ekranda yukarı doğru yüzer."},
"settings.ui_scale": {
	"pt_BR": "Escala da interface", "en": "Interface scale",
	"es": "Escala de la interfaz", "fr": "Échelle de l'interface",
	"de": "Oberflächengröße", "it": "Scala dell'interfaccia",
	"ru": "Масштаб интерфейса", "pl": "Skala interfejsu",
	"tr": "Arayüz ölçeği"},
"settings.ui_scale.hint": {
	"pt_BR": "Aumenta o tamanho de todo o texto e de todos os botões.",
	"en": "Makes every label and every button bigger.",
	"es": "Aumenta el tamaño de todo el texto y de todos los botones.",
	"fr": "Agrandit tous les textes et tous les boutons.",
	"de": "Vergrößert jeden Text und jeden Knopf.",
	"it": "Ingrandisce ogni testo e ogni pulsante.",
	"ru": "Увеличивает весь текст и все кнопки.",
	"pl": "Powiększa cały tekst i wszystkie przyciski.",
	"tr": "Her metni ve her düğmeyi büyütür."},
"settings.fullscreen": {
	"pt_BR": "Tela cheia", "en": "Fullscreen", "es": "Pantalla completa",
	"fr": "Plein écran", "de": "Vollbild", "it": "Schermo intero",
	"ru": "Полный экран", "pl": "Pełny ekran", "tr": "Tam ekran"},

"settings.tutorial": {
	"pt_BR": "REVER TUTORIAL", "en": "REPLAY TUTORIAL",
	"es": "REPETIR TUTORIAL", "fr": "REVOIR LE TUTORIEL",
	"de": "TUTORIAL WIEDERHOLEN", "it": "RIVEDI IL TUTORIAL",
	"ru": "ПОВТОРИТЬ ОБУЧЕНИЕ", "pl": "POWTÓRZ SAMOUCZEK",
	"tr": "EĞİTİMİ TEKRARLA"},
"settings.tutorial.hint": {
	"pt_BR": "Mostra de novo as dicas do começo.",
	"en": "Runs the opening walkthrough again.",
	"es": "Muestra de nuevo las indicaciones del inicio.",
	"fr": "Relance les indications du début.",
	"de": "Zeigt die Einführung erneut.",
	"it": "Rimostra le indicazioni iniziali.",
	"ru": "Снова показывает вступительные подсказки.",
	"pl": "Pokazuje ponownie wskazówki z początku.",
	"tr": "Başlangıç ipuçlarını tekrar gösterir."},
"settings.day_note": {
	"pt_BR": "Um dia no porto dura {minutes} minutos. Dias de neblina rendem menos.",
	"en": "A day at the port lasts {minutes} minutes. Foggy days pay less.",
	"es": "Un día en el puerto dura {minutes} minutos. Los días de niebla rinden menos.",
	"fr": "Une journée au port dure {minutes} minutes. Les jours de brouillard rapportent moins.",
	"de": "Ein Tag im Hafen dauert {minutes} Minuten. Nebeltage bringen weniger ein.",
	"it": "Un giorno in porto dura {minutes} minuti. I giorni di nebbia rendono meno.",
	"ru": "Один день в порту длится {minutes} минут. В туманные дни доход меньше.",
	"pl": "Jeden dzień w porcie trwa {minutes} minut. Mglisty dzień daje mniejszy zysk.",
	"tr": "Limanda bir gün {minutes} dakika sürer. Sisli günler daha az kazandırır."},
"settings.offline_note": {
	"pt_BR": "Fora do jogo o porto rende {percent}% da produção, por até {duration}.",
	"en": "While you are away the port earns {percent}% of its output, for up to {duration}.",
	"es": "Fuera del juego el puerto rinde {percent}% de la producción, hasta {duration}.",
	"fr": "Hors jeu, le port rapporte {percent}% de sa production, pendant {duration} maximum.",
	"de": "Außerhalb des Spiels verdient der Hafen {percent}% seiner Leistung, für bis zu {duration}.",
	"it": "Fuori dal gioco il porto rende il {percent}% della produzione, per un massimo di {duration}.",
	"ru": "Пока вы не в игре, порт зарабатывает {percent}% от обычного дохода, максимум {duration}.",
	"pl": "Poza grą port zarabia {percent}% swojej produkcji, maksymalnie przez {duration}.",
	"tr": "Oyun kapalıyken liman üretiminin %{percent} kadarını kazanır, en fazla {duration} boyunca."},

"settings.export": {
	"pt_BR": "EXPORTAR", "en": "EXPORT", "es": "EXPORTAR", "fr": "EXPORTER",
	"de": "EXPORTIEREN", "it": "ESPORTA", "ru": "ЭКСПОРТ",
	"pl": "EKSPORTUJ", "tr": "DIŞA AKTAR"},
"settings.export.name": {
	"pt_BR": "Exportar o save", "en": "Export your save",
	"es": "Exportar la partida", "fr": "Exporter la sauvegarde",
	"de": "Speicherstand exportieren", "it": "Esporta il salvataggio",
	"ru": "Экспортировать сохранение", "pl": "Eksportuj zapis",
	"tr": "Kaydı dışa aktar"},
"settings.export.hint": {
	"pt_BR": "Copia o save para a área de transferência e grava uma cópia em disco.",
	"en": "Copies your save to the clipboard and writes a copy to disk.",
	"es": "Copia la partida al portapapeles y guarda una copia en disco.",
	"fr": "Copie la sauvegarde dans le presse-papiers et écrit une copie sur le disque.",
	"de": "Kopiert den Speicherstand in die Zwischenablage und schreibt eine Kopie auf die Festplatte.",
	"it": "Copia il salvataggio negli appunti e scrive una copia su disco.",
	"ru": "Копирует сохранение в буфер обмена и записывает копию на диск.",
	"pl": "Kopiuje zapis do schowka i zapisuje kopię na dysku.",
	"tr": "Kaydı panoya kopyalar ve diske bir kopya yazar."},
"settings.import": {
	"pt_BR": "IMPORTAR", "en": "IMPORT", "es": "IMPORTAR", "fr": "IMPORTER",
	"de": "IMPORTIEREN", "it": "IMPORTA", "ru": "ИМПОРТ",
	"pl": "IMPORTUJ", "tr": "İÇE AKTAR"},
"settings.import.name": {
	"pt_BR": "Importar um save", "en": "Import a save",
	"es": "Importar una partida", "fr": "Importer une sauvegarde",
	"de": "Speicherstand importieren", "it": "Importa un salvataggio",
	"ru": "Импортировать сохранение", "pl": "Importuj zapis",
	"tr": "Kayıt içe aktar"},
"settings.import.hint": {
	"pt_BR": "Lê o save da área de transferência e substitui o progresso atual.",
	"en": "Reads a save from the clipboard and replaces your current progress.",
	"es": "Lee una partida del portapapeles y sustituye el progreso actual.",
	"fr": "Lit la sauvegarde depuis le presse-papiers et remplace la progression actuelle.",
	"de": "Liest den Speicherstand aus der Zwischenablage und ersetzt den aktuellen Fortschritt.",
	"it": "Legge il salvataggio dagli appunti e sostituisce il progresso attuale.",
	"ru": "Считывает сохранение из буфера обмена и заменяет текущий прогресс.",
	"pl": "Odczytuje zapis ze schowka i zastępuje bieżący postęp.",
	"tr": "Kaydı panodan okur ve mevcut ilerlemenin yerine geçirir."},
"settings.export.done_file": {
	"pt_BR": "Save copiado. Cópia em {path}",
	"en": "Save copied. A copy is at {path}",
	"es": "Partida copiada. Hay una copia en {path}",
	"fr": "Sauvegarde copiée. Copie dans {path}",
	"de": "Speicherstand kopiert. Kopie unter {path}",
	"it": "Salvataggio copiato. Copia in {path}",
	"ru": "Сохранение скопировано. Копия в {path}",
	"pl": "Zapis skopiowany. Kopia w {path}",
	"tr": "Kayıt kopyalandı. Kopya: {path}"},
"settings.export.done_clipboard": {
	"pt_BR": "Save copiado para a área de transferência.",
	"en": "Save copied to the clipboard.",
	"es": "Partida copiada al portapapeles.",
	"fr": "Sauvegarde copiée dans le presse-papiers.",
	"de": "Speicherstand in die Zwischenablage kopiert.",
	"it": "Salvataggio copiato negli appunti.",
	"ru": "Сохранение скопировано в буфер обмена.",
	"pl": "Zapis skopiowany do schowka.",
	"tr": "Kayıt panoya kopyalandı."},
"settings.import.confirm": {
	"pt_BR": "Isso substitui o progresso atual. Toque de novo.",
	"en": "This replaces your current progress. Tap again.",
	"es": "Esto sustituye el progreso actual. Toque de nuevo.",
	"fr": "Cela remplace votre progression actuelle. Touchez à nouveau.",
	"de": "Das ersetzt Ihren aktuellen Fortschritt. Erneut tippen.",
	"it": "Questo sostituisce il tuo progresso attuale. Tocca di nuovo.",
	"ru": "Это заменит ваш текущий прогресс. Нажмите ещё раз.",
	"pl": "To zastąpi bieżący postęp. Dotknij ponownie.",
	"tr": "Bu mevcut ilerlemenizin yerine geçer. Tekrar dokunun."},
"settings.import.done": {
	"pt_BR": "Save importado.", "en": "Save imported.",
	"es": "Partida importada.", "fr": "Sauvegarde importée.",
	"de": "Speicherstand importiert.", "it": "Salvataggio importato.",
	"ru": "Сохранение импортировано.", "pl": "Zapis zaimportowany.",
	"tr": "Kayıt içe aktarıldı."},
"settings.import.failed": {
	"pt_BR": "Falha ao importar.", "en": "Import failed.",
	"es": "Error al importar.", "fr": "Échec de l'importation.",
	"de": "Import fehlgeschlagen.", "it": "Importazione non riuscita.",
	"ru": "Не удалось импортировать.", "pl": "Import nie powiódł się.",
	"tr": "İçe aktarma başarısız oldu."},
"settings.storage_warning": {
	"pt_BR": "Este navegador não está guardando o progresso. Exporte o save antes de sair.",
	"en": "This browser is not storing your progress. Export your save before you leave.",
	"es": "Este navegador no está guardando el progreso. Exporte la partida antes de salir.",
	"fr": "Ce navigateur ne conserve pas votre progression. Exportez la sauvegarde avant de partir.",
	"de": "Dieser Browser speichert Ihren Fortschritt nicht. Exportieren Sie den Speicherstand, bevor Sie gehen.",
	"it": "Questo browser non sta salvando il tuo progresso. Esporta il salvataggio prima di uscire.",
	"ru": "Этот браузер не сохраняет ваш прогресс. Экспортируйте сохранение перед выходом.",
	"pl": "Ta przeglądarka nie zapisuje twojego postępu. Wyeksportuj zapis przed wyjściem.",
	"tr": "Bu tarayıcı ilerlemenizi kaydetmiyor. Çıkmadan önce kaydı dışa aktarın."},

"settings.wipe": {
	"pt_BR": "APAGAR PROGRESSO", "en": "ERASE PROGRESS",
	"es": "BORRAR PROGRESO", "fr": "EFFACER LA PROGRESSION",
	"de": "FORTSCHRITT LÖSCHEN", "it": "CANCELLA PROGRESSO",
	"ru": "СТЕРЕТЬ ПРОГРЕСС", "pl": "USUŃ POSTĘP", "tr": "İLERLEMEYİ SİL"},
"settings.wipe.confirm": {
	"pt_BR": "TEM CERTEZA? TOQUE DE NOVO", "en": "ARE YOU SURE? TAP AGAIN",
	"es": "¿SEGURO? TOQUE DE NUEVO", "fr": "SÛR ? TOUCHEZ À NOUVEAU",
	"de": "SICHER? ERNEUT TIPPEN", "it": "SICURO? TOCCA DI NUOVO",
	"ru": "ТОЧНО? НАЖМИТЕ ЕЩЁ РАЗ", "pl": "NA PEWNO? DOTKNIJ PONOWNIE",
	"tr": "EMİN MİSİN? TEKRAR DOKUN"},
"settings.wipe.hint": {
	"pt_BR": "Apaga tudo neste terminal. Não dá para desfazer.",
	"en": "Erases everything at this terminal. There is no undo.",
	"es": "Borra todo en esta terminal. No se puede deshacer.",
	"fr": "Efface tout sur ce terminal. Impossible à annuler.",
	"de": "Löscht alles an diesem Terminal. Es gibt kein Zurück.",
	"it": "Cancella tutto in questo terminal. Non si può annullare.",
	"ru": "Стирает всё на этом терминале. Отменить нельзя.",
	"pl": "Usuwa wszystko w tym terminalu. Nie da się cofnąć.",
	"tr": "Bu terminaldeki her şeyi siler. Geri alınamaz."},
"settings.leave": {
	"pt_BR": "SAIR PARA O MENU", "en": "BACK TO THE MENU",
	"es": "SALIR AL MENÚ", "fr": "RETOUR AU MENU", "de": "ZURÜCK ZUM MENÜ",
	"it": "TORNA AL MENU", "ru": "В МЕНЮ", "pl": "WRÓĆ DO MENU",
	"tr": "MENÜYE DÖN"},
"settings.leave.name": {
	"pt_BR": "Sair para o menu de terminais", "en": "Back to the terminal menu",
	"es": "Salir al menú de terminales",
	"fr": "Retour au menu des terminaux", "de": "Zurück zum Terminal-Menü",
	"it": "Torna al menu dei terminal", "ru": "Вернуться в меню терминалов",
	"pl": "Wróć do menu terminali", "tr": "Terminal menüsüne dön"},
"settings.leave.hint": {
	"pt_BR": "Salva o progresso antes de sair.",
	"en": "Saves your progress before leaving.",
	"es": "Guarda el progreso antes de salir.",
	"fr": "Enregistre votre progression avant de partir.",
	"de": "Speichert Ihren Fortschritt, bevor Sie gehen.",
	"it": "Salva il progresso prima di uscire.",
	"ru": "Сохраняет прогресс перед выходом.",
	"pl": "Zapisuje postęp przed wyjściem.",
	"tr": "Çıkmadan önce ilerlemenizi kaydeder."},

# ------------------------------------------------------------------- routes

"routes.title": {
	"pt_BR": "MAPA-MÚNDI DE ROTAS", "en": "WORLD ROUTE CHART",
	"es": "MAPA MUNDIAL DE RUTAS", "fr": "CARTE MONDIALE DES ROUTES",
	"de": "WELTROUTENKARTE", "it": "CARTA MONDIALE DELLE ROTTE",
	"ru": "КАРТА МИРОВЫХ МАРШРУТОВ", "pl": "MAPA ŚWIATOWYCH TRAS",
	"tr": "DÜNYA ROTA HARİTASI"},
"routes.close_name": {
	"pt_BR": "Fechar as rotas", "en": "Close the route chart",
	"es": "Cerrar las rutas", "fr": "Fermer les routes",
	"de": "Routenkarte schließen", "it": "Chiudi le rotte",
	"ru": "Закрыть маршруты", "pl": "Zamknij trasy", "tr": "Rotaları kapat"},
"routes.count.one": {
	"pt_BR": "{n} rota", "en": "{n} route", "es": "{n} ruta",
	"fr": "{n} route", "de": "{n} Route", "it": "{n} rotta",
	"ru": "{n} маршрут", "pl": "{n} trasa", "tr": "{n} rota"},
"routes.count.other": {
	"pt_BR": "{n} rotas", "en": "{n} routes", "es": "{n} rutas",
	"fr": "{n} routes", "de": "{n} Routen", "it": "{n} rotte",
	"ru": "{n} маршрутов", "pl": "{n} tras", "tr": "{n} rota"},
"routes.status": {
	"pt_BR": "{count}  •  frete ×{rate}", "en": "{count}  •  freight ×{rate}",
	"es": "{count}  •  flete ×{rate}", "fr": "{count}  •  fret ×{rate}",
	"de": "{count}  •  Fracht ×{rate}", "it": "{count}  •  nolo ×{rate}",
	"ru": "{count}  •  фрахт ×{rate}", "pl": "{count}  •  fracht ×{rate}",
	"tr": "{count}  •  navlun ×{rate}"},
"routes.freight": {
	"pt_BR": "frete ×{rate}", "en": "freight ×{rate}", "es": "flete ×{rate}",
	"fr": "fret ×{rate}", "de": "Fracht ×{rate}", "it": "nolo ×{rate}",
	"ru": "фрахт ×{rate}", "pl": "fracht ×{rate}", "tr": "navlun ×{rate}"},
"routes.owned": {
	"pt_BR": "ABERTA", "en": "OPEN", "es": "ABIERTA", "fr": "OUVERTE",
	"de": "OFFEN", "it": "APERTA", "ru": "ОТКРЫТО", "pl": "OTWARTA",
	"tr": "AÇIK"},
"routes.buy_name": {
	"pt_BR": "Abrir a rota {name}", "en": "Open the {name} route",
	"es": "Abrir la ruta {name}", "fr": "Ouvrir la route {name}",
	"de": "Route {name} öffnen", "it": "Apri la rotta {name}",
	"ru": "Открыть маршрут «{name}»", "pl": "Otwórz trasę {name}",
	"tr": "{name} rotasını aç"},
"routes.buy_hint": {
	"pt_BR": "Custa {cost} TEUs.", "en": "Costs {cost} TEUs.",
	"es": "Cuesta {cost} TEUs.", "fr": "Coûte {cost} TEU.",
	"de": "Kostet {cost} TEU.", "it": "Costa {cost} TEU.",
	"ru": "Стоит {cost} TEU.", "pl": "Kosztuje {cost} TEU.",
	"tr": "{cost} TEU tutar."},
"routes.locked": {
	"pt_BR": "Abre depois de {name}.", "en": "Opens after {name}.",
	"es": "Se abre después de {name}.", "fr": "S'ouvre après {name}.",
	"de": "Öffnet nach {name}.", "it": "Si apre dopo {name}.",
	"ru": "Откроется после «{name}».", "pl": "Otwiera się po {name}.",
	"tr": "{name} sonrasında açılır."},
"routes.missing": {
	"pt_BR": "Faltam {amount} TEUs.", "en": "{amount} TEUs to go.",
	"es": "Faltan {amount} TEUs.", "fr": "Il manque {amount} TEU.",
	"de": "Noch {amount} TEU nötig.", "it": "Mancano {amount} TEU.",
	"ru": "Не хватает {amount} TEU.", "pl": "Brakuje {amount} TEU.",
	"tr": "{amount} TEU eksik."},
"routes.bought": {
	"pt_BR": "Rota aberta: {name}. Navios novos a caminho.",
	"en": "Route open: {name}. New ships are on their way.",
	"es": "Ruta abierta: {name}. Vienen barcos nuevos.",
	"fr": "Route ouverte : {name}. De nouveaux navires arrivent.",
	"de": "Route eröffnet: {name}. Neue Schiffe sind unterwegs.",
	"it": "Rotta aperta: {name}. Nuove navi in arrivo.",
	"ru": "Маршрут открыт: «{name}». В пути новые суда.",
	"pl": "Otwarto trasę: {name}. W drodze nowe statki.",
	"tr": "Rota açıldı: {name}. Yeni gemiler yolda."},
"routes.next_up": {
	"pt_BR": "Próxima: {name}, por {cost} TEUs.",
	"en": "Next up: {name}, for {cost} TEUs.",
	"es": "Siguiente: {name}, por {cost} TEUs.",
	"fr": "Prochaine : {name}, pour {cost} TEU.",
	"de": "Als Nächstes: {name}, für {cost} TEU.",
	"it": "Prossima: {name}, per {cost} TEU.",
	"ru": "Следующий: «{name}», за {cost} TEU.",
	"pl": "Następna: {name}, za {cost} TEU.",
	"tr": "Sıradaki: {name}, {cost} TEU karşılığında."},
"routes.all_open": {
	"pt_BR": "O porto está em todas as rotas do mundo.",
	"en": "This port trades on every route in the world.",
	"es": "El puerto está en todas las rutas del mundo.",
	"fr": "Ce port commerce sur toutes les routes du monde.",
	"de": "Dieser Hafen handelt auf jeder Route der Welt.",
	"it": "Questo porto commercia su ogni rotta del mondo.",
	"ru": "Этот порт торгует на всех маршрутах мира.",
	"pl": "Ten port handluje na wszystkich trasach świata.",
	"tr": "Bu liman dünyadaki her rotada ticaret yapıyor."},
"routes.interval": {
	"pt_BR": "escala ×{value}", "en": "call gap ×{value}",
	"es": "escala ×{value}", "fr": "cadence ×{value}",
	"de": "Taktzeit ×{value}", "it": "cadenza ×{value}",
	"ru": "интервал ×{value}", "pl": "odstęp ×{value}",
	"tr": "sıklık ×{value}"},

# --------------------------------------------------------------- command rail

"rail.shop": {
	"pt_BR": "LOJA", "en": "SHOP", "es": "TIENDA", "fr": "BOUTIQUE",
	"de": "LADEN", "it": "NEGOZIO", "ru": "МАГАЗИН", "pl": "SKLEP",
	"tr": "MAĞAZA"},
"rail.shop.name": {
	"pt_BR": "Abrir a loja do terminal", "en": "Open the terminal shop",
	"es": "Abrir la tienda de la terminal",
	"fr": "Ouvrir la boutique du terminal", "de": "Terminal-Laden öffnen",
	"it": "Apri il negozio del terminal", "ru": "Открыть магазин терминала",
	"pl": "Otwórz sklep terminalu", "tr": "Terminal mağazasını aç"},
"rail.routes": {
	"pt_BR": "ROTAS", "en": "ROUTES", "es": "RUTAS", "fr": "ROUTES",
	"de": "ROUTEN", "it": "ROTTE", "ru": "МАРШРУТЫ", "pl": "TRASY",
	"tr": "ROTALAR"},
"rail.routes.name": {
	"pt_BR": "Abrir o mapa de rotas", "en": "Open the route chart",
	"es": "Abrir el mapa de rutas", "fr": "Ouvrir la carte des routes",
	"de": "Routenkarte öffnen", "it": "Apri la carta delle rotte",
	"ru": "Открыть карту маршрутов", "pl": "Otwórz mapę tras",
	"tr": "Rota haritasını aç"},
"rail.journal": {
	"pt_BR": "DIÁRIO", "en": "LOGBOOK", "es": "DIARIO", "fr": "JOURNAL",
	"de": "LOGBUCH", "it": "DIARIO", "ru": "ЖУРНАЛ", "pl": "DZIENNIK",
	"tr": "GÜNLÜK"},
"rail.journal.name": {
	"pt_BR": "Abrir o Diário do Porto", "en": "Open the Port Logbook",
	"es": "Abrir el Diario del Puerto", "fr": "Ouvrir le journal du port",
	"de": "Hafenlogbuch öffnen", "it": "Apri il diario del porto",
	"ru": "Открыть судовой журнал порта", "pl": "Otwórz dziennik portu",
	"tr": "Liman günlüğünü aç"},
"rail.settings": {
	"pt_BR": "AJUSTES", "en": "SETTINGS", "es": "AJUSTES", "fr": "RÉGLAGES",
	"de": "OPTIONEN", "it": "OPZIONI", "ru": "НАСТРОЙКИ", "pl": "USTAW.",
	"tr": "AYARLAR"},
"rail.settings.name": {
	"pt_BR": "Abrir os ajustes", "en": "Open settings",
	"es": "Abrir los ajustes", "fr": "Ouvrir les réglages",
	"de": "Einstellungen öffnen", "it": "Apri le impostazioni",
	"ru": "Открыть настройки", "pl": "Otwórz ustawienia",
	"tr": "Ayarları aç"},
"rail.next_action": {
	"pt_BR": "Próxima ação", "en": "What to do next",
	"es": "Próxima acción", "fr": "Prochaine action",
	"de": "Nächste Aktion", "it": "Prossima azione",
	"ru": "Следующее действие", "pl": "Następna czynność",
	"tr": "Sıradaki eylem"},
"rail.objective.none": {
	"pt_BR": "Toque no navio pra mover carga",
	"en": "Tap the ship to move cargo",
	"es": "Toque el barco para mover carga",
	"fr": "Touchez le navire pour déplacer la cargaison",
	"de": "Tippen Sie auf das Schiff, um Fracht zu bewegen",
	"it": "Tocca la nave per spostare il carico",
	"ru": "Коснитесь судна, чтобы переместить груз",
	"pl": "Dotknij statku, aby przenieść ładunek",
	"tr": "Yükü taşımak için gemiye dokunun"},
"rail.objective.pinned": {
	"pt_BR": "FIXADA: ", "en": "PINNED: ", "es": "FIJADA: ",
	"fr": "ÉPINGLÉ : ", "de": "ANGEHEFTET: ", "it": "FISSATO: ",
	"ru": "ЗАКРЕПЛЕНО: ", "pl": "PRZYPIĘTE: ", "tr": "SABİTLENDİ: "},
"rail.objective.fallback": {
	"pt_BR": "Meta", "en": "Goal", "es": "Meta", "fr": "Objectif",
	"de": "Ziel", "it": "Obiettivo", "ru": "Цель", "pl": "Cel",
	"tr": "Hedef"},
"rail.prestige": {
	"pt_BR": "CAPITAL +{n}", "en": "SHARES +{n}", "es": "CAPITAL +{n}",
	"fr": "CAPITAL +{n}", "de": "KAPITAL +{n}", "it": "CAPITALE +{n}",
	"ru": "КАПИТАЛ +{n}", "pl": "KAPITAŁ +{n}", "tr": "SERMAYE +{n}"},
"rail.prestige.name": {
	"pt_BR": "Reconstruir o porto e emitir ações",
	"en": "Rebuild the port and issue shares",
	"es": "Reconstruir el puerto y emitir acciones",
	"fr": "Reconstruire le port et émettre des actions",
	"de": "Hafen neu aufbauen und Anteile ausgeben",
	"it": "Ricostruire il porto ed emettere azioni",
	"ru": "Перестроить порт и выпустить акции",
	"pl": "Odbuduj port i wyemituj udziały",
	"tr": "Limanı yeniden inşa et ve hisse çıkar"},
"rail.buy": {
	"pt_BR": "COMPRAR", "en": "BUY", "es": "COMPRAR", "fr": "ACHETER",
	"de": "KAUFEN", "it": "COMPRA", "ru": "КУПИТЬ", "pl": "KUP",
	"tr": "SATIN AL"},
"rail.eta.seconds": {
	"pt_BR": "em {n}s", "en": "in {n}s", "es": "en {n}s", "fr": "dans {n}s",
	"de": "in {n}s", "it": "tra {n}s", "ru": "через {n} с",
	"pl": "za {n}s", "tr": "{n}sn sonra"},
"rail.eta.minutes": {
	"pt_BR": "em {n}min", "en": "in {n}min", "es": "en {n}min",
	"fr": "dans {n}min", "de": "in {n}min", "it": "tra {n}min",
	"ru": "через {n} мин", "pl": "za {n}min", "tr": "{n}dk sonra"},
"rail.eta.hours": {
	"pt_BR": "em {n}h", "en": "in {n}h", "es": "en {n}h", "fr": "dans {n}h",
	"de": "in {n}h", "it": "tra {n}h", "ru": "через {n} ч",
	"pl": "za {n}h", "tr": "{n}sa sonra"},

# ------------------------------------------------------------ clock and tally

"clock.day": {
	"pt_BR": "DIA {n}", "en": "DAY {n}", "es": "DÍA {n}", "fr": "JOUR {n}",
	"de": "TAG {n}", "it": "GIORNO {n}", "ru": "ДЕНЬ {n}",
	"pl": "DZIEŃ {n}", "tr": "GÜN {n}"},
"clock.name": {
	"pt_BR": "Relógio do porto", "en": "Port clock", "es": "Reloj del puerto",
	"fr": "Horloge du port", "de": "Hafenuhr", "it": "Orologio del porto",
	"ru": "Часы порта", "pl": "Zegar portu", "tr": "Liman saati"},
"clock.hint": {
	"pt_BR": "Dia, hora, tempo e vento {wind} no terminal",
	"en": "Day, time, weather and {wind} wind at the terminal",
	"es": "Día, hora, tiempo y viento {wind} en la terminal",
	"fr": "Jour, heure, météo et vent {wind} au terminal",
	"de": "Tag, Uhrzeit, Wetter und {wind} Wind im Terminal",
	"it": "Giorno, ora, meteo e vento {wind} nel terminal",
	"ru": "День, время, погода и {wind} ветер в терминале",
	"pl": "Dzień, godzina, pogoda i wiatr: {wind} w terminalu",
	"tr": "Terminaldeki gün, saat, hava durumu ve {wind} rüzgâr"},
"clock.wind.calm": {
	"pt_BR": "calmo", "en": "calm", "es": "calmo", "fr": "calme",
	"de": "ruhig", "it": "calmo", "ru": "слабый", "pl": "słaby",
	"tr": "sakin"},
"clock.wind.fresh": {
	"pt_BR": "fresco", "en": "fresh", "es": "fresco", "fr": "frais",
	"de": "frisch", "it": "fresco", "ru": "умеренный", "pl": "umiarkowany",
	"tr": "orta"},
"clock.wind.strong": {
	"pt_BR": "forte", "en": "strong", "es": "fuerte", "fr": "fort",
	"de": "stark", "it": "forte", "ru": "сильный", "pl": "silny",
	"tr": "güçlü"},

"readout.rate.name": {
	"pt_BR": "Taxa por segundo", "en": "Rate per second",
	"es": "Tasa por segundo", "fr": "Taux par seconde",
	"de": "Rate pro Sekunde", "it": "Tasso al secondo",
	"ru": "Скорость в секунду", "pl": "Tempo na sekundę",
	"tr": "Saniyedeki oran"},
"readout.rate.hint": {
	"pt_BR": "Abre de onde vem a taxa", "en": "Shows where the rate comes from",
	"es": "Muestra de dónde viene la tasa", "fr": "Ouvre d'où vient le taux",
	"de": "Zeigt, woher die Rate kommt", "it": "Apre da dove viene il tasso",
	"ru": "Показывает, откуда берётся доход",
	"pl": "Pokazuje, skąd bierze się tempo",
	"tr": "Oranın nereden geldiğini gösterir"},
"readout.total.name": {
	"pt_BR": "Contêineres movimentados", "en": "Containers handled",
	"es": "Contenedores movidos", "fr": "Conteneurs traités",
	"de": "Bearbeitete Container", "it": "Container movimentati",
	"ru": "Обработано контейнеров", "pl": "Obsłużone kontenery",
	"tr": "İşlenen konteynerler"},
"readout.total.hint": {
	"pt_BR": "Total do terminal e a taxa por segundo",
	"en": "The terminal's total, and its rate per second",
	"es": "Total de la terminal y la tasa por segundo",
	"fr": "Le total du terminal, et son taux par seconde",
	"de": "Die Gesamtzahl des Terminals und seine Rate pro Sekunde",
	"it": "Il totale del terminal, e il suo tasso al secondo",
	"ru": "Общий показатель терминала и его скорость в секунду",
	"pl": "Suma terminalu i jego tempo na sekundę",
	"tr": "Terminalin toplamı ve saniyedeki oranı"},
"readout.per_second": {
	"pt_BR": " TEU/s", "en": " TEU/s", "es": " TEU/s", "fr": " TEU/s",
	"de": " TEU/s", "it": " TEU/s", "ru": " TEU/с", "pl": " TEU/s",
	"tr": " TEU/sn"},

# --------------------------------------------------------------------- shop

"shop.title": {
	"pt_BR": "LOJA", "en": "SHOP", "es": "TIENDA", "fr": "BOUTIQUE",
	"de": "LADEN", "it": "NEGOZIO", "ru": "МАГАЗИН", "pl": "SKLEP",
	"tr": "MAĞAZA"},
"shop.close_name": {
	"pt_BR": "Fechar a loja", "en": "Close the shop",
	"es": "Cerrar la tienda", "fr": "Fermer la boutique",
	"de": "Laden schließen", "it": "Chiudi il negozio",
	"ru": "Закрыть магазин", "pl": "Zamknij sklep", "tr": "Mağazayı kapat"},
"shop.tab.structures": {
	"pt_BR": "EQUIP.", "en": "GEAR", "es": "EQUIPO", "fr": "ÉQUIP.",
	"de": "GERÄTE", "it": "ATTREZ", "ru": "ТЕХН.", "pl": "SPRZĘT",
	"tr": "ALET"},
"shop.tab.upgrades": {
	# Six characters is the hard ceiling on this strip: five tabs and a glyph
	# each inside a 320px board. "UPGRADES" lost its S to the clip and still
	# looked like a word, which is why the fit is a test rather than a habit.
	"pt_BR": "MELH.", "en": "PERKS", "es": "MEJORA", "fr": "AMÉLIO",
	"de": "AUSBAU", "it": "POTENZ", "ru": "УЛУЧШ.", "pl": "ULEPSZ",
	"tr": "YÜKS."},
"shop.tab.land": {
	"pt_BR": "TERRA", "en": "LAND", "es": "TIERRA", "fr": "TERRE",
	"de": "LAND", "it": "TERRA", "ru": "ЗЕМЛЯ", "pl": "TEREN",
	"tr": "ARAZİ"},
"shop.tab.orders": {
	"pt_BR": "ORDENS", "en": "ORDERS", "es": "ORDEN", "fr": "ORDRES",
	"de": "ORDER", "it": "ORDINI", "ru": "ПРИКАЗ", "pl": "ROZKAZ",
	"tr": "EMİR"},
"shop.tab.cosmetics": {
	"pt_BR": "DECOR.", "en": "DECOR", "es": "ADORNO", "fr": "DÉCOR",
	"de": "DEKOR", "it": "DECORO", "ru": "ДЕКОР", "pl": "DEKOR",
	"tr": "SÜS"},
"shop.bulk": {
	"pt_BR": "LOTE", "en": "BULK", "es": "LOTE", "fr": "LOT", "de": "MENGE",
	"it": "LOTTO", "ru": "ПАРТИЯ", "pl": "PARTIA", "tr": "TOPLU"},
"shop.bulk.name": {
	"pt_BR": "Comprar {mode} de uma vez", "en": "Buy {mode} at a time",
	"es": "Comprar {mode} de una vez", "fr": "Acheter {mode} à la fois",
	"de": "{mode} auf einmal kaufen", "it": "Compra {mode} alla volta",
	"ru": "Покупать по {mode} за раз", "pl": "Kupuj po {mode} naraz",
	"tr": "Bir seferde {mode} satın al"},
"shop.bulk.max": {
	"pt_BR": "MAX", "en": "MAX", "es": "MÁX", "fr": "MAX", "de": "MAX",
	"it": "MAX", "ru": "МАКС", "pl": "MAKS", "tr": "MAKS"},
"shop.empty": {
	"pt_BR": "Nada novo na prancheta.\nMovimente mais carga e volte aqui.",
	"en": "Nothing new on the clipboard.\nMove more cargo and come back.",
	"es": "Nada nuevo en la carpeta.\nMueva más carga y vuelva aquí.",
	"fr": "Rien de neuf sur la planchette.\nDéplacez plus de cargaison et revenez ici.",
	"de": "Nichts Neues auf dem Klemmbrett.\nBewegen Sie mehr Fracht und kommen Sie zurück.",
	"it": "Niente di nuovo sulla lavagna.\nMuovi più carico e torna qui.",
	"ru": "На планшете ничего нового.\nПереместите больше груза и возвращайтесь.",
	"pl": "Nic nowego na desce.\nPrzenieś więcej ładunku i wróć tutaj.",
	"tr": "Pano üzerinde yeni bir şey yok.\nDaha fazla yük taşıyın ve buraya dönün."},
"shop.teaser": {
	"pt_BR": "Movimente {amount} TEU no total para liberar.",
	"en": "Handle {amount} TEU in total to unlock.",
	"es": "Mueva {amount} TEU en total para desbloquear.",
	"fr": "Déplacez {amount} TEU au total pour débloquer.",
	"de": "Bewegen Sie insgesamt {amount} TEU, um freizuschalten.",
	"it": "Muovi {amount} TEU in totale per sbloccare.",
	"ru": "Переместите всего {amount} TEU, чтобы открыть.",
	"pl": "Przenieś łącznie {amount} TEU, aby odblokować.",
	"tr": "Kilidi açmak için toplam {amount} TEU taşıyın."},
"shop.requires": {
	"pt_BR": "Requer: {name}", "en": "Needs: {name}", "es": "Requiere: {name}",
	"fr": "Nécessite : {name}", "de": "Erfordert: {name}",
	"it": "Richiede: {name}", "ru": "Требуется: {name}",
	"pl": "Wymaga: {name}", "tr": "Gerekli: {name}"},
"shop.cost": {
	"pt_BR": "{amount} TEUs", "en": "{amount} TEUs", "es": "{amount} TEUs",
	"fr": "{amount} TEU", "de": "{amount} TEU", "it": "{amount} TEU",
	"ru": "{amount} TEU", "pl": "{amount} TEU", "tr": "{amount} TEU"},
"shop.buy_name": {
	"pt_BR": "Comprar {name}", "en": "Buy {name}", "es": "Comprar {name}",
	"fr": "Acheter {name}", "de": "{name} kaufen", "it": "Compra {name}",
	"ru": "Купить «{name}»", "pl": "Kup {name}", "tr": "{name} satın al"},

"shop.cosmetics.port": {
	"pt_BR": "O PORTO", "en": "THE PORT", "es": "EL PUERTO",
	"fr": "LE PORT", "de": "DER HAFEN", "it": "IL PORTO", "ru": "ПОРТ",
	"pl": "PORT", "tr": "LİMAN"},
"shop.cosmetics.crew": {
	"pt_BR": "A EQUIPE", "en": "THE CREW", "es": "LA TRIPULACIÓN",
	"fr": "L'ÉQUIPAGE", "de": "DIE MANNSCHAFT", "it": "L'EQUIPAGGIO",
	"ru": "КОМАНДА", "pl": "ZAŁOGA", "tr": "MÜRETTEBAT"},
"shop.cosmetics.blurb": {
	"pt_BR": "Enfeite não paga TEU. Compra uma vez e é sua para sempre - nem a reconstrução leva. Liga e desliga quando quiser.",
	"en": "Decorations earn nothing. Buy one once and it is yours for good - not even a rebuild takes it away. Switch it on and off whenever you like.",
	"es": "Los adornos no pagan TEU. Se compran una vez y son suyos para siempre - ni la reconstrucción se los lleva. Se encienden y apagan cuando quiera.",
	"fr": "Les décorations ne rapportent pas de TEU. Achetez-en une et elle est à vous pour toujours - même une reconstruction ne l'enlève pas. Allumez-la et éteignez-la à volonté.",
	"de": "Dekorationen bringen keine TEU ein. Einmal gekauft, gehören sie für immer - nicht einmal ein Neuaufbau nimmt sie weg. Schalten Sie sie ein und aus, wann immer Sie wollen.",
	"it": "Le decorazioni non guadagnano TEU. Comprane una e sarà tua per sempre - nemmeno una ricostruzione te la toglie. Accendila e spegnila quando vuoi.",
	"ru": "Украшения не приносят TEU. Купите один раз - и он ваш навсегда, даже перестройка его не заберёт. Включайте и выключайте, когда захотите.",
	"pl": "Dekoracje nie zarabiają TEU. Kup raz, a zostanie twoja na zawsze - nawet odbudowa jej nie zabierze. Włączaj i wyłączaj, kiedy chcesz.",
	"tr": "Süslemeler TEU kazandırmaz. Bir kez satın alın, sonsuza dek sizindir - yeniden inşa bile onu almaz. İstediğinizde açıp kapatabilirsiniz."},
"shop.cosmetics.on": {
	"pt_BR": "LIGADO", "en": "ON", "es": "PUESTO", "fr": "ACTIVÉ", "de": "AN",
	"it": "ATTIVO", "ru": "ВКЛ", "pl": "WŁ.", "tr": "TAKILI"},
"shop.cosmetics.off": {
	"pt_BR": "DESLIG.", "en": "OFF", "es": "QUITADO", "fr": "DÉSACT.",
	"de": "AUS", "it": "SPENTO", "ru": "ВЫКЛ", "pl": "WYŁ.",
	"tr": "KALDIRILDI"},
"shop.cosmetics.toggle_on": {
	"pt_BR": "Ligar {name}", "en": "Switch on {name}", "es": "Poner {name}",
	"fr": "Activer {name}", "de": "{name} einschalten", "it": "Attiva {name}",
	"ru": "Включить «{name}»", "pl": "Włącz {name}", "tr": "{name} tak"},
"shop.cosmetics.toggle_off": {
	"pt_BR": "Desligar {name}", "en": "Switch off {name}",
	"es": "Quitar {name}", "fr": "Désactiver {name}",
	"de": "{name} ausschalten", "it": "Disattiva {name}",
	"ru": "Выключить «{name}»", "pl": "Wyłącz {name}", "tr": "{name} kaldır"},

"shop.orders.gang": {
	"pt_BR": "A GANGUE", "en": "THE GANG", "es": "LA CUADRILLA",
	"fr": "L'ÉQUIPE", "de": "DIE TRUPPE", "it": "LA SQUADRA",
	"ru": "БРИГАДА", "pl": "BRYGADA", "tr": "EKİP"},
"shop.orders.gang.blurb": {
	"pt_BR": "A gangue é uma só. Com mais de um berço trabalhando, você decide quem leva as máquinas.",
	"en": "There is only one gang. Once more than one berth is working, you decide who gets the machines.",
	"es": "La cuadrilla es una sola. Con más de un muelle trabajando, usted decide quién se lleva las máquinas.",
	"fr": "Il n'y a qu'une seule équipe. Dès que plusieurs postes à quai travaillent, vous décidez qui reçoit les machines.",
	"de": "Es gibt nur eine Truppe. Sobald mehr als ein Liegeplatz arbeitet, entscheiden Sie, wer die Maschinen bekommt.",
	"it": "C'è una sola squadra. Quando più di un ormeggio è al lavoro, decidi tu chi riceve le macchine.",
	"ru": "Бригада одна. Когда работает больше одного причала, вы решаете, кому достанется техника.",
	"pl": "Brygada jest jedna. Gdy pracuje więcej niż jedno nabrzeże, ty decydujesz, kto dostaje maszyny.",
	"tr": "Tek bir ekip var. Birden fazla rıhtım çalışmaya başladığında, makineleri kimin alacağına siz karar verirsiniz."},
"shop.orders.lane": {
	"pt_BR": "ROTA DA PRÓXIMA ESCALA", "en": "ROUTE FOR THE NEXT CALL",
	"es": "RUTA DE LA PRÓXIMA ESCALA", "fr": "ROUTE DE LA PROCHAINE ESCALE",
	"de": "ROUTE FÜR DEN NÄCHSTEN ANLAUF",
	"it": "ROTTA DELLO SCALO SUCCESSIVO",
	"ru": "МАРШРУТ СЛЕДУЮЩЕГО ЗАХОДА", "pl": "TRASA NASTĘPNEGO ZAWINIĘCIA",
	"tr": "SONRAKİ UĞRAK İÇİN ROTA"},
"shop.orders.rail": {
	"pt_BR": "O RAMAL FERROVIÁRIO", "en": "THE BRANCH LINE",
	"es": "EL RAMAL FERROVIARIO", "fr": "LA VOIE FERRÉE",
	"de": "DIE BAHNSTRECKE", "it": "IL RAMO FERROVIARIO",
	"ru": "ЖЕЛЕЗНОДОРОЖНАЯ ВЕТКА", "pl": "BOCZNICA KOLEJOWA",
	"tr": "DEMİRYOLU HATTI"},
"shop.orders.foreman": {
	"pt_BR": "O CAPATAZ", "en": "THE FOREMAN", "es": "EL CAPATAZ",
	"fr": "LE CONTREMAÎTRE", "de": "DER VORARBEITER",
	"it": "IL CAPOSQUADRA", "ru": "ПРОРАБ", "pl": "MAJSTER",
	"tr": "USTABAŞI"},
"shop.orders.foreman.blurb": {
	"pt_BR": "Compra sozinho, uma de cada vez, e nunca encosta na reserva. Terreno é sempre seu.",
	"en": "Buys on his own, one at a time, and never touches the reserve. Land is always your call.",
	"es": "Compra solo, una a la vez, y nunca toca la reserva. El terreno siempre es cosa suya.",
	"fr": "Achète seul, un à la fois, et ne touche jamais à la réserve. Le terrain reste toujours votre décision.",
	"de": "Kauft alleine, eins nach dem anderen, und rührt nie die Reserve an. Land ist immer Ihre Entscheidung.",
	"it": "Compra da solo, uno alla volta, e non tocca mai la riserva. Il terreno resta sempre una tua decisione.",
	"ru": "Покупает сам, по одному, и никогда не трогает резерв. Земля - всегда ваше решение.",
	"pl": "Kupuje sam, po jednym, i nigdy nie rusza rezerwy. Teren to zawsze twoja decyzja.",
	"tr": "Tek başına, birer birer satın alır ve rezerve asla dokunmaz. Arazi her zaman sizin kararınızdır."},
"shop.orders.foreman.locked": {
	"pt_BR": "Ele só assume depois da primeira reconstrução. Abra capital e ele estará esperando.",
	"en": "He only starts after your first rebuild. Issue shares and he will be waiting.",
	"es": "Solo empieza tras la primera reconstrucción. Abra capital y estará esperando.",
	"fr": "Il ne prend le relais qu'après votre première reconstruction. Émettez du capital et il sera prêt.",
	"de": "Er übernimmt erst nach Ihrem ersten Neuaufbau. Geben Sie Kapital aus, und er wird bereitstehen.",
	"it": "Subentra solo dopo la tua prima ricostruzione. Emetti capitale e sarà pronto ad aspettare.",
	"ru": "Он берётся за дело только после вашей первой перестройки. Выпустите капитал - и он будет ждать.",
	"pl": "Przejmuje kontrolę dopiero po pierwszej odbudowie. Wyemituj kapitał, a będzie czekał.",
	"tr": "Yalnızca ilk yeniden inşanızdan sonra devreye girer. Sermaye çıkarın, o zaman hazır bekleyecektir."},
"shop.orders.reserve": {
	"pt_BR": "RESERVA", "en": "RESERVE", "es": "RESERVA", "fr": "RÉSERVE",
	"de": "RESERVE", "it": "RISERVA", "ru": "РЕЗЕРВ", "pl": "REZERWA",
	"tr": "REZERV"},
"shop.orders.reserve.name": {
	"pt_BR": "Reserva de {percent}", "en": "Reserve of {percent}",
	"es": "Reserva de {percent}", "fr": "Réserve de {percent}",
	"de": "Reserve von {percent}", "it": "Riserva del {percent}",
	"ru": "Резерв {percent}", "pl": "Rezerwa {percent}",
	"tr": "Rezerv: {percent}"},
"shop.orders.reserve.hint": {
	"pt_BR": "O capataz nunca gasta esta parte do caixa.",
	"en": "The foreman never spends this share of the treasury.",
	"es": "El capataz nunca gasta esta parte de la caja.",
	"fr": "Le contremaître ne dépense jamais cette part de la caisse.",
	"de": "Der Vorarbeiter gibt diesen Teil der Kasse niemals aus.",
	"it": "Il caposquadra non spende mai questa parte della cassa.",
	"ru": "Прораб никогда не тратит эту часть казны.",
	"pl": "Majster nigdy nie wydaje tej części kasy.",
	"tr": "Ustabaşı kasanın bu kısmını asla harcamaz."},

"shop.rail.none": {
	"pt_BR": "Sem ramal próprio: o interior manda um frete curto de vez em quando.",
	"en": "No branch of your own: the interior sends a short haul now and then.",
	"es": "Sin ramal propio: el interior manda un flete corto de vez en cuando.",
	"fr": "Pas de voie propre : l'arrière-pays envoie un petit fret de temps en temps.",
	"de": "Kein eigenes Gleis: Das Hinterland schickt gelegentlich eine kurze Fracht.",
	"it": "Nessun ramo proprio: l'entroterra manda un piccolo carico di tanto in tanto.",
	"ru": "Своей ветки нет: изредка вглубь материка приходит небольшой груз.",
	"pl": "Brak własnej bocznicy: zaplecze wysyła krótki transport od czasu do czasu.",
	"tr": "Kendi hattı yok: iç kesimden zaman zaman kısa bir yük gelir."},
"shop.rail.idle": {
	"pt_BR": "Linha livre. Próximo trem em {seconds}s.",
	"en": "Line clear. Next train in {seconds}s.",
	"es": "Vía libre. Próximo tren en {seconds}s.",
	"fr": "Voie libre. Prochain train dans {seconds}s.",
	"de": "Gleis frei. Nächster Zug in {seconds}s.",
	"it": "Binario libero. Prossimo treno tra {seconds}s.",
	"ru": "Путь свободен. Следующий поезд через {seconds} с.",
	"pl": "Tor wolny. Następny pociąg za {seconds}s.",
	"tr": "Hat boş. Sonraki tren {seconds}sn sonra."},
"shop.rail.working": {
	"pt_BR": "No ramal agora: {inbound} para descarregar, {outbound} para embarcar. Sai em {seconds}s.",
	"en": "On the branch now: {inbound} to unload, {outbound} to load. Leaves in {seconds}s.",
	"es": "En el ramal ahora: {inbound} para descargar, {outbound} para cargar. Sale en {seconds}s.",
	"fr": "Sur la voie maintenant : {inbound} à décharger, {outbound} à charger. Départ dans {seconds}s.",
	"de": "Gerade auf dem Gleis: {inbound} zu entladen, {outbound} zu beladen. Abfahrt in {seconds}s.",
	"it": "Sul binario ora: {inbound} da scaricare, {outbound} da caricare. Parte tra {seconds}s.",
	"ru": "Сейчас на ветке: {inbound} на разгрузку, {outbound} на погрузку. Отправление через {seconds} с.",
	"pl": "Teraz na torze: {inbound} do rozładunku, {outbound} do załadunku. Odjazd za {seconds}s.",
	"tr": "Şu an hatta: boşaltılacak {inbound}, yüklenecek {outbound}. {seconds}sn sonra kalkıyor."},
"shop.rail.arriving": {
	"pt_BR": "Trem entrando no ramal.", "en": "Train coming onto the branch.",
	"es": "Tren entrando al ramal.", "fr": "Un train entre sur la voie.",
	"de": "Ein Zug fährt auf das Gleis ein.",
	"it": "Treno in ingresso sul binario.", "ru": "Поезд заходит на ветку.",
	"pl": "Pociąg wjeżdża na bocznicę.", "tr": "Tren hatta giriyor."},
"shop.rail.runaround": {
	"pt_BR": "A locomotiva está contornando a composição.",
	"en": "The locomotive is running around the rake.",
	"es": "La locomotora está rodeando la composición.",
	"fr": "La locomotive fait le tour du convoi.",
	"de": "Die Lokomotive umfährt den Wagenzug.",
	"it": "La locomotiva sta girando intorno al convoglio.",
	"ru": "Локомотив выполняет манёвр вокруг состава.",
	"pl": "Lokomotywa okrąża skład.",
	"tr": "Lokomotif kompozisyonun etrafından dolaşıyor."},
"shop.rail.departing": {
	"pt_BR": "Trem saindo, {done} de {total} movimentos feitos.",
	"en": "Train leaving, {done} of {total} moves done.",
	"es": "Tren saliendo, {done} de {total} movimientos hechos.",
	"fr": "Train en partance, {done} sur {total} mouvements effectués.",
	"de": "Zug fährt ab, {done} von {total} Bewegungen erledigt.",
	"it": "Treno in partenza, {done} di {total} movimenti fatti.",
	"ru": "Поезд отправляется, выполнено {done} из {total} манёвров.",
	"pl": "Pociąg odjeżdża, wykonano {done} z {total} ruchów.",
	"tr": "Tren kalkıyor, {total} hareketten {done} tanesi tamamlandı."},

# ------------------------------------------------------------------- title

"title.motto": {
	"pt_BR": "CONSTRUA. EXPANDA. FATURE.", "en": "BUILD. EXPAND. CASH IN.",
	"es": "CONSTRUYA. AMPLÍE. FACTURE.",
	"fr": "CONSTRUISEZ. DÉVELOPPEZ. ENCAISSEZ.",
	"de": "BAUEN. AUSBAUEN. KASSIEREN.", "it": "COSTRUISCI. ESPANDI. INCASSA.",
	"ru": "СТРОЙ. РАСШИРЯЙ. ЗАРАБАТЫВАЙ.",
	"pl": "BUDUJ. ROZBUDOWUJ. ZARABIAJ.", "tr": "İNŞA ET. BÜYÜT. KAZAN."},
"title.play": {
	"pt_BR": "JOGAR", "en": "PLAY", "es": "JUGAR", "fr": "JOUER",
	"de": "SPIELEN", "it": "GIOCA", "ru": "ИГРАТЬ", "pl": "GRAJ",
	"tr": "OYNA"},
"title.play.name": {
	"pt_BR": "Jogar", "en": "Play", "es": "Jugar", "fr": "Jouer",
	"de": "Spielen", "it": "Gioca", "ru": "Играть", "pl": "Graj",
	"tr": "Oyna"},
"title.play.hint": {
	"pt_BR": "Escolher um dos três terminais",
	"en": "Pick one of the three terminals",
	"es": "Elegir una de las tres terminales",
	"fr": "Choisir l'un des trois terminaux",
	"de": "Eines der drei Terminals wählen",
	"it": "Scegli uno dei tre terminal",
	"ru": "Выбрать один из трёх терминалов",
	"pl": "Wybierz jeden z trzech terminali", "tr": "Üç terminalden birini seçin"},
"title.continue": {
	"pt_BR": "CONTINUAR", "en": "CONTINUE", "es": "CONTINUAR",
	"fr": "CONTINUER", "de": "FORTSETZEN", "it": "CONTINUA",
	"ru": "ПРОДОЛЖИТЬ", "pl": "KONTYNUUJ", "tr": "DEVAM ET"},
"title.continue.name": {
	"pt_BR": "Continuar", "en": "Continue", "es": "Continuar",
	"fr": "Continuer", "de": "Fortsetzen", "it": "Continua",
	"ru": "Продолжить", "pl": "Kontynuuj", "tr": "Devam et"},
"title.continue.hint": {
	"pt_BR": "Terminal {slot}, dia {day}", "en": "Terminal {slot}, day {day}",
	"es": "Terminal {slot}, día {day}", "fr": "Terminal {slot}, jour {day}",
	"de": "Terminal {slot}, Tag {day}", "it": "Terminal {slot}, giorno {day}",
	"ru": "Терминал {slot}, день {day}", "pl": "Terminal {slot}, dzień {day}",
	"tr": "Terminal {slot}, {day}. gün"},
"title.settings.name": {
	"pt_BR": "Ajustes", "en": "Settings", "es": "Ajustes", "fr": "Réglages",
	"de": "Einstellungen", "it": "Impostazioni", "ru": "Настройки",
	"pl": "Ustawienia", "tr": "Ayarlar"},
"title.settings.hint": {
	"pt_BR": "Som, idioma, movimento e tela",
	"en": "Sound, language, motion and screen",
	"es": "Sonido, idioma, movimiento y pantalla",
	"fr": "Son, langue, mouvement et écran",
	"de": "Ton, Sprache, Bewegung und Bildschirm",
	"it": "Audio, lingua, movimento e schermo",
	"ru": "Звук, язык, движение и экран",
	"pl": "Dźwięk, język, ruch i ekran", "tr": "Ses, dil, hareket ve ekran"},
"title.back": {
	"pt_BR": "VOLTAR", "en": "BACK", "es": "VOLVER", "fr": "RETOUR",
	"de": "ZURÜCK", "it": "INDIETRO", "ru": "НАЗАД", "pl": "WSTECZ",
	"tr": "GERİ"},
"title.back.hint": {
	"pt_BR": "Voltar à tela inicial", "en": "Back to the start screen",
	"es": "Volver a la pantalla inicial",
	"fr": "Retour à l'écran de démarrage",
	"de": "Zurück zum Startbildschirm", "it": "Torna alla schermata iniziale",
	"ru": "Вернуться на начальный экран",
	"pl": "Wróć do ekranu początkowego", "tr": "Başlangıç ekranına dön"},
"title.pick_terminal": {
	"pt_BR": "ESCOLHA SEU TERMINAL", "en": "PICK YOUR TERMINAL",
	"es": "ELIJA SU TERMINAL", "fr": "CHOISISSEZ VOTRE TERMINAL",
	"de": "TERMINAL WÄHLEN", "it": "SCEGLI IL TUO TERMINAL",
	"ru": "ВЫБЕРИТЕ ТЕРМИНАЛ", "pl": "WYBIERZ SWÓJ TERMINAL",
	"tr": "TERMİNALİNİZİ SEÇİN"},
"title.saved_here": {
	"pt_BR": "PROGRESSO SALVO NESTE DISPOSITIVO",
	"en": "PROGRESS IS SAVED ON THIS DEVICE",
	"es": "PROGRESO GUARDADO EN ESTE DISPOSITIVO",
	"fr": "PROGRESSION ENREGISTRÉE SUR CET APPAREIL",
	"de": "FORTSCHRITT AUF DIESEM GERÄT GESPEICHERT",
	"it": "PROGRESSO SALVATO SU QUESTO DISPOSITIVO",
	"ru": "ПРОГРЕСС СОХРАНЁН НА ЭТОМ УСТРОЙСТВЕ",
	"pl": "POSTĘP ZAPISANY NA TYM URZĄDZENIU",
	"tr": "İLERLEME BU CİHAZDA KAYITLI"},
"title.no_storage": {
	"pt_BR": "Este navegador não está guardando o progresso.",
	"en": "This browser is not storing your progress.",
	"es": "Este navegador no está guardando el progreso.",
	"fr": "Ce navigateur ne conserve pas votre progression.",
	"de": "Dieser Browser speichert Ihren Fortschritt nicht.",
	"it": "Questo browser non sta salvando il tuo progresso.",
	"ru": "Этот браузер не сохраняет ваш прогресс.",
	"pl": "Ta przeglądarka nie zapisuje twojego postępu.",
	"tr": "Bu tarayıcı ilerlemenizi kaydetmiyor."},
"title.reduce_motion": {
	"pt_BR": "REDUZIR MOVIMENTO", "en": "REDUCE MOTION",
	"es": "REDUCIR MOVIMIENTO", "fr": "RÉDUIRE LE MOUVEMENT",
	"de": "BEWEGUNG REDUZIEREN", "it": "RIDUCI MOVIMENTO",
	"ru": "СНИЗИТЬ ДВИЖЕНИЕ", "pl": "OGRANICZ RUCH", "tr": "HAREKETİ AZALT"},
"title.options_note": {
	"pt_BR": "O resto dos ajustes - save, backup e tutorial - fica dentro do terminal, porque pertence a uma operação e não ao aparelho.",
	"en": "The rest of the settings - save, backup and tutorial - live inside the terminal, because they belong to an operation rather than to the device.",
	"es": "El resto de los ajustes - partida, copia y tutorial - está dentro de la terminal, porque pertenece a una operación y no al aparato.",
	"fr": "Le reste des réglages - sauvegarde, copie et tutoriel - se trouve dans le terminal, car ils appartiennent à une exploitation, pas à l'appareil.",
	"de": "Der Rest der Einstellungen - Speicherstand, Backup und Tutorial - befindet sich im Terminal, weil sie zu einem Betrieb gehören, nicht zum Gerät.",
	"it": "Il resto delle impostazioni - salvataggio, backup e tutorial - si trova dentro il terminal, perché appartiene a un'operazione e non al dispositivo.",
	"ru": "Остальные настройки - сохранение, резервная копия и обучение - находятся внутри терминала, потому что они принадлежат порту, а не устройству.",
	"pl": "Reszta ustawień - zapis, kopia zapasowa i samouczek - znajduje się wewnątrz terminalu, bo należy do operacji, a nie do urządzenia.",
	"tr": "Ayarların geri kalanı - kayıt, yedekleme ve eğitim - terminalin içindedir, çünkü bunlar cihaza değil işletmeye aittir."},
"title.slot": {
	"pt_BR": "TERMINAL {n}", "en": "TERMINAL {n}", "es": "TERMINAL {n}",
	"fr": "TERMINAL {n}", "de": "TERMINAL {n}", "it": "TERMINAL {n}",
	"ru": "ТЕРМИНАЛ {n}", "pl": "TERMINAL {n}", "tr": "TERMİNAL {n}"},
"title.slot.summary": {
	"pt_BR": "{teus} TEU  •  DIA {day}", "en": "{teus} TEU  •  DAY {day}",
	"es": "{teus} TEU  •  DÍA {day}", "fr": "{teus} TEU  •  JOUR {day}",
	"de": "{teus} TEU  •  TAG {day}", "it": "{teus} TEU  •  GIORNO {day}",
	"ru": "{teus} TEU  •  ДЕНЬ {day}", "pl": "{teus} TEU  •  DZIEŃ {day}",
	"tr": "{teus} TEU  •  {day}. GÜN"},
"title.slot.rebuilds.one": {
	"pt_BR": "{n} reconstrução", "en": "{n} rebuild",
	"es": "{n} reconstrucción", "fr": "{n} reconstruction",
	"de": "{n} Neuaufbau", "it": "{n} ricostruzione",
	"ru": "{n} перестройка", "pl": "{n} odbudowa", "tr": "{n} yeniden inşa"},
"title.slot.rebuilds.other": {
	"pt_BR": "{n} reconstruções", "en": "{n} rebuilds",
	"es": "{n} reconstrucciones", "fr": "{n} reconstructions",
	"de": "{n} Neuaufbauten", "it": "{n} ricostruzioni",
	"ru": "{n} перестроек", "pl": "{n} odbudów", "tr": "{n} yeniden inşa"},
"title.slot.first_run": {
	"pt_BR": "primeira operação", "en": "first run", "es": "primera operación",
	"fr": "première exploitation", "de": "erster Durchlauf",
	"it": "prima operazione", "ru": "первый заход",
	"pl": "pierwsze podejście", "tr": "ilk çalıştırma"},
"title.slot.empty": {
	"pt_BR": "CAIS LIVRE", "en": "BERTH FREE", "es": "MUELLE LIBRE",
	"fr": "QUAI LIBRE", "de": "LIEGEPLATZ FREI", "it": "BANCHINA LIBERA",
	"ru": "ПРИЧАЛ СВОБОДЕН", "pl": "NABRZEŻE WOLNE", "tr": "RIHTIM BOŞ"},
"title.slot.start": {
	"pt_BR": "COMEÇAR", "en": "START", "es": "EMPEZAR", "fr": "COMMENCER",
	"de": "STARTEN", "it": "INIZIA", "ru": "НАЧАТЬ", "pl": "ROZPOCZNIJ",
	"tr": "BAŞLA"},
"title.slot.open_name": {
	"pt_BR": "Continuar o terminal {n}", "en": "Continue terminal {n}",
	"es": "Continuar la terminal {n}", "fr": "Continuer le terminal {n}",
	"de": "Terminal {n} fortsetzen", "it": "Continua il terminal {n}",
	"ru": "Продолжить терминал {n}", "pl": "Kontynuuj terminal {n}",
	"tr": "Terminal {n}'e devam et"},
"title.slot.start_name": {
	"pt_BR": "Começar o terminal {n}", "en": "Start terminal {n}",
	"es": "Empezar la terminal {n}", "fr": "Commencer le terminal {n}",
	"de": "Terminal {n} starten", "it": "Inizia il terminal {n}",
	"ru": "Начать терминал {n}", "pl": "Rozpocznij terminal {n}",
	"tr": "Terminal {n}'i başlat"},
"title.slot.erase": {
	"pt_BR": "APAGAR", "en": "ERASE", "es": "BORRAR", "fr": "EFFACER",
	"de": "LÖSCHEN", "it": "CANCELLA", "ru": "СТЕРЕТЬ", "pl": "USUŃ",
	"tr": "SİL"},
"title.slot.erase_armed": {
	"pt_BR": "APAGAR?", "en": "ERASE?", "es": "¿BORRAR?", "fr": "EFFACER ?",
	"de": "LÖSCHEN?", "it": "CANCELLA?", "ru": "СТЕРЕТЬ?", "pl": "USUNĄĆ?",
	"tr": "SİL Mİ?"},
"title.slot.erase_name": {
	"pt_BR": "Apagar o terminal {n}", "en": "Erase terminal {n}",
	"es": "Borrar la terminal {n}", "fr": "Effacer le terminal {n}",
	"de": "Terminal {n} löschen", "it": "Cancella il terminal {n}",
	"ru": "Стереть терминал {n}", "pl": "Usuń terminal {n}",
	"tr": "Terminal {n}'i sil"},
"title.slot.erase_hint": {
	"pt_BR": "Toque duas vezes. A operação não pode ser desfeita.",
	"en": "Tap twice. This cannot be undone.",
	"es": "Toque dos veces. No se puede deshacer.",
	"fr": "Touchez deux fois. Impossible à annuler.",
	"de": "Zweimal tippen. Kann nicht rückgängig gemacht werden.",
	"it": "Tocca due volte. Non si può annullare.",
	"ru": "Нажмите дважды. Отменить нельзя.",
	"pl": "Dotknij dwa razy. Nie da się cofnąć.",
	"tr": "İki kez dokunun. Geri alınamaz."},
"title.slot.erase_confirm": {
	"pt_BR": "Apagar o terminal {n} é definitivo. Toque em APAGAR? de novo.",
	"en": "Erasing terminal {n} is permanent. Tap ERASE? again.",
	"es": "Borrar la terminal {n} es definitivo. Toque ¿BORRAR? de nuevo.",
	"fr": "Effacer le terminal {n} est définitif. Touchez EFFACER ? à nouveau.",
	"de": "Das Löschen von Terminal {n} ist endgültig. Erneut auf LÖSCHEN? tippen.",
	"it": "Cancellare il terminal {n} è definitivo. Tocca di nuovo CANCELLA?.",
	"ru": "Удаление терминала {n} необратимо. Нажмите «СТЕРЕТЬ?» ещё раз.",
	"pl": "Usunięcie terminalu {n} jest ostateczne. Dotknij USUNĄĆ? ponownie.",
	"tr": "Terminal {n}'i silmek kalıcıdır. SİL Mİ? düğmesine tekrar dokunun."},
"title.slot.erased": {
	"pt_BR": "Terminal {n} apagado.", "en": "Terminal {n} erased.",
	"es": "Terminal {n} borrada.", "fr": "Terminal {n} effacé.",
	"de": "Terminal {n} gelöscht.", "it": "Terminal {n} cancellato.",
	"ru": "Терминал {n} стёрт.", "pl": "Terminal {n} usunięty.",
	"tr": "Terminal {n} silindi."},
"title.credits": {
	"pt_BR": "CRÉDITOS", "en": "CREDITS", "es": "CRÉDITOS", "fr": "CRÉDITS",
	"de": "MITWIRKENDE", "it": "CREDITI", "ru": "АВТОРЫ", "pl": "TWÓRCY",
	"tr": "EMEĞİ GEÇENLER"},
"title.credits.made_with": {
	"pt_BR": "Feito em Godot 4. Cada sprite, fonte, efeito e trilha deste jogo é gerado por código: nada foi desenhado à mão.",
	"en": "Made in Godot 4. Every sprite, font, sound and track in this game is generated by code: none of it was drawn by hand.",
	"es": "Hecho en Godot 4. Cada sprite, fuente, efecto y pista de este juego se genera por código: nada se dibujó a mano.",
	"fr": "Fait avec Godot 4. Chaque sprite, police, effet et morceau de ce jeu est généré par du code : rien n'a été dessiné à la main.",
	"de": "Erstellt mit Godot 4. Jedes Sprite, jede Schrift, jeder Effekt und jeder Titel dieses Spiels wird durch Code erzeugt: nichts davon wurde von Hand gezeichnet.",
	"it": "Realizzato in Godot 4. Ogni sprite, font, effetto e traccia di questo gioco è generato dal codice: niente è stato disegnato a mano.",
	"ru": "Сделано на Godot 4. Каждый спрайт, шрифт, эффект и трек в этой игре создан кодом: ничего не нарисовано вручную.",
	"pl": "Stworzone w Godocie 4. Każdy sprite, czcionka, efekt i utwór w tej grze jest generowany przez kod: nic nie zostało narysowane ręcznie.",
	"tr": "Godot 4 ile yapıldı. Bu oyundaki her sprite, yazı tipi, efekt ve parça kodla üretildi: hiçbiri elle çizilmedi."},
"title.credits.jargon": {
	"pt_BR": "Jargão de terminal conferido com quem trabalha em porto brasileiro.",
	"en": "Terminal jargon checked with people who work in Brazilian ports.",
	"es": "Jerga portuaria revisada con gente que trabaja en puertos brasileños.",
	"fr": "Le jargon portuaire a été vérifié auprès de gens qui travaillent dans des ports brésiliens.",
	"de": "Der Hafenjargon wurde mit Leuten geprüft, die in brasilianischen Häfen arbeiten.",
	"it": "Il gergo portuale è stato verificato con persone che lavorano nei porti brasiliani.",
	"ru": "Портовый жаргон сверен с людьми, которые работают в бразильских портах.",
	"pl": "Żargon portowy sprawdzono z ludźmi pracującymi w brazylijskich portach.",
	"tr": "Liman jargonu, Brezilya limanlarında çalışan kişilerle doğrulandı."},
"title.site": {
	"pt_BR": "SITE", "en": "SITE", "es": "SITIO", "fr": "SITE",
	"de": "WEBSITE", "it": "SITO", "ru": "САЙТ", "pl": "STRONA",
	"tr": "SİTE"},
"title.site.blurb": {
	"pt_BR": "O projeto inteiro é aberto, código e geradores de arte.",
	"en": "The whole project is open, code and art generators alike.",
	"es": "El proyecto entero es abierto, código y generadores de arte.",
	"fr": "Le projet entier est ouvert, code et générateurs d'art compris.",
	"de": "Das gesamte Projekt ist offen, Code und Art-Generatoren eingeschlossen.",
	"it": "L'intero progetto è aperto, codice e generatori d'arte compresi.",
	"ru": "Весь проект открыт - и код, и генераторы графики.",
	"pl": "Cały projekt jest otwarty, kod i generatory grafiki włącznie.",
	"tr": "Tüm proje açık kaynaklıdır, kod ve görsel üreticileri dahil."},
"title.site.link": {
	"pt_BR": "ABRIR REPOSITÓRIO", "en": "OPEN THE REPOSITORY",
	"es": "ABRIR EL REPOSITORIO", "fr": "OUVRIR LE DÉPÔT",
	"de": "REPOSITORY ÖFFNEN", "it": "APRI IL REPOSITORY",
	"ru": "ОТКРЫТЬ РЕПОЗИТОРИЙ", "pl": "OTWÓRZ REPOZYTORIUM",
	"tr": "DEPOYU AÇ"},
"title.feedback": {
	"pt_BR": "FEEDBACK", "en": "FEEDBACK", "es": "COMENTARIOS",
	"fr": "RETOURS", "de": "FEEDBACK", "it": "FEEDBACK", "ru": "ОТЗЫВЫ",
	"pl": "OPINIE", "tr": "GERİ BİLDİRİM"},
"title.feedback.blurb": {
	"pt_BR": "Achou um bug ou tem uma ideia? Abra uma issue - é o caminho que a gente lê.",
	"en": "Found a bug, or have an idea? Open an issue - that is the channel we actually read.",
	"es": "¿Encontró un fallo o tiene una idea? Abra una issue - es el canal que sí leemos.",
	"fr": "Trouvé un bug ou une idée ? Ouvrez une issue - c'est le canal qu'on lit vraiment.",
	"de": "Einen Fehler gefunden oder eine Idee? Erstellen Sie ein Issue - das ist der Kanal, den wir wirklich lesen.",
	"it": "Hai trovato un bug o hai un'idea? Apri una issue - è il canale che leggiamo davvero.",
	"ru": "Нашли баг или есть идея? Откройте issue - это единственный канал, который мы реально читаем.",
	"pl": "Znalazłeś błąd albo masz pomysł? Otwórz issue - to kanał, który naprawdę czytamy.",
	"tr": "Bir hata mı buldunuz ya da bir fikriniz mi var? Bir issue açın - gerçekten okuduğumuz kanal budur."},
"title.feedback.link": {
	"pt_BR": "ABRIR ISSUES", "en": "OPEN ISSUES", "es": "ABRIR ISSUES",
	"fr": "OUVRIR LES ISSUES", "de": "ISSUES ÖFFNEN", "it": "APRI LE ISSUE",
	"ru": "ОТКРЫТЬ ISSUES", "pl": "OTWÓRZ ISSUES", "tr": "ISSUE'LARI AÇ"},
"title.community": {
	"pt_BR": "COMUNIDADE", "en": "COMMUNITY", "es": "COMUNIDAD",
	"fr": "COMMUNAUTÉ", "de": "COMMUNITY", "it": "COMUNITÀ",
	"ru": "СООБЩЕСТВО", "pl": "SPOŁECZNOŚĆ", "tr": "TOPLULUK"},
"title.community.blurb": {
	"pt_BR": "Estratégia, builds e reclamação sobre o pátio cheio.",
	"en": "Strategy, builds, and complaining about a full yard.",
	"es": "Estrategia, builds y quejas sobre el patio lleno.",
	"fr": "Stratégie, builds, et plaintes sur une cour pleine.",
	"de": "Strategie, Builds und Beschwerden über einen vollen Hof.",
	"it": "Strategia, build e lamentele su un piazzale pieno.",
	"ru": "Стратегия, билды и жалобы на переполненный двор.",
	"pl": "Strategia, buildy i narzekanie na zapełniony plac.",
	"tr": "Strateji, build'ler ve dolu bir saha hakkında şikayetler."},
"title.community.link": {
	"pt_BR": "ABRIR DISCUSSÕES", "en": "OPEN DISCUSSIONS",
	"es": "ABRIR DISCUSIONES", "fr": "OUVRIR LES DISCUSSIONS",
	"de": "DISKUSSIONEN ÖFFNEN", "it": "APRI LE DISCUSSIONI",
	"ru": "ОТКРЫТЬ ОБСУЖДЕНИЯ", "pl": "OTWÓRZ DYSKUSJE",
	"tr": "TARTIŞMALARI AÇ"},

}
