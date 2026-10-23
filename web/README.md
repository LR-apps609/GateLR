# Sito di GateLR

Una sola pagina: cerchi un hotel o un luogo e vedi subito se è in ZTL, se puoi entrare (adesso o all'ora di arrivo), gli orari, la multa e il messaggio per l'hotel. Stesse regole dell'app (port in JavaScript di `Sources/RuleEngine.swift`).

- `template.html` – la pagina (HTML, CSS e JavaScript in un file)
- `../Resources/Rules/fine.json` – importi delle multe (gli stessi dell app) con note (da `docs/multe-mappe-caratteri.md`)
- `index.html` – generato: `python3 Tools/build_site.py` mette dentro i dati di Firenze e le multe
- Mappa: MapLibre GL JS + OpenFreeMap (gratuita, senza chiave, attribuzione «© OpenMapTiles, OpenStreetMap»). Se non si carica (es. anteprima su claude.ai) resta la mappa disegnata in SVG dai perimetri ufficiali.
- Ricerca: luoghi d'esempio + geocoder Photon (komoot) quando la rete lo permette. Per la pubblicazione: Apple MapKit JS o Photon.
- «Get the app»: quando l'app è sull'App Store, mettere l'URL in `APP_STORE_URL` e attivare il meta `apple-itunes-app` (banner di Safari).
