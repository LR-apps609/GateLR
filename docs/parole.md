# Le parole di GateLR (glossario per la 1.0)

Obiettivo: usare le parole che il guidatore vede sui cartelli e nelle app che già conosce.

| Concetto | Italiano | English | Deutsch | Nota |
|---|---|---|---|---|
| La zona | ZTL (zona a traffico limitato) | ZTL (limited traffic zone) | ZTL (verkehrsbeschränkte Zone) | Sigla ovunque: è quella dei cartelli |
| Divieto in vigore | ZTL attiva | ZTL active | ZTL aktiv | Dicitura ufficiale dei pannelli (linee guida MIT 2019), in rosso |
| Divieto non in vigore | ZTL non attiva | ZTL not active | ZTL nicht aktiv | In verde sui pannelli |
| Vecchia dicitura | Varco attivo / non attivo | – | – | Ancora su pannelli vecchi; la spieghiamo in «Cos'è una ZTL?» |
| Ingresso con telecamera | varco | gate | Einfahrt | |
| Telecamera | telecamera | camera | Kamera | |
| Permesso | permesso / pass | permit / pass | Genehmigung / Pass | |
| Biglietto d'ingresso | ticket (giornaliero) | day ticket | Tagesticket | Milano e Bologna lo chiamano «ticket» |
| Zona a basse emissioni | zona verde / zona a basse emissioni | green zone / low-emission zone | Umweltzone | Area B di Milano |
| Navigazione | Naviga, Indicazioni, Percorso | Navigate, Directions, Route | Navigieren, Route | Come Apple Mappe e Google Maps |
| Parcheggio | parcheggio | car park | Parkplatz / Parkhaus | |

Fonti sul cambio di dicitura dei pannelli: [money.it](https://www.money.it/ZTL-dicitura-varco-attivo), [Sicurauto](https://www.sicurauto.it/news/codice-della-strada/ztl-la-scritta-varco-attivo-diventa-illegittima-multe-annullabili/), [MotoriOnline](https://www.motorionline.com/ztl-la-scritta-varco-attivo-non-e-piu-legale/).

## Le sette risposte (RispostaFinale): un solo titolo per lingua, ovunque

Decisione di Ledion del 09/11/2026: il «sì» si dice «Puoi entrare» (mai «Entra pure»), la condizione «A una condizione»
(mai «Entri a una condizione»), come nell'app per iPhone. Gli stessi titoli su iPhone, Android e sito (risposta e
legenda «Le risposte possibili»). La fonte è `Tools/translations.py` (italiano e tedesco) e `Tools/lang/*.py`; il sito
(`web/template.html`, chiavi `s…` e `p…`) li ripete in inglese, italiano e tedesco. Controlli: `Tools/check_strings.py`,
`ParoleTests.testSiteTitlesMatchTheApp` (iPhone), `ParoleTest.siteTitlesMatchTheApp` (Android). Il motivo del giallo va
nella riga sotto, mai nel titolo.

| Stato | English | Italiano | Deutsch | Français | Español | Nederlands | Polski | 简体中文 |
|---|---|---|---|---|---|---|---|---|
| nonEntrare | Don't enter | Non entrare | Nicht einfahren | N'entrez pas | No entres | Niet inrijden | Nie wjeżdżaj | 请勿进入 |
| condizione | On one condition | A una condizione | Mit Bedingung | À une condition | Con una condición | Op één voorwaarde | Pod jednym warunkiem | 有一个条件 |
| entraPure | You can enter | Puoi entrare | Einfahrt erlaubt | Vous pouvez entrer | Puedes entrar | Je mag erin | Możesz wjechać | 可以进入 |
| ztlNonAttiva | ZTL not active | ZTL non attiva | ZTL nicht aktiv | ZTL inactive | ZTL no activa | ZTL niet actief | ZTL nieaktywna | ZTL 未生效 |
| controllaCartello | Check the sign | Controlla il cartello | Achte auf das Schild | Vérifiez le panneau | Comprueba el cartel | Controleer het bord | Sprawdź znak | 请查看标牌 |
| nonCoperto | We don't know this place | Non conosciamo questo posto | Ort nicht bekannt | Endroit inconnu | Lugar desconocido | Plek onbekend | Nieznane miejsce | 未知地点 |
| fuoriZTL | Outside the ZTL | Fuori dalla ZTL | Außerhalb der ZTL | Hors de la ZTL | Fuera de la ZTL | Buiten de ZTL | Poza ZTL | 在 ZTL 外 |

Il nome interno `entraPure` dello stato resta (è solo un identificatore nel codice, non si mostra).
