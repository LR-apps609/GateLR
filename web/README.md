# Sito di GateLR

Una sola pagina: cerchi un hotel o un luogo e vedi subito se è in ZTL, se puoi entrare (adesso o all'ora di arrivo), gli orari, la multa e il messaggio per l'hotel. Stesse regole dell'app (port in JavaScript di `Sources/RuleEngine.swift`).

- `template.html` – la pagina (HTML, CSS e JavaScript in un file)
- `../Resources/Rules/fine.json` – importi delle multe (gli stessi dell app) con note (da `docs/multe-mappe-caratteri.md`)
- Generati da `python3 Tools/build_site.py` (indirizzo del sito nella costante `SITE`): `index.html`, `it/index.html`, `de/index.html` (home con dati delle città, multe, meta SEO e JSON-LD), una pagina statica per città e lingua (`firenze/`, `it/firenze/`, `de/firenze/` …), `sitemap.xml`, `robots.txt`, `icon.png`
- Mappa: disegnata in SVG con i colori per tipo di zona (rossa vietata, ambra con ticket, verde a basse emissioni, viola aree pedonali); MapLibre GL JS + OpenFreeMap (gratuita, senza chiave, attribuzione «© OpenMapTiles, OpenStreetMap»). Si scarica solo quando la mappa entra nello schermo o al primo tocco; se non si carica (es. anteprima su claude.ai) resta la mappa disegnata in SVG dai perimetri ufficiali.
- Ricerca: luoghi d'esempio + geocoder Photon (komoot) quando la rete lo permette. Per la pubblicazione: Apple MapKit JS o Photon.
- «Get the app»: quando l'app è nei negozi, mettere gli URL in `APP_STORE_URL` e `PLAY_URL` e attivare il meta `apple-itunes-app` (banner di Safari).
