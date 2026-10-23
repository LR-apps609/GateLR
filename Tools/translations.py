#!/usr/bin/env python3
# Scrive Resources/Localizations/{it,de}.lproj/Localizable.strings dalle tabelle qui sotto.
# Chiave = testo inglese dell'app. Uso: python3 Tools/translations.py
from pathlib import Path

T = {
# Schede e titoli
"Now": ("Adesso", "Jetzt"), "Map": ("Mappa", "Karte"), "Trip": ("Viaggio", "Reise"), "Garage": ("Garage", "Garage"),
"Your arrival": ("Il tuo arrivo", "Deine Ankunft"), "About": ("Informazioni", "Info"), "About GateLR": ("Informazioni su GateLR", "Über GateLR"),
# Risposte
"Yes, you can enter": ("Sì, puoi entrare", "Ja, du darfst rein"), "No, don't enter": ("No, non entrare", "Nein, nicht hineinfahren"),
"Yes, on one condition": ("Sì, a una condizione", "Ja, unter einer Bedingung"), "Not sure": ("Non sicuro", "Nicht sicher"),
"Yes, you can|enter": ("Sì, puoi|entrare", "Ja, du darfst|rein"), "No, don't|enter": ("No, non|entrare", "Nein, nicht|hineinfahren"),
"Yes, on one|condition": ("Sì, a una|condizione", "Ja, unter einer|Bedingung"),
"You can enter": ("Puoi entrare", "Einfahrt erlaubt"), "Don't enter": ("Non entrare", "Nicht einfahren"), "On one condition": ("A una condizione", "Mit Bedingung"),
"Gates on": ("Varchi accesi", "Kameras aktiv"), "Gates off": ("Varchi spenti", "Kameras aus"),
"The gates are off.": ("I varchi sono spenti.", "Die Kameras sind aus."), "The gates are on.": ("I varchi sono accesi.", "Die Kameras sind aktiv."),
"The gates switch back on %@.": ("Si riaccendono %@.", "Sie gehen %@ wieder an."), "They switch off %@.": ("Si spengono %@.", "Sie gehen %@ aus."),
"The gates are on, but your permit covers this vehicle.": ("I varchi sono accesi, ma il tuo permesso copre questo veicolo.", "Die Kameras sind aktiv, aber deine Genehmigung gilt für dieses Fahrzeug."),
"The gates are on, but %@ vehicles may enter.": ("I varchi sono accesi, ma i veicoli %@ possono entrare.", "Die Kameras sind aktiv, aber Fahrzeuge mit Antrieb „%@“ dürfen einfahren."),
"Your permit is still waiting for confirmation. Drive in only once it's confirmed.": ("Il tuo permesso è ancora in attesa di conferma. Entra solo quando è confermato.", "Deine Genehmigung ist noch nicht bestätigt. Fahr erst hinein, wenn sie bestätigt ist."),
"You can drive to the hotel only if the hotel registers your plate with the city.": ("Puoi arrivare all'hotel solo se l'hotel comunica la tua targa al Comune.", "Du darfst nur zum Hotel fahren, wenn das Hotel dein Kennzeichen bei der Stadt anmeldet."),
"It's a public holiday and we haven't confirmed whether the gates are off. Check the sign at the gate.": ("È festivo e non abbiamo conferma che i varchi siano spenti. Controlla il cartello al varco.", "Heute ist Feiertag und wir wissen nicht sicher, ob die Kameras aus sind. Achte auf das Schild an der Einfahrt."),
"This zone hasn't been checked for %lld days. Look at the city's page before driving in.": ("Questa zona non viene controllata da %lld giorni. Guarda la pagina del Comune prima di entrare.", "Diese Zone wurde seit %lld Tagen nicht geprüft. Sieh dir vor der Einfahrt die Seite der Stadt an."),
"today at %@": ("oggi alle %@", "heute um %@"), "tomorrow at %@": ("domani alle %@", "morgen um %@"), "on %@ at %@": ("%@ alle %@", "am %@ um %@"),
"On since %@": ("Accesi dalle %@", "Aktiv seit %@"), "Off since %@": ("Spenti dalle %@", "Aus seit %@"), "Off in %@": ("Si spengono tra %@", "Aus in %@"), "On in %@": ("Si accendono tra %@", "Aktiv in %@"),
"%lld d %lld h": ("%lld g %lld h", "%lld T %lld Std"), "%lld h %lld min": ("%lld h %lld min", "%lld Std %lld Min"), "%lld min": ("%lld min", "%lld Min"),
"Checked %@": ("Controllato il %@", "Geprüft am %@"), "Read %@": ("Letto il %@", "Gelesen am %@"), "Why?": ("Perché?", "Warum?"),
"Sector %@": ("Settore %@", "Sektor %@"),
"Sample data, not real": ("Dati di esempio, non reali", "Beispieldaten, nicht echt"),
"Draft: from official sources, not yet reviewed by a person": ("Bozza: dalle fonti ufficiali, non ancora rivista da una persona", "Entwurf: aus offiziellen Quellen, noch nicht von einer Person geprüft"),
# Now
"Change": ("Cambia", "Ändern"), "Arriving later?": ("Arrivi più tardi?", "Kommst du später an?"),
"Check the day and time you'll get there": ("Controlla il giorno e l'ora del tuo arrivo", "Prüfe Tag und Uhrzeit deiner Ankunft"),
"Gates near you": ("Varchi vicino a te", "Einfahrten in deiner Nähe"),
"This sector has no gates of its own: you enter it through the gates of the sectors around it.": ("Questo settore non ha varchi propri: ci entri dai varchi dei settori intorno.", "Dieser Sektor hat keine eigenen Einfahrten: du kommst über die Einfahrten der Sektoren drumherum hinein."),
"Road signs on site always win over the app.": ("Vale sempre la segnaletica sul posto, non l'app.", "Es gelten immer die Schilder vor Ort, nicht die App."),
# Mappa
"Gate off": ("Varco spento", "Kamera aus"), "Gate on": ("Varco acceso", "Kamera aktiv"), "Parking": ("Parcheggio", "Parkplatz"),
"Zone details": ("Dettagli zona", "Zonendetails"), "Park outside": ("Parcheggia fuori", "Außerhalb parken"), "Searching…": ("Cerco…", "Suche…"),
"Outside the ZTL": ("Fuori dalla ZTL", "Außerhalb der ZTL"), "Directions in Maps": ("Indicazioni in Mappe", "Route in Karten"),
"Prices and opening hours: check the car park before you go.": ("Prezzi e orari: controlla il parcheggio prima di andare.", "Preise und Öffnungszeiten: prüfe den Parkplatz vorher."),
"No car parks found just outside the zone.": ("Nessun parcheggio trovato appena fuori dalla zona.", "Keine Parkplätze direkt außerhalb der Zone gefunden."),
"Couldn't search car parks right now. Check your connection.": ("Non riesco a cercare i parcheggi adesso. Controlla la connessione.", "Parkplätze konnten gerade nicht gesucht werden. Prüfe deine Verbindung."),
# Scheda zona
"In short": ("In breve", "Kurz gesagt"), "When it's on": ("Quando è attiva", "Wann sie aktiv ist"), "The city's own words": ("Le parole del Comune", "Der Originaltext der Stadt"),
"Translation: %@": ("Traduzione: %@", "Übersetzung: %@"), "Read it on the city's page": ("Leggilo sulla pagina del Comune", "Auf der Seite der Stadt lesen"),
"If you drive in by mistake": ("Se entri per sbaglio", "Wenn du aus Versehen hineinfährst"), "per day": ("al giorno", "pro Tag"),
"Amounts still being checked against the official text.": ("Importi ancora da verificare sul testo ufficiale.", "Beträge werden noch am offiziellen Text geprüft."),
"Still to check": ("Ancora da verificare", "Noch zu prüfen"), "Sources": ("Fonti", "Quellen"), "Done": ("Fine", "Fertig"),
"Public holidays": ("Festivi", "Feiertage"), "not confirmed": ("da confermare", "unbestätigt"), "open to all": ("libero", "frei"),
# Viaggio
"Arrival": ("Arrivo", "Ankunft"), "Tonight 9 pm": ("Stasera alle 21", "Heute 21 Uhr"), "Tomorrow 10 am": ("Domani alle 10", "Morgen 10 Uhr"),
"Saturday 6 pm": ("Sabato alle 18", "Samstag 18 Uhr"), "Sunday noon": ("Domenica a mezzogiorno", "Sonntag 12 Uhr"),
"Hotel name (optional)": ("Nome dell'hotel (facoltativo)", "Hotelname (optional)"), "Hotel is inside the ZTL": ("L'hotel è dentro la ZTL", "Hotel liegt in der ZTL"),
"Sector": ("Settore", "Sektor"), "Message for the hotel": ("Messaggio per l'hotel", "Nachricht ans Hotel"), "Message language": ("Lingua del messaggio", "Sprache der Nachricht"),
"Add your plate in Garage to fill it in.": ("Aggiungi la targa nel Garage per completarlo.", "Trag dein Kennzeichen in der Garage ein, um es auszufüllen."),
"Send to hotel": ("Invia all'hotel", "Ans Hotel senden"), "Copy": ("Copia", "Kopieren"), "Copied": ("Copiato", "Kopiert"),
"Warn me %lld m before a gate": ("Avvisami %lld m prima di un varco", "Warne mich %lld m vor einer Einfahrt"),
# Garage
"Vehicles": ("Veicoli", "Fahrzeuge"), "Permits": ("Permessi", "Genehmigungen"), "In use": ("In uso", "Aktiv"), "Use": ("Usa", "Nutzen"),
"Add a permit": ("Aggiungi un permesso", "Genehmigung hinzufügen"), "Add a vehicle": ("Aggiungi un veicolo", "Fahrzeug hinzufügen"),
"Alerts": ("Avvisi", "Warnungen"), "Gate alerts": ("Avvisi ai varchi", "Warnungen an Einfahrten"),
"Alerts work with the app closed for the saved cities. They need location access \"Always\".": ("Gli avvisi funzionano ad app chiusa per le città salvate. Serve l'accesso alla posizione «Sempre».", "Warnungen funktionieren bei geschlossener App für gespeicherte Städte. Dafür braucht es Standortzugriff „Immer“."),
"Offline cities": ("Città offline", "Offline-Städte"), "Sources, licences and disclaimer": ("Fonti, licenze e avvertenze", "Quellen, Lizenzen und Hinweise"), "Version": ("Versione", "Version"),
"Name (e.g. Rental car)": ("Nome (es. Auto a noleggio)", "Name (z. B. Mietwagen)"), "Model": ("Modello", "Modell"), "Plate": ("Targa", "Kennzeichen"),
"Fuel": ("Alimentazione", "Antrieb"), "Rental car": ("Auto a noleggio", "Mietwagen"), "New vehicle": ("Nuovo veicolo", "Neues Fahrzeug"),
"Cancel": ("Annulla", "Abbrechen"), "Save": ("Salva", "Sichern"), "Type": ("Tipo", "Art"), "From": ("Dal", "Von"), "To": ("Al", "Bis"), "New permit": ("Nuovo permesso", "Neue Genehmigung"),
"Petrol": ("Benzina", "Benzin"), "Diesel": ("Diesel", "Diesel"), "Hybrid": ("Ibrida", "Hybrid"), "Electric": ("Elettrica", "Elektro"), "LPG / methane": ("GPL / metano", "Autogas / Erdgas"),
"Hotel registration": ("Registrazione dall'hotel", "Anmeldung durchs Hotel"), "Resident permit": ("Permesso residenti", "Anwohnergenehmigung"),
"Disabled badge": ("Contrassegno disabili", "Behindertenausweis"), "Other permit": ("Altro permesso", "Andere Genehmigung"),
"Confirmed": ("Confermato", "Bestätigt"), "Waiting": ("In attesa", "Ausstehend"),
# About
"Know before the gate.": ("Sappilo prima del varco.", "Wissen vor der Einfahrt."),
"GateLR explains Italy's limited traffic zones in plain words and links every rule to the city's official source.": ("GateLR spiega le zone a traffico limitato italiane con parole semplici e collega ogni regola alla fonte ufficiale del Comune.", "GateLR erklärt Italiens verkehrsberuhigte Zonen in einfachen Worten und verlinkt jede Regel mit der offiziellen Quelle der Stadt."),
"Please note": ("Da sapere", "Bitte beachten"),
"Road signs and gate panels on site always win over the app.": ("Cartelli e pannelli ai varchi valgono sempre più dell'app.", "Schilder und Anzeigen an den Einfahrten gelten immer vor der App."),
"Cities marked Draft come from official sources but haven't been reviewed by a person yet.": ("Le città segnate come Bozza vengono dalle fonti ufficiali ma non sono ancora state riviste da una persona.", "Als Entwurf markierte Städte stammen aus offiziellen Quellen, wurden aber noch nicht von einer Person geprüft."),
"GateLR is not affiliated with any city or with the police.": ("GateLR non è collegata ad alcun Comune né alla polizia.", "GateLR ist mit keiner Stadt und nicht mit der Polizei verbunden."),
"Typeface and maps": ("Carattere e mappe", "Schrift und Karten"), "Maps and car parks: Apple Maps.": ("Mappe e parcheggi: Apple Mappe.", "Karten und Parkplätze: Apple Karten."),
# Primo avvio
"Italy's old towns have camera gates": ("I centri storici hanno i varchi con telecamera", "Italiens Altstädte haben Kamera-Einfahrten"),
"ZTL means limited traffic zone. Cameras read every plate, and driving in at the wrong time means a fine that reaches you months later, even at home.": ("ZTL vuol dire zona a traffico limitato. Le telecamere leggono ogni targa: entrare all'ora sbagliata significa una multa che arriva mesi dopo, anche a casa.", "ZTL heißt verkehrsberuhigte Zone. Kameras lesen jedes Kennzeichen, und wer zur falschen Zeit hineinfährt, bekommt Monate später ein Bußgeld – auch nach Hause."),
"One clear answer": ("Una risposta chiara", "Eine klare Antwort"),
"GateLR tells you if you can enter right now, or when you arrive: yes, no, on one condition, or not sure. Never a guess.": ("GateLR ti dice se puoi entrare adesso o quando arrivi: sì, no, a una condizione, oppure non sicuro. Mai a caso.", "GateLR sagt dir, ob du jetzt oder bei deiner Ankunft hineindarfst: ja, nein, unter einer Bedingung oder nicht sicher. Nie geraten."),
"Every rule has its source": ("Ogni regola ha la sua fonte", "Jede Regel hat ihre Quelle"),
"Each answer links to the city's official page, with the date we read it. Road signs on site always win over the app.": ("Ogni risposta porta alla pagina ufficiale del Comune, con la data in cui l'abbiamo letta. Vale sempre la segnaletica sul posto.", "Jede Antwort verlinkt die offizielle Seite der Stadt, mit dem Datum, an dem wir sie gelesen haben. Es gelten immer die Schilder vor Ort."),
"Next": ("Avanti", "Weiter"), "Start": ("Inizia", "Los geht's"), "Skip": ("Salta", "Überspringen"),
# Avvisi
"ZTL gate in %lld m · it's ON": ("Varco ZTL tra %lld m · è ACCESO", "ZTL-Einfahrt in %lld m · AKTIV"),
"Don't drive in. Tap for parking outside.": ("Non entrare. Tocca per i parcheggi fuori.", "Nicht hineinfahren. Tippe für Parkplätze außerhalb."),
}

def esc(s): return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
root = Path(__file__).resolve().parent.parent / "Resources/Localizations"
for i, code in enumerate(["it", "de"]):
    d = root / f"{code}.lproj"; d.mkdir(parents=True, exist_ok=True)
    lines = [f'"{esc(k)}" = "{esc(v[i])}";' for k, v in T.items()]
    (d / "Localizable.strings").write_text("/* Generato da Tools/translations.py */\n" + "\n".join(lines) + "\n", encoding="utf-8")
en = root / "en.lproj"; en.mkdir(parents=True, exist_ok=True)
(en / "Localizable.strings").write_text("/* Inglese: le chiavi sono già il testo */\n", encoding="utf-8")
print(len(T), "testi")
