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
"shop.land.done": {
	"pt_BR": "Todo o terreno em volta do porto ja e seu.",
	"en": "All the land around the port is already yours.",
	"es": "Toda la tierra alrededor del puerto ya es tuya.",
	"fr": "Toute la terre autour du port est déjà à vous.",
	"de": "Alles Land um den Hafen herum gehört bereits Ihnen.",
	"it": "Tutto il terreno intorno al porto è già tuo.",
	"ru": "Вся земля вокруг порта уже ваша.",
	"pl": "Cała ziemia wokół portu już należy do ciebie.",
	"tr": "Limanın etrafındaki tüm arazi zaten senin."},
"shop.requires": {
	"pt_BR": "Requer: {name}", "en": "Needs: {name}", "es": "Requiere: {name}",
	"fr": "Nécessite : {name}", "de": "Erfordert: {name}",
	"it": "Richiede: {name}", "ru": "Требуется: {name}",
	"pl": "Wymaga: {name}", "tr": "Gerekli: {name}"},
"shop.upgrade.needs": {
	"pt_BR": "Abre com: {name}", "en": "Opens with: {name}",
	"es": "Se abre con: {name}", "fr": "Ouvert par : {name}",
	"de": "Öffnet mit: {name}", "it": "Si apre con: {name}",
	"ru": "Открывает: {name}", "pl": "Otwiera: {name}",
	"tr": "Şununla açılır: {name}"},
"shop.upgrade.needs_fleet": {
	"pt_BR": "Faltam {count} x {name}", "en": "Needs {count} more {name}",
	"es": "Faltan {count} x {name}", "fr": "Il manque {count} x {name}",
	"de": "Es fehlen {count} x {name}", "it": "Mancano {count} x {name}",
	"ru": "Не хватает {count} x {name}", "pl": "Brakuje {count} x {name}",
	"tr": "{count} x {name} eksik"},
"shop.upgrade.needs_teus": {
	"pt_BR": "Movimente {amount} TEU no total",
	"en": "Handle {amount} TEU in total",
	"es": "Mueva {amount} TEU en total",
	"fr": "Déplacez {amount} TEU au total",
	"de": "Bewegen Sie insgesamt {amount} TEU",
	"it": "Muovi {amount} TEU in totale",
	"ru": "Переместите всего {amount} TEU",
	"pl": "Przenieś łącznie {amount} TEU",
	"tr": "Toplam {amount} TEU taşıyın"},
# Deliberately terse: the card's sub-label shows two lines and the second is
# "+N TEU/s". A longer sentence pushes the gain off the card, and the gain is
# half of what makes the swap a decision.
"shop.upgrade.swap": {
	"pt_BR": "Troca {name} - preço triplo",
	"en": "Replaces {name} - triple price",
	"es": "Sustituye {name} - precio triple",
	"fr": "Remplace {name} - prix triple",
	"de": "Ersetzt {name} - dreifach",
	"it": "Sostituisce {name} - prezzo triplo",
	"ru": "Заменит «{name}» - тройная цена",
	"pl": "Zastąpi {name} - potrójna cena",
	"tr": "{name} yerine - üç kat fiyat"},
# Not a word, a punctuation mark — but it is localised text like any other, and
# it belongs where the rest of it lives. "1.2B" in a pt-BR game reads as one
# point two, which is a different number.
# The offline board. Every one of these has to fit `OfflinePopup.MAX_LINE`
# characters in all nine languages — the board does not autowrap, so a long
# translation is a clipped one. `core_test_runner` checks that for every
# language rather than only the one the tests happen to run in.
# --- the first-run walkthrough -------------------------------------------
# Seu Waldemar is a retired foreman handing over his port, and he talks like
# one. The translations keep the voice — warm, direct, a bit gruff — rather than
# flattening him into instructions, because the tone is doing the onboarding as
# much as the words are.
"tut.hint.tap": {
	"pt_BR": "toque aqui para continuar", "en": "tap here to go on",
	"es": "toque aquí para continuar", "fr": "touchez ici pour continuer",
	"de": "hier tippen, um fortzufahren", "it": "tocca qui per continuare",
	"ru": "нажмите здесь, чтобы продолжить", "pl": "dotknij, aby kontynuować",
	"tr": "devam etmek için dokunun"},
"tut.hint.ship": {
	"pt_BR": "toque no navio ({count})", "en": "tap the ship ({count})",
	"es": "toque el barco ({count})", "fr": "touchez le navire ({count})",
	"de": "das Schiff antippen ({count})", "it": "tocca la nave ({count})",
	"ru": "коснитесь судна ({count})", "pl": "dotknij statku ({count})",
	"tr": "gemiye dokun ({count})"},
"tut.hint.buy": {
	"pt_BR": "compre um Estivador na loja", "en": "buy a Docker in the shop",
	"es": "compre un Estibador en la tienda", "fr": "achetez un Docker en boutique",
	"de": "im Laden einen Schauermann kaufen", "it": "compra uno Scaricatore nel negozio",
	"ru": "купите докера в магазине", "pl": "kup Dokera w sklepie",
	"tr": "dükkândan bir Liman İşçisi al"},
"tut.hello": {
	"pt_BR": "Opa! Seu Waldemar, capataz aposentado. Cuido deste porto há 40 anos - agora é teu.",
	"en": "Hey! Waldemar, retired foreman. Ran this port for 40 years - it's yours now.",
	"es": "¡Hola! Waldemar, capataz jubilado. Cuidé este puerto 40 años - ahora es tuyo.",
	"fr": "Salut ! Waldemar, contremaître retraité. 40 ans dans ce port - il est à toi.",
	"de": "Hallo! Waldemar, Vorarbeiter im Ruhestand. 40 Jahre hier - jetzt gehört er dir.",
	"it": "Ehi! Waldemar, capo scalo in pensione. 40 anni qui - adesso è tuo.",
	"ru": "Привет! Вальдемар, бригадир на пенсии. Сорок лет тут - теперь порт твой.",
	"pl": "Hej! Waldemar, brygadzista na emeryturze. 40 lat tutaj - teraz jest twój.",
	"tr": "Selam! Waldemar, emekli postabaşı. 40 yıl bu limandaydım - artık senin."},
"tut.tap_ship": {
	"pt_BR": "Tá vendo aquele navio atracado? Toca nele. Cada toque tira um container do convés.",
	"en": "See that ship alongside? Tap it. Every tap lifts a box off the deck.",
	"es": "¿Ves ese barco atracado? Tócalo. Cada toque saca un contenedor.",
	"fr": "Tu vois ce navire à quai ? Touche-le. Chaque appui sort un conteneur.",
	"de": "Siehst du das Schiff am Kai? Tipp drauf. Jeder Tipp holt eine Box vom Deck.",
	"it": "Vedi quella nave ormeggiata? Toccala. Ogni tocco toglie un container.",
	"ru": "Видишь судно у причала? Жми. Каждое нажатие снимает ящик с палубы.",
	"pl": "Widzisz ten statek przy nabrzeżu? Stukaj. Każde stuknięcie zdejmuje kontener.",
	"tr": "Rıhtımdaki gemiyi gördün mü? Dokun. Her dokunuş güverteden bir konteyner alır."},
"tut.teu": {
	"pt_BR": "Isso aí! Container movimentado é TEU no bolso. O contador lá em cima não mente.",
	"en": "That's it! A box moved is a TEU banked. The counter up there doesn't lie.",
	"es": "¡Eso es! Contenedor movido es TEU en el bolsillo. El contador no miente.",
	"fr": "Voilà ! Un conteneur bougé, c'est un TEU en poche. Le compteur ne ment pas.",
	"de": "Genau! Bewegte Box heißt TEU in der Tasche. Der Zähler oben lügt nicht.",
	"it": "Ecco! Container mosso è TEU in tasca. Il contatore lassù non mente.",
	"ru": "Вот так! Перемещённый ящик - это TEU в кармане. Счётчик наверху не врёт.",
	"pl": "O to chodzi! Przeniesiony kontener to TEU w kieszeni. Licznik nie kłamie.",
	"tr": "İşte bu! Taşınan konteyner cebe TEU demek. Yukarıdaki sayaç yalan söylemez."},
"tut.shop": {
	"pt_BR": "Agora abre a LOJA ali embaixo e contrata um Estivador. Ele descarrega sozinho.",
	"en": "Now open the SHOP down there and hire a Docker. He unloads on his own.",
	"es": "Ahora abre la TIENDA de abajo y contrata un Estibador. Descarga solo.",
	"fr": "Ouvre la BOUTIQUE en bas et embauche un Docker. Il décharge tout seul.",
	"de": "Öffne unten den LADEN und stell einen Schauermann ein. Der lädt allein ab.",
	"it": "Apri il NEGOZIO lì sotto e assumi uno Scaricatore. Scarica da solo.",
	"ru": "Открой МАГАЗИН внизу и найми докера. Он разгружает сам.",
	"pl": "Otwórz SKLEP na dole i zatrudnij Dokera. Rozładowuje sam.",
	"tr": "Aşağıdaki DÜKKANI aç ve bir Liman İşçisi tut. Kendi başına boşaltır."},
"tut.passive": {
	"pt_BR": "Pronto: TEU por segundo. Dorme, acorda, o porto continua rendendo.",
	"en": "There: TEU a second. Sleep, wake up, the port keeps earning.",
	"es": "Listo: TEU por segundo. Duerme, despierta, el puerto sigue rindiendo.",
	"fr": "Voilà : des TEU par seconde. Dors, réveille-toi, le port produit.",
	"de": "So: TEU pro Sekunde. Schlaf, wach auf, der Hafen verdient weiter.",
	"it": "Ecco: TEU al secondo. Dormi, svegliati, il porto continua a rendere.",
	"ru": "Вот: TEU в секунду. Спи, просыпайся - порт всё равно зарабатывает.",
	"pl": "Proszę: TEU na sekundę. Śpij, budź się, port dalej zarabia.",
	"tr": "İşte: saniyede TEU. Uyu, uyan, liman kazanmaya devam eder."},
"tut.pan": {
	"pt_BR": "Arrasta a tela pra cima pra ver o pátio inteiro. Enche ele de container até não caber mais.",
	"en": "Drag the screen up to see the whole yard. Fill it with boxes until nothing fits.",
	"es": "Arrastra la pantalla para ver todo el patio. Llénalo hasta que no quepa más.",
	"fr": "Fais glisser l'écran pour voir tout le parc. Remplis-le à ras bord.",
	"de": "Zieh den Bildschirm hoch für den ganzen Hof. Füll ihn, bis nichts mehr passt.",
	"it": "Trascina lo schermo per vedere tutto il piazzale. Riempilo fino all'orlo.",
	"ru": "Потяни экран вверх, чтобы увидеть весь двор. Забей его под завязку.",
	"pl": "Przeciągnij ekran w górę, by zobaczyć cały plac. Zapełnij go po brzegi.",
	"tr": "Tüm sahayı görmek için ekranı yukarı kaydır. Sığmayana kadar doldur."},
"tut.done": {
	"pt_BR": "Bom trabalho. O porto é teu.", "en": "Good work. The port is yours.",
	"es": "Buen trabajo. El puerto es tuyo.", "fr": "Beau travail. Le port est à toi.",
	"de": "Gute Arbeit. Der Hafen gehört dir.", "it": "Bel lavoro. Il porto è tuo.",
	"ru": "Хорошая работа. Порт твой.", "pl": "Dobra robota. Port jest twój.",
	"tr": "İyi iş. Liman senin."},

# --- the spotlight tour --------------------------------------------------
"spot.ship.title": {
	"pt_BR": "NAVIO ATRACADO", "en": "SHIP ALONGSIDE", "es": "BARCO ATRACADO",
	"fr": "NAVIRE À QUAI", "de": "SCHIFF AM KAI", "it": "NAVE ORMEGGIATA",
	"ru": "СУДНО У ПРИЧАЛА", "pl": "STATEK PRZY NABRZEŻU", "tr": "RIHTIMDA GEMİ"},
"spot.ship.text": {
	"pt_BR": "Toque no navio para mover carga.", "en": "Tap the ship to move cargo.",
	"es": "Toque el barco para mover carga.", "fr": "Touchez le navire pour bouger la cargaison.",
	"de": "Tippen Sie das Schiff an, um Fracht zu bewegen.",
	"it": "Tocca la nave per muovere il carico.",
	"ru": "Коснитесь судна, чтобы двигать груз.",
	"pl": "Dotknij statku, aby przenosić ładunek.",
	"tr": "Yük taşımak için gemiye dokunun."},
"spot.teu.title": {
	"pt_BR": "CONTADOR TEU", "en": "TEU COUNTER", "es": "CONTADOR TEU",
	"fr": "COMPTEUR TEU", "de": "TEU-ZÄHLER", "it": "CONTATORE TEU",
	"ru": "СЧЁТЧИК TEU", "pl": "LICZNIK TEU", "tr": "TEU SAYACI"},
"spot.teu.text": {
	"pt_BR": "Aqui chega a receita do cais.", "en": "The quay's takings land here.",
	"es": "Aquí llega el ingreso del muelle.", "fr": "Les recettes du quai arrivent ici.",
	"de": "Hier landen die Einnahmen des Kais.", "it": "Qui arrivano gli incassi della banchina.",
	"ru": "Сюда поступает выручка причала.", "pl": "Tu trafia utarg nabrzeża.",
	"tr": "Rıhtımın geliri buraya düşer."},
"spot.goal.title": {
	"pt_BR": "META DO TURNO", "en": "SHIFT GOAL", "es": "META DEL TURNO",
	"fr": "OBJECTIF DU QUART", "de": "SCHICHTZIEL", "it": "OBIETTIVO DEL TURNO",
	"ru": "ЦЕЛЬ СМЕНЫ", "pl": "CEL ZMIANY", "tr": "VARDİYA HEDEFİ"},
"spot.goal.text": {
	"pt_BR": "Acompanhe a próxima operação.", "en": "Follow the next operation.",
	"es": "Siga la próxima operación.", "fr": "Suivez la prochaine opération.",
	"de": "Verfolgen Sie den nächsten Vorgang.", "it": "Segui la prossima operazione.",
	"ru": "Следите за следующей операцией.", "pl": "Śledź następną operację.",
	"tr": "Sonraki operasyonu takip edin."},
"spot.journal.title": {
	"pt_BR": "DIÁRIO DO PORTO", "en": "PORT LOGBOOK", "es": "DIARIO DEL PUERTO",
	"fr": "JOURNAL DU PORT", "de": "HAFENLOGBUCH", "it": "DIARIO DEL PORTO",
	"ru": "СУДОВОЙ ЖУРНАЛ", "pl": "DZIENNIK PORTU", "tr": "LİMAN DEFTERİ"},
"spot.journal.text": {
	"pt_BR": "Fixe uma meta para o próximo turno.", "en": "Pin a goal for the next shift.",
	"es": "Fije una meta para el próximo turno.", "fr": "Épinglez un objectif pour le prochain quart.",
	"de": "Heften Sie ein Ziel für die nächste Schicht an.",
	"it": "Fissa un obiettivo per il prossimo turno.",
	"ru": "Закрепите цель на следующую смену.",
	"pl": "Przypnij cel na następną zmianę.",
	"tr": "Sonraki vardiya için bir hedef sabitleyin."},
"spot.shop.title": {
	"pt_BR": "PRANCHETA", "en": "CLIPBOARD", "es": "PORTAPAPELES",
	"fr": "PLANCHETTE", "de": "KLEMMBRETT", "it": "LAVAGNETTA",
	"ru": "ПЛАНШЕТ", "pl": "PODKŁADKA", "tr": "PANO"},
"spot.shop.text": {
	"pt_BR": "Contrate equipe e equipamento.", "en": "Hire crew and equipment.",
	"es": "Contrate personal y equipo.", "fr": "Embauchez équipe et matériel.",
	"de": "Stellen Sie Mannschaft und Gerät ein.", "it": "Assumi equipaggio e mezzi.",
	"ru": "Нанимайте людей и технику.", "pl": "Zatrudniaj załogę i sprzęt.",
	"tr": "Ekip ve ekipman tutun."},
"spot.capital.title": {
	"pt_BR": "CAPITAL", "en": "CAPITAL", "es": "CAPITAL", "fr": "CAPITAL",
	"de": "KAPITAL", "it": "CAPITALE", "ru": "КАПИТАЛ", "pl": "KAPITAŁ",
	"tr": "SERMAYE"},
"spot.capital.text": {
	"pt_BR": "Reconstrua o porto quando o botão de ações aparecer.",
	"en": "Rebuild the port when the shares key appears.",
	"es": "Reconstruya el puerto cuando aparezca el botón de acciones.",
	"fr": "Reconstruisez le port quand la touche actions apparaît.",
	"de": "Bauen Sie den Hafen neu, wenn die Anteilstaste erscheint.",
	"it": "Ricostruisci il porto quando appare il tasto azioni.",
	"ru": "Перестройте порт, когда появится кнопка акций.",
	"pl": "Odbuduj port, gdy pojawi się przycisk akcji.",
	"tr": "Hisse tuşu göründüğünde limanı yeniden kurun."},
"spot.routes.title": {
	"pt_BR": "ROTAS DE CARGA", "en": "CARGO ROUTES", "es": "RUTAS DE CARGA",
	"fr": "ROUTES DE FRET", "de": "FRACHTROUTEN", "it": "ROTTE DI CARICO",
	"ru": "ГРУЗОВЫЕ МАРШРУТЫ", "pl": "TRASY ŁADUNKÓW", "tr": "YÜK ROTALARI"},
"spot.routes.text": {
	"pt_BR": "Novas rotas aparecerão no Diário conforme o porto cresce.",
	"en": "New routes appear in the Logbook as the port grows.",
	"es": "Nuevas rutas aparecerán en el Diario según crezca el puerto.",
	"fr": "De nouvelles routes apparaissent dans le Journal quand le port grandit.",
	"de": "Neue Routen erscheinen im Logbuch, wenn der Hafen wächst.",
	"it": "Nuove rotte appaiono nel Diario man mano che il porto cresce.",
	"ru": "Новые маршруты появляются в журнале по мере роста порта.",
	"pl": "Nowe trasy pojawiają się w Dzienniku wraz z rozwojem portu.",
	"tr": "Liman büyüdükçe Deftere yeni rotalar gelir."},
"spot.next": {
	"pt_BR": "PRÓXIMO", "en": "NEXT", "es": "SIGUIENTE", "fr": "SUIVANT",
	"de": "WEITER", "it": "AVANTI", "ru": "ДАЛЕЕ", "pl": "DALEJ", "tr": "İLERİ"},
"offline.title": {
	"pt_BR": "O PORTO NÃO DORMIU", "en": "THE PORT NEVER SLEPT",
	"es": "EL PUERTO NO DURMIÓ", "fr": "LE PORT N'A PAS DORMI",
	"de": "DER HAFEN SCHLIEF NICHT", "it": "IL PORTO NON HA DORMITO",
	"ru": "ПОРТ НЕ СПАЛ", "pl": "PORT NIE SPAŁ", "tr": "LİMAN UYUMADI"},
"offline.greeting.short": {
	"pt_BR": "Os guindastes trabalharam sem você:",
	"en": "The cranes worked without you:",
	"es": "Las grúas trabajaron sin usted:",
	"fr": "Les grues ont travaillé sans vous :",
	"de": "Die Krane arbeiteten ohne Sie:",
	"it": "Le gru hanno lavorato senza di te:",
	"ru": "Краны работали без вас:",
	"pl": "Dźwigi pracowały bez ciebie:",
	"tr": "Vinçler sensiz çalıştı:"},
"offline.greeting.away": {
	"pt_BR": "Fora por {time}. O porto não parou:",
	"en": "Away {time}. The port kept going:",
	"es": "Fuera {time}. El puerto siguió:",
	"fr": "Absent {time}. Le port a continué :",
	"de": "{time} weg. Der Hafen lief weiter:",
	"it": "Via per {time}. Il porto è andato:",
	"ru": "Вас не было {time}. Порт работал:",
	"pl": "Nieobecny {time}. Port działał:",
	"tr": "{time} yoktun. Liman çalıştı:"},
"offline.counted": {
	"pt_BR": "{time} contadas x {rate} TEU/s x {pct}%",
	"en": "{time} counted x {rate} TEU/s x {pct}%",
	"es": "{time} contadas x {rate} TEU/s x {pct}%",
	"fr": "{time} comptées x {rate} TEU/s x {pct}%",
	"de": "{time} gezählt x {rate} TEU/s x {pct}%",
	"it": "{time} contate x {rate} TEU/s x {pct}%",
	"ru": "{time} зачтено x {rate} TEU/s x {pct}%",
	"pl": "{time} zliczone x {rate} TEU/s x {pct}%",
	"tr": "{time} sayıldı x {rate} TEU/s x {pct}%"},
"offline.capped": {
	"pt_BR": "Limite de {time}: {amount} TEU fora",
	"en": "{time} cap: {amount} TEU missed",
	"es": "Límite de {time}: {amount} TEU fuera",
	"fr": "Plafond {time} : {amount} TEU perdus",
	"de": "Grenze {time}: {amount} TEU verpasst",
	"it": "Limite {time}: {amount} TEU persi",
	"ru": "Предел {time}: {amount} TEU мимо",
	"pl": "Limit {time}: {amount} TEU poza",
	"tr": "{time} sınırı: {amount} TEU dışta"},
"offline.ok": {
	"pt_BR": "BELEZA", "en": "GOT IT", "es": "VALE", "fr": "OK",
	"de": "ALLES KLAR", "it": "OK", "ru": "ЯСНО", "pl": "JASNE",
	"tr": "TAMAM"},
"number.decimal": {
	"pt_BR": ",", "en": ".", "es": ",", "fr": ",", "de": ",",
	"it": ",", "ru": ",", "pl": ",", "tr": ","},
"shop.map.pick": {
	"pt_BR": "Toque numa estação", "en": "Tap a station",
	"es": "Toque una estación", "fr": "Touchez une station",
	"de": "Station antippen", "it": "Tocca una stazione",
	"ru": "Коснитесь станции", "pl": "Dotknij stacji",
	"tr": "Bir istasyona dokun"},
"shop.map.hint": {
	"pt_BR": "Cada linha é um ramo. Arraste para andar, pince para aproximar.",
	"en": "Each line is a branch. Drag to move, pinch to zoom.",
	"es": "Cada línea es una rama. Arrastre para mover, pellizque para acercar.",
	"fr": "Chaque ligne est une branche. Glissez pour vous déplacer, pincez pour zoomer.",
	"de": "Jede Linie ist ein Zweig. Ziehen zum Bewegen, kneifen zum Zoomen.",
	"it": "Ogni linea è un ramo. Trascina per spostarti, pizzica per ingrandire.",
	"ru": "Каждая линия - ветка. Тяните, чтобы двигаться, сводите пальцы для масштаба.",
	"pl": "Każda linia to gałąź. Przeciągnij, aby się poruszać, uszczypnij, aby przybliżyć.",
	"tr": "Her hat bir daldır. Kaydırarak gezin, sıkıştırarak yakınlaş."},
"shop.upgrades.available": {
	"pt_BR": "DISPONÍVEIS", "en": "AVAILABLE", "es": "DISPONIBLES",
	"fr": "DISPONIBLES", "de": "VERFÜGBAR", "it": "DISPONIBILI",
	"ru": "ДОСТУПНО", "pl": "DOSTĘPNE", "tr": "MEVCUT"},
"shop.upgrades.next": {
	"pt_BR": "PRÓXIMAS", "en": "COMING UP", "es": "PRÓXIMAS",
	"fr": "BIENTÔT", "de": "ALS NÄCHSTES", "it": "PROSSIME",
	"ru": "СЛЕДУЮЩИЕ", "pl": "NASTĘPNE", "tr": "SIRADAKİ"},
"shop.upgrades.owned": {
	"pt_BR": "COMPRADAS ({n})", "en": "OWNED ({n})", "es": "COMPRADAS ({n})",
	"fr": "ACQUISES ({n})", "de": "GEKAUFT ({n})", "it": "ACQUISTATE ({n})",
	"ru": "КУПЛЕНО ({n})", "pl": "KUPIONE ({n})", "tr": "ALINANLAR ({n})"},
"shop.upgrades.summary": {
	"pt_BR": "{owned}/{total} compradas • {ready} prontas",
	"en": "{owned}/{total} owned • {ready} ready",
	"es": "{owned}/{total} compradas • {ready} listas",
	"fr": "{owned}/{total} acquises • {ready} prêtes",
	"de": "{owned}/{total} gekauft • {ready} bereit",
	"it": "{owned}/{total} acquistate • {ready} pronte",
	"ru": "{owned}/{total} куплено • {ready} готово",
	"pl": "{owned}/{total} kupione • {ready} gotowe",
	"tr": "{owned}/{total} alındı • {ready} hazır"},
"shop.upgrades.more": {
	"pt_BR": "+{n} mais adiante na árvore", "en": "+{n} further up the tree",
	"es": "+{n} más adelante en el árbol", "fr": "+{n} plus loin dans l'arbre",
	"de": "+{n} weiter oben im Baum", "it": "+{n} più avanti nell'albero",
	"ru": "+{n} дальше по дереву", "pl": "+{n} dalej w drzewie",
	"tr": "+{n} ağaçta ileride"},
"shop.upgrades.map": {
	"pt_BR": "MAPA", "en": "MAP", "es": "MAPA", "fr": "CARTE", "de": "KARTE",
	"it": "MAPPA", "ru": "КАРТА", "pl": "MAPA", "tr": "HARİTA"},
"shop.upgrades.list": {
	"pt_BR": "LISTA", "en": "LIST", "es": "LISTA", "fr": "LISTE", "de": "LISTE",
	"it": "LISTA", "ru": "СПИСОК", "pl": "LISTA", "tr": "LİSTE"},
"shop.map.buy": {
	"pt_BR": "COMPRAR", "en": "BUY", "es": "COMPRAR", "fr": "ACHETER",
	"de": "KAUFEN", "it": "COMPRA", "ru": "КУПИТЬ", "pl": "KUP",
	"tr": "SATIN AL"},
"shop.map.owned": {
	"pt_BR": "PRONTO", "en": "DONE", "es": "LISTO", "fr": "FAIT",
	"de": "FERTIG", "it": "FATTO", "ru": "ГОТОВО", "pl": "GOTOWE",
	"tr": "TAMAM"},
"shop.map.shut": {
	"pt_BR": "FECHADO", "en": "SHUT", "es": "CERRADO", "fr": "FERMÉ",
	"de": "ZU", "it": "CHIUSO", "ru": "ЗАКРЫТО", "pl": "ZAMKNIĘTE",
	"tr": "KAPALI"},
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
"title.about": {
	"pt_BR": "SOBRE", "en": "ABOUT", "es": "ACERCA DE",
	"fr": "À PROPOS", "de": "ÜBER", "it": "INFO",
	"ru": "О ИГРЕ", "pl": "O GRZE", "tr": "HAKKINDA"},
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

# ------------------------------------------------------ missões do dia (daily)
# Mission labels, kept short like the wheel's. Multipliers are written with
# the letter x, never the × glyph, to keep the rows uniform.

"daily.title": {
	"pt_BR": "MISSÕES DO DIA", "en": "DAILY MISSIONS", "es": "MISIONES DEL DÍA",
	"fr": "MISSIONS DU JOUR", "de": "TAGESMISSIONEN", "it": "MISSIONI DEL GIORNO",
	"ru": "ЗАДАНИЯ ДНЯ", "pl": "ZADANIA DNIA", "tr": "GÜNLÜK GÖREVLER"},
"daily.streak": {
	"pt_BR": "SEQUÊNCIA: {n} DIAS", "en": "STREAK: {n} DAYS", "es": "RACHA: {n} DÍAS",
	"fr": "SÉRIE: {n} JOURS", "de": "SERIE: {n} TAGE", "it": "SERIE: {n} GIORNI",
	"ru": "СЕРИЯ: {n} ДНЕЙ", "pl": "SERIA: {n} DNI", "tr": "SERİ: {n} GÜN"},
"daily.best": {
	"pt_BR": "recorde {n}", "en": "best {n}", "es": "récord {n}",
	"fr": "record {n}", "de": "Rekord {n}", "it": "record {n}",
	"ru": "рекорд {n}", "pl": "rekord {n}", "tr": "rekor {n}"},
"daily.claim": {
	"pt_BR": "RESGATAR", "en": "CLAIM", "es": "RECLAMAR",
	"fr": "RÉCLAMER", "de": "EINLÖSEN", "it": "RITIRA",
	"ru": "ЗАБРАТЬ", "pl": "ODBIERZ", "tr": "AL"},
"daily.done": {
	"pt_BR": "FEITO", "en": "DONE", "es": "HECHO",
	"fr": "FAIT", "de": "ERLEDIGT", "it": "FATTO",
	"ru": "ГОТОВО", "pl": "GOTOWE", "tr": "BİTTİ"},
"daily.bonus": {
	"pt_BR": "Todas as 3: TURBO x3 por 2 min + 1 ficha",
	"en": "All 3: TURBO x3 for 2 min + 1 token",
	"es": "Las 3: TURBO x3 2 min + 1 ficha",
	"fr": "Les 3: TURBO x3 2 min + 1 jeton",
	"de": "Alle 3: TURBO x3 2 Min + 1 Chip",
	"it": "Tutte 3: TURBO x3 2 min + 1 gettone",
	"ru": "Все 3: ТУРБО x3 2 мин + 1 фишка",
	"pl": "3/3: TURBO x3 2 min + 1 żeton",
	"tr": "3'ü de: TURBO x3 2 dk + 1 jeton"},
"daily.reset": {
	"pt_BR": "novas missões em {time}", "en": "new missions in {time}",
	"es": "nuevas misiones en {time}", "fr": "nouvelles missions dans {time}",
	"de": "neue Missionen in {time}", "it": "nuove missioni in {time}",
	"ru": "новые задания через {time}", "pl": "nowe zadania za {time}",
	"tr": "yeni görevler {time}"},
"daily.mission.unload": {
	"pt_BR": "Mova {goal} contêineres", "en": "Move {goal} containers",
	"es": "Mueve {goal} contenedores", "fr": "Bouge {goal} conteneurs",
	"de": "Bewege {goal} Container", "it": "Sposta {goal} container",
	"ru": "Перемести {goal} конт.", "pl": "Przenieś {goal} kontenery",
	"tr": "{goal} konteyner taşı"},
"daily.mission.taps": {
	"pt_BR": "Toque no navio {goal} vezes", "en": "Tap the ship {goal} times",
	"es": "Toca el barco {goal} veces", "fr": "Touche le navire {goal} fois",
	"de": "Tippe {goal}x auf das Schiff", "it": "Tocca la nave {goal} volte",
	"ru": "Тапни по судну {goal} раз", "pl": "Stuknij statek {goal} razy",
	"tr": "Gemiye {goal} kez dokun"},
"daily.mission.ships": {
	"pt_BR": "Despache {goal} navios", "en": "Dispatch {goal} ships",
	"es": "Despacha {goal} barcos", "fr": "Expédie {goal} navires",
	"de": "Schicke {goal} Schiffe ab", "it": "Spedisci {goal} navi",
	"ru": "Отправь {goal} судов", "pl": "Wyślij {goal} statków",
	"tr": "{goal} gemi gönder"},
"daily.mission.machines": {
	"pt_BR": "Compre {goal} máquinas", "en": "Buy {goal} machines",
	"es": "Compra {goal} máquinas", "fr": "Achète {goal} machines",
	"de": "Kaufe {goal} Maschinen", "it": "Compra {goal} macchine",
	"ru": "Купи {goal} машин", "pl": "Kup {goal} maszyn",
	"tr": "{goal} makine al"},
"daily.mission.upgrade": {
	"pt_BR": "Compre {goal} melhoria", "en": "Buy {goal} upgrade",
	"es": "Compra {goal} mejora", "fr": "Achète {goal} amélioration",
	"de": "Kaufe {goal} Upgrade", "it": "Compra {goal} upgrade",
	"ru": "Купи {goal} улучшение", "pl": "Kup {goal} ulepszenie",
	"tr": "{goal} yükseltme al"},
"daily.mission.spin": {
	"pt_BR": "Gire a Roda da Sorte", "en": "Spin the Lucky Wheel",
	"es": "Gira la Ruleta", "fr": "Tourne la Roulette",
	"de": "Drehe am Glücksrad", "it": "Gira la Ruota",
	"ru": "Крути колесо", "pl": "Zakręć kołem",
	"tr": "Çarkı çevir"},
"daily.mission.gull": {
	"pt_BR": "Pegue uma gaivota dourada", "en": "Catch a golden gull",
	"es": "Atrapa una gaviota dorada", "fr": "Attrape une mouette dorée",
	"de": "Fang die Goldmöwe", "it": "Prendi un gabbiano dorato",
	"ru": "Поймай золотую чайку", "pl": "Złap złotą mewę",
	"tr": "Altın martı yakala"},

# ------------------------------------------------------- roda da sorte (wheel)
# Small labels, so every translation stays short. The × is in the bitmap font
# (see tools/sprites/gen_font.py, "x_mult").

"skill.skill_overtime": {
	"pt_BR": "Turno Extra", "en": "Overtime", "es": "Turno extra", "fr": "Heures sup",
	"de": "Überstunden", "it": "Straordinario", "ru": "Сверхурочные",
	"pl": "Nadgodziny", "tr": "Fazla mesai"},
"skill.skill_overtime.desc": {
	"pt_BR": "Produção x2 por 30 s.", "en": "Production x2 for 30 s.",
	"es": "Producción x2 por 30 s.", "fr": "Production x2 pendant 30 s.",
	"de": "Produktion x2 für 30 s.", "it": "Produzione x2 per 30 s.",
	"ru": "Производство x2 на 30 с.", "pl": "Produkcja x2 przez 30 s.",
	"tr": "30 sn boyunca üretim x2."},
"skill.skill_mutirao": {
	"pt_BR": "Mutirão", "en": "All Hands", "es": "Faena", "fr": "Branle-bas",
	"de": "Alle Mann", "it": "Tutti al lavoro", "ru": "Аврал",
	"pl": "Wszyscy na pokład", "tr": "Seferberlik"},
"skill.skill_mutirao.desc": {
	"pt_BR": "10 s: combo no máximo e a equipe toca por você.",
	"en": "10 s: combo maxed and the crew taps for you.",
	"es": "10 s: combo al máximo y la cuadrilla toca por ti.",
	"fr": "10 s: combo au max et l'équipe tape pour vous.",
	"de": "10 s: Combo am Limit, die Crew tippt für dich.",
	"it": "10 s: combo al massimo, la squadra tocca per te.",
	"ru": "10 с: комбо на максимуме, команда жмёт за вас.",
	"pl": "10 s: combo na maksimum, ekipa stuka za ciebie.",
	"tr": "10 sn: kombo en üstte, ekip senin yerine dokunur."},
"skill.skill_pilot": {
	"pt_BR": "Prático a Bordo", "en": "Pilot Aboard", "es": "Práctico a bordo",
	"fr": "Pilote à bord", "de": "Lotse an Bord", "it": "Pilota a bordo",
	"ru": "Лоцман на борту", "pl": "Pilot na pokładzie", "tr": "Kılavuz kaptan"},
"skill.skill_pilot.desc": {
	"pt_BR": "O bônus da próxima escala paga x3.",
	"en": "The next call's departure bonus pays x3.",
	"es": "El bono de la próxima escala paga x3.",
	"fr": "La prime de la prochaine escale paie x3.",
	"de": "Der Abfahrtsbonus des nächsten Anlaufs zahlt x3.",
	"it": "Il bonus del prossimo scalo paga x3.",
	"ru": "Бонус следующего захода x3.",
	"pl": "Premia za następne zawinięcie x3.",
	"tr": "Sonraki seferin bonusu x3 öder."},
"build.speed_up": {
	"pt_BR": "Acelerar a obra", "en": "Speed up the build", "es": "Acelerar la obra",
	"fr": "Accélérer le chantier", "de": "Bau beschleunigen", "it": "Accelera i lavori",
	"ru": "Ускорить стройку", "pl": "Przyspiesz budowę", "tr": "İnşaatı hızlandır"},
"spot.ship.text2": {
	"pt_BR": "Toque no navio. Cada toque tira uma caixa e paga TEU.", "en": "Tap the ship. Each tap lifts a box and pays TEU.", "es": "Toca el barco. Cada toque saca una caja y paga TEU.",
	"fr": "Touchez le navire. Chaque tap sort une caisse et rapporte des EVP.", "de": "Tippe das Schiff an. Jeder Tipp hebt eine Kiste und bringt TEU.", "it": "Tocca la nave. Ogni tocco solleva un box e rende TEU.",
	"ru": "Нажимайте на судно. Каждое нажатие снимает контейнер и платит TEU.", "pl": "Dotykaj statku. Każde dotknięcie zdejmuje kontener i płaci TEU.", "tr": "Gemiye dokun. Her dokunuş bir konteyner indirir ve TEU kazandırır."},
"spot.teu.text2": {
	"pt_BR": "Esse é o seu TEU. Com 15 dá para contratar o primeiro Estivador.", "en": "This is your TEU. With 15 you can hire your first Docker.", "es": "Este es tu TEU. Con 15 puedes contratar al primer Estibador.",
	"fr": "Voici vos EVP. Avec 15, engagez votre premier docker.", "de": "Das sind deine TEU. Mit 15 stellst du den ersten Hafenarbeiter ein.", "it": "Questi sono i tuoi TEU. Con 15 assumi il primo scaricatore.",
	"ru": "Это ваши TEU. За 15 можно нанять первого грузчика.", "pl": "To twoje TEU. Za 15 zatrudnisz pierwszego dokera.", "tr": "Bu senin TEU'n. 15 ile ilk liman işçisini tutabilirsin."},
"spot.shop.title2": {
	"pt_BR": "LOJA", "en": "SHOP", "es": "TIENDA",
	"fr": "BOUTIQUE", "de": "SHOP", "it": "NEGOZIO",
	"ru": "МАГАЗИН", "pl": "SKLEP", "tr": "MAĞAZA"},
"spot.shop.text2": {
	"pt_BR": "Abra a loja e contrate um Estivador. Ele trabalha sozinho.", "en": "Open the shop and hire a Docker. He works on his own.", "es": "Abre la tienda y contrata un Estibador. Trabaja solo.",
	"fr": "Ouvrez la boutique et engagez un docker. Il travaille seul.", "de": "Öffne den Shop und stelle einen Hafenarbeiter ein. Er arbeitet allein.", "it": "Apri il negozio e assumi uno scaricatore. Lavora da solo.",
	"ru": "Откройте магазин и наймите грузчика. Он работает сам.", "pl": "Otwórz sklep i zatrudnij doker. Pracuje sam.", "tr": "Mağazayı aç ve bir işçi tut. Kendi başına çalışır."},
"spot.done.title": {
	"pt_BR": "PRONTO!", "en": "DONE!", "es": "¡LISTO!",
	"fr": "PRÊT !", "de": "FERTIG!", "it": "FATTO!",
	"ru": "ГОТОВО!", "pl": "GOTOWE!", "tr": "TAMAM!"},
"spot.done.text": {
	"pt_BR": "Continue tocando e comprando. O porto cresce com você.", "en": "Keep tapping and buying. The port grows with you.", "es": "Sigue tocando y comprando. El puerto crece contigo.",
	"fr": "Continuez à taper et acheter. Le port grandit avec vous.", "de": "Tippe und kaufe weiter. Der Hafen wächst mit dir.", "it": "Continua a toccare e comprare. Il porto cresce con te.",
	"ru": "Продолжайте нажимать и покупать. Порт растёт вместе с вами.", "pl": "Dotykaj i kupuj dalej. Port rośnie razem z tobą.", "tr": "Dokunmaya ve almaya devam et. Liman seninle büyür."},
"spot.wait.text": {
	"pt_BR": "O navio já vem entrando no cais...", "en": "The ship is coming alongside...", "es": "El barco ya entra al muelle...",
	"fr": "Le navire arrive à quai...", "de": "Das Schiff läuft gerade ein...", "it": "La nave sta entrando in banchina...",
	"ru": "Судно заходит к причалу...", "pl": "Statek wchodzi do nabrzeża...", "tr": "Gemi rıhtıma yaklaşıyor..."},
"spot.hint.tap": {
	"pt_BR": "toque no navio ({n}/{goal})", "en": "tap the ship ({n}/{goal})", "es": "toca el barco ({n}/{goal})",
	"fr": "touchez le navire ({n}/{goal})", "de": "tippe das Schiff an ({n}/{goal})", "it": "tocca la nave ({n}/{goal})",
	"ru": "нажмите на судно ({n}/{goal})", "pl": "dotknij statku ({n}/{goal})", "tr": "gemiye dokun ({n}/{goal})"},
"spot.hint.buy": {
	"pt_BR": "compre um Estivador", "en": "buy a Docker", "es": "compra un Estibador",
	"fr": "achetez un docker", "de": "kaufe einen Hafenarbeiter", "it": "compra uno scaricatore",
	"ru": "купите грузчика", "pl": "kup dokera", "tr": "bir işçi al"},
"spot.hint.ok": {
	"pt_BR": "toque para continuar", "en": "tap to continue", "es": "toca para seguir",
	"fr": "touchez pour continuer", "de": "tippen zum Weitermachen", "it": "tocca per continuare",
	"ru": "нажмите, чтобы продолжить", "pl": "dotknij, by kontynuować", "tr": "devam için dokun"},
"spot.skip": {
	"pt_BR": "PULAR", "en": "SKIP", "es": "SALTAR",
	"fr": "PASSER", "de": "SKIP", "it": "SALTA",
	"ru": "ПРОПУСК", "pl": "POMIŃ", "tr": "GEÇ"},
"level.short": {
	"pt_BR": "NV {n}", "en": "LV {n}", "es": "NV {n}",
	"fr": "NIV {n}", "de": "STF {n}", "it": "LIV {n}",
	"ru": "УР {n}", "pl": "POZ {n}", "tr": "SV {n}"},
"level.up": {
	"pt_BR": "NÍVEL {n}!", "en": "LEVEL {n}!", "es": "¡NIVEL {n}!",
	"fr": "NIVEAU {n} !", "de": "STUFE {n}!", "it": "LIVELLO {n}!",
	"ru": "УРОВЕНЬ {n}!", "pl": "POZIOM {n}!", "tr": "SEVİYE {n}!"},
"level.feature.objective": {
	"pt_BR": "Objetivo", "en": "Goal", "es": "Objetivo",
	"fr": "Objectif", "de": "Ziel", "it": "Obiettivo",
	"ru": "Цель", "pl": "Cel", "tr": "Hedef"},
"level.feature.upgrades": {
	"pt_BR": "Melhorias", "en": "Upgrades", "es": "Mejoras",
	"fr": "Améliorations", "de": "Upgrades", "it": "Potenziamenti",
	"ru": "Улучшения", "pl": "Ulepszenia", "tr": "Geliştirmeler"},
"level.feature.skill_overtime": {
	"pt_BR": "Turno Extra", "en": "Overtime", "es": "Turno extra",
	"fr": "Heures sup", "de": "Überstunden", "it": "Straordinario",
	"ru": "Сверхурочные", "pl": "Nadgodziny", "tr": "Fazla mesai"},
"level.feature.daily": {
	"pt_BR": "Missões do Dia", "en": "Daily Orders", "es": "Misiones",
	"fr": "Missions", "de": "Tagesaufträge", "it": "Missioni",
	"ru": "Задания", "pl": "Zadania", "tr": "Görevler"},
"level.feature.land": {
	"pt_BR": "Terreno", "en": "Land", "es": "Terreno",
	"fr": "Terrain", "de": "Land", "it": "Terreno",
	"ru": "Земля", "pl": "Teren", "tr": "Arazi"},
"level.feature.skill_mutirao": {
	"pt_BR": "Mutirão", "en": "All Hands", "es": "Faena",
	"fr": "Branle-bas", "de": "Alle Mann", "it": "Tutti al lavoro",
	"ru": "Аврал", "pl": "Wszyscy na pokład", "tr": "Seferberlik"},
"level.feature.gull": {
	"pt_BR": "Gaivota Dourada", "en": "Golden Gull", "es": "Gaviota dorada",
	"fr": "Mouette dorée", "de": "Goldmöwe", "it": "Gabbiano d'oro",
	"ru": "Золотая чайка", "pl": "Złota mewa", "tr": "Altın martı"},
"level.feature.wheel": {
	"pt_BR": "Roda da Sorte", "en": "Lucky Wheel", "es": "Ruleta",
	"fr": "Roulette", "de": "Glücksrad", "it": "Ruota",
	"ru": "Колесо", "pl": "Koło", "tr": "Çark"},
"level.feature.journal": {
	"pt_BR": "Diário", "en": "Logbook", "es": "Diario",
	"fr": "Journal", "de": "Logbuch", "it": "Diario",
	"ru": "Журнал", "pl": "Dziennik", "tr": "Seyir defteri"},
"level.feature.routes": {
	"pt_BR": "Rotas e Ramal", "en": "Routes and Rail", "es": "Rutas y ramal",
	"fr": "Routes et rail", "de": "Routen und Bahn", "it": "Rotte e raccordo",
	"ru": "Маршруты и ветка", "pl": "Trasy i bocznica", "tr": "Rotalar ve hat"},
"level.feature.charters": {
	"pt_BR": "Fretamentos", "en": "Charters", "es": "Fletamentos",
	"fr": "Affrètements", "de": "Charter", "it": "Noleggi",
	"ru": "Фрахт", "pl": "Czartery", "tr": "Çarterler"},
"level.feature.skill_pilot": {
	"pt_BR": "Prático a Bordo", "en": "Pilot Aboard", "es": "Práctico a bordo",
	"fr": "Pilote à bord", "de": "Lotse an Bord", "it": "Pilota a bordo",
	"ru": "Лоцман", "pl": "Pilot na pokładzie", "tr": "Kılavuz kaptan"},
"level.feature.decor": {
	"pt_BR": "Decoração", "en": "Decor", "es": "Decoración",
	"fr": "Déco", "de": "Deko", "it": "Decori",
	"ru": "Декор", "pl": "Dekoracje", "tr": "Dekor"},
"level.feature.orders": {
	"pt_BR": "Ordens", "en": "Orders", "es": "Órdenes",
	"fr": "Ordres", "de": "Aufträge", "it": "Ordini",
	"ru": "Приказы", "pl": "Rozkazy", "tr": "Emirler"},
"level.feature.prestige": {
	"pt_BR": "Reconstrução", "en": "Rebuild", "es": "Reconstrucción",
	"fr": "Reconstruction", "de": "Wiederaufbau", "it": "Ricostruzione",
	"ru": "Перестройка", "pl": "Przebudowa", "tr": "Yeniden inşa"},
"settings.telemetry": {
	"pt_BR": "Telemetria local", "en": "Local telemetry", "es": "Telemetría local",
	"fr": "Télémétrie locale", "de": "Lokale Telemetrie", "it": "Telemetria locale",
	"ru": "Локальная телеметрия", "pl": "Lokalna telemetria", "tr": "Yerel telemetri"},
"settings.telemetry.hint": {
	"pt_BR": "Opcional, desligada por padrão. Eventos ficam só neste aparelho, em user://telemetry.jsonl. Nada é enviado.",
	"en": "Optional, off by default. Events stay on this device only, in user://telemetry.jsonl. Nothing is sent.",
	"es": "Opcional, desactivado por defecto. Los eventos quedan solo en este aparato, en user://telemetry.jsonl. No se envía nada.",
	"fr": "Optionnel, désactivé par défaut. Les événements restent sur cet appareil, dans user://telemetry.jsonl. Rien n'est envoyé.",
	"de": "Optional, standardmäßig aus. Ereignisse bleiben nur auf diesem Gerät, in user://telemetry.jsonl. Es wird nichts gesendet.",
	"it": "Facoltativo, disattivato di default. Gli eventi restano solo su questo dispositivo, in user://telemetry.jsonl. Non viene inviato nulla.",
	"ru": "Опционально, по умолчанию выключено. События только на этом устройстве, в user://telemetry.jsonl. Ничего не отправляется.",
	"pl": "Opcjonalne, domyślnie wyłączone. Zdarzenia tylko na tym urządzeniu, w user://telemetry.jsonl. Nic nie jest wysyłane.",
	"tr": "İsteğe bağlı, varsayılan kapalı. Olaylar yalnızca bu cihazda, user://telemetry.jsonl içinde kalır. Hiçbir şey gönderilmez."},
"journal.arcade": {
	"pt_BR": "ARCADE", "en": "ARCADE", "es": "ARCADE",
	"fr": "ARCADE", "de": "ARCADE", "it": "ARCADE",
	"ru": "АРКАДА", "pl": "ARCADE", "tr": "ATARI"},
"journal.arcade.hint": {
	"pt_BR": "Um minijogo agora, por anúncio recompensado.", "en": "One minigame now, for a rewarded ad.",
	"es": "Un minijuego ahora, por anuncio recompensado.", "fr": "Un mini-jeu maintenant, contre une pub récompensée.",
	"de": "Ein Minispiel jetzt, für ein belohntes Werbevideo.", "it": "Un minigioco ora, con un annuncio premiato.",
	"ru": "Одна мини-игра сейчас, за рекламу с наградой.", "pl": "Jedna minigra teraz, za nagradzaną reklamę.",
	"tr": "Reklam karşılığında şimdi bir mini oyun."},
"arcade.title": {
	"pt_BR": "Fichinha do arcade", "en": "Arcade token", "es": "Ficha de arcade",
	"fr": "Jeton d'arcade", "de": "Arcade-Münze", "it": "Gettone arcade",
	"ru": "Жетон аркады", "pl": "Żeton arcade", "tr": "Atari jetonu"},
"cargo.premiada": {
	"pt_BR": "PREMIADA x5", "en": "PREMIUM x5", "es": "PREMIUM x5",
	"fr": "PRIME x5", "de": "PREMIUM x5", "it": "PREMIUM x5",
	"ru": "ПРЕМИЯ x5", "pl": "PREMIUM x5", "tr": "ÖDÜL x5"},
"wheel.ad_spin": {
	"pt_BR": "Girar de novo (anúncio)", "en": "Spin again (ad)", "es": "Girar otra vez (anuncio)",
	"fr": "Tourner encore (pub)", "de": "Nochmal drehen (Werbung)", "it": "Gira ancora (annuncio)",
	"ru": "Ещё раз (реклама)", "pl": "Kręć jeszcze (reklama)", "tr": "Tekrar çevir (reklam)"},
"wheel.ad_double": {
	"pt_BR": "Dobrar prêmio (anúncio)", "en": "Double the prize (ad)", "es": "Duplicar premio (anuncio)",
	"fr": "Doubler le gain (pub)", "de": "Preis verdoppeln (Werbung)", "it": "Raddoppia il premio (annuncio)",
	"ru": "Удвоить приз (реклама)", "pl": "Podwój nagrodę (reklama)", "tr": "Ödülü ikiye katla (reklam)"},
"offline.double": {
	"pt_BR": "Dobrar ganho (anúncio)", "en": "Double it (ad)", "es": "Duplicar (anuncio)",
	"fr": "Doubler (pub)", "de": "Verdoppeln (Werbung)", "it": "Raddoppia (annuncio)",
	"ru": "Удвоить (реклама)", "pl": "Podwój (reklama)", "tr": "İkiye katla (reklam)"},
"minigame.retry": {
	"pt_BR": "Tentar de novo (anúncio)", "en": "Try again (ad)", "es": "Reintentar (anuncio)",
	"fr": "Réessayer (pub)", "de": "Nochmal (Werbung)", "it": "Riprova (annuncio)",
	"ru": "Ещё раз (реклама)", "pl": "Jeszcze raz (reklama)", "tr": "Tekrar dene (reklam)"},
"minigame.again": {
	"pt_BR": "OUTRA CHANCE!", "en": "ANOTHER GO!", "es": "¡OTRA VEZ!",
	"fr": "ENCORE !", "de": "NOCHMAL!", "it": "ANCORA!",
	"ru": "ЕЩЁ РАЗ!", "pl": "JESZCZE RAZ!", "tr": "BİR ŞANS DAHA!"},
"ad.placeholder.title": {
	"pt_BR": "ANÚNCIO (TESTE)", "en": "AD (TEST)", "es": "ANUNCIO (PRUEBA)",
	"fr": "PUB (TEST)", "de": "WERBUNG (TEST)", "it": "ANNUNCIO (TEST)",
	"ru": "РЕКЛАМА (ТЕСТ)", "pl": "REKLAMA (TEST)", "tr": "REKLAM (TEST)"},
"ad.placeholder.close": {
	"pt_BR": "Fechar sem recompensa", "en": "Close without reward",
	"es": "Cerrar sin premio", "fr": "Fermer sans récompense",
	"de": "Ohne Belohnung schließen", "it": "Chiudi senza premio",
	"ru": "Закрыть без награды", "pl": "Zamknij bez nagrody",
	"tr": "Ödülsüz kapat"},
"wheel.earn": {
	"pt_BR": "+1 ficha a cada 3 navios ({have}/{need})",
	"en": "+1 token every 3 ships ({have}/{need})",
	"es": "+1 ficha cada 3 barcos ({have}/{need})",
	"fr": "+1 jeton tous les 3 navires ({have}/{need})",
	"de": "+1 Chip alle 3 Schiffe ({have}/{need})",
	"it": "+1 gettone ogni 3 navi ({have}/{need})",
	"ru": "+1 фишка за 3 судна ({have}/{need})",
	"pl": "+1 żeton co 3 statki ({have}/{need})",
	"tr": "Her 3 gemide +1 jeton ({have}/{need})"},
"wheel.title": {
	"pt_BR": "RODA DA SORTE", "en": "LUCKY WHEEL", "es": "RULETA",
	"fr": "ROULETTE", "de": "GLÜCKSRAD", "it": "RUOTA",
	"ru": "КОЛЕСО", "pl": "KOŁO", "tr": "ÇARK"},
"wheel.spin": {
	"pt_BR": "GIRAR", "en": "SPIN", "es": "GIRAR", "fr": "TOURNER",
	"de": "DREHEN", "it": "GIRA", "ru": "КРУТЬ", "pl": "KRĘĆ",
	"tr": "ÇEVİR"},
"wheel.free": {
	"pt_BR": "GRÁTIS!", "en": "FREE!", "es": "¡GRATIS!", "fr": "GRATUIT!",
	"de": "GRATIS!", "it": "GRATIS!", "ru": "ДАРОМ", "pl": "ZA DARMO",
	"tr": "BEDAVA"},
"wheel.tokens": {
	"pt_BR": "FICHAS: {n}", "en": "TOKENS: {n}", "es": "FICHAS: {n}",
	"fr": "JETONS: {n}", "de": "JETONS: {n}", "it": "GETTONI: {n}",
	"ru": "ФИШКИ: {n}", "pl": "ŻETONY: {n}", "tr": "JETON: {n}"},
"wheel.next_free": {
	"pt_BR": "GRÁTIS EM {time}", "en": "FREE {time}", "es": "GRATIS {time}",
	"fr": "GRATIS {time}", "de": "GRATIS {time}", "it": "GRATIS {time}",
	"ru": "ДАРОМ {time}", "pl": "DARMO {time}", "tr": "BEDAVA {time}"},
"wheel.token_earned": {
	"pt_BR": "+1 FICHA DA RODA", "en": "+1 TOKEN", "es": "+1 FICHA",
	"fr": "+1 JETON", "de": "+1 JETON", "it": "+1 GETTONE",
	"ru": "+1 ФИШКА", "pl": "+1 ŻETON", "tr": "+1 JETON"},
"wheel.collect": {
	"pt_BR": "COLETAR", "en": "COLLECT", "es": "COBRAR", "fr": "ENCAISSER",
	"de": "EINLÖSEN", "it": "RITIRA", "ru": "ЗАБРАТЬ", "pl": "ODBIERZ",
	"tr": "AL"},
"wheel.prize.cash_s": {
	"pt_BR": "TROCADO", "en": "SPARE", "es": "SUELTO", "fr": "MONNAIE",
	"de": "KLEINGELD", "it": "POCHI", "ru": "МЕЛОЧЬ", "pl": "DROBNE",
	"tr": "KIRINTI"},
"wheel.prize.surge2": {
	"pt_BR": "TURBO ×2", "en": "TURBO ×2", "es": "TURBO ×2",
	"fr": "TURBO ×2", "de": "TURBO ×2", "it": "TURBO ×2",
	"ru": "ТУРБО ×2", "pl": "TURBO ×2", "tr": "TURBO ×2"},
"wheel.prize.cash_m": {
	"pt_BR": "BOLADA", "en": "HAUL", "es": "BOLADA", "fr": "GROS LOT",
	"de": "BATZEN", "it": "GROSSO", "ru": "КУШ", "pl": "BONUS",
	"tr": "BÜYÜK"},
"wheel.prize.respin": {
	"pt_BR": "+1 FICHA", "en": "+1 TOKEN", "es": "+1 FICHA",
	"fr": "+1 JETON", "de": "+1 JETON", "it": "+1 GETTONE",
	"ru": "+1 ФИШКА", "pl": "+1 ŻETON", "tr": "+1 JETON"},
"wheel.prize.jackpot": {
	"pt_BR": "JACKPOT!", "en": "JACKPOT!", "es": "JACKPOT!",
	"fr": "JACKPOT!", "de": "JACKPOT!", "it": "JACKPOT!",
	"ru": "ДЖЕКПОТ!", "pl": "JACKPOT!", "tr": "JACKPOT!"},
"wheel.prize.surge3": {
	"pt_BR": "TURBO ×3", "en": "TURBO ×3", "es": "TURBO ×3",
	"fr": "TURBO ×3", "de": "TURBO ×3", "it": "TURBO ×3",
	"ru": "ТУРБО ×3", "pl": "TURBO ×3", "tr": "TURBO ×3"},
"wheel.prize.cash_l": {
	"pt_BR": "COFRE CHEIO", "en": "FULL CHEST", "es": "COFRE LLENO",
	"fr": "COFFRE PLEIN", "de": "VOLLE TRUHE", "it": "COFANO PIENO",
	"ru": "СУНДУК", "pl": "SKRZYNIA", "tr": "DOLU SANDIK"},
"wheel.prize.frenzy": {
	"pt_BR": "FRENESI ×7", "en": "FRENZY ×7", "es": "FRENESÍ ×7",
	"fr": "FOLIE ×7", "de": "RASEREI ×7", "it": "FRENZIA ×7",
	"ru": "ШТУРМ ×7", "pl": "SZAŁ ×7", "tr": "ÇILGIN ×7"},

# ------------------------------------------- gaivota dourada (golden gull)
# The prize label shown as a big crit float text where the gull was caught, so
# it has to stay short. The multiplier is written with the letter x, not the ×
# glyph, to keep the row uniform with the rest of the short labels.

"gull.hint": {
	"pt_BR": "TOQUE NA GAIVOTA!", "en": "TAP THE GULL!", "es": "¡TOCA LA GAVIOTA!",
	"fr": "TOUCHE LA MOUETTE!", "de": "TIPP DIE MÖWE AN!", "it": "TOCCA IL GABBIANO!",
	"ru": "ЖМИ НА ЧАЙКУ!", "pl": "DOTKNIJ MEWY!", "tr": "MARTIYA DOKUN!"},
"gull.lucky": {
	"pt_BR": "SORTE GRANDE!", "en": "GREAT LUCK!", "es": "¡GRAN SUERTE!",
	"fr": "CHANCE FOLLE!", "de": "RIESENGLÜCK!", "it": "GRAN FORTUNA!",
	"ru": "БОЛЬШАЯ УДАЧА!", "pl": "SZCZĘŚCIE!", "tr": "BÜYÜK ŞANS!"},
"gull.frenzy": {
	"pt_BR": "FRENESI x7!", "en": "FRENZY x7!", "es": "FRENESÍ x7!",
	"fr": "FOLIE x7!", "de": "RASEREI x7!", "it": "FRENZIA x7!",
	"ru": "ШТУРМ x7!", "pl": "SZAŁ x7!", "tr": "ÇILGIN x7!"},
"gull.token": {
	"pt_BR": "+1 FICHA!", "en": "+1 TOKEN", "es": "+1 FICHA",
	"fr": "+1 JETON", "de": "+1 JETON", "it": "+1 GETTONE",
	"ru": "+1 ФИШКА", "pl": "+1 ŻETON", "tr": "+1 JETON"},

}
