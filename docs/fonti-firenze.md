# Firenze, settori A, B, O, F, G: fonti (1.17.1)

Zone `firenze-a`, `firenze-b`, `firenze-o`, `firenze-f`, `firenze-g`, generate da `Tools/build_firenze.py` → `Resources/Cities/firenze.json` (stato **draft**). Lo Scudo Verde ha le sue fonti in `docs/fonti-scudo-verde.md`; orari diurni e perimetri come in `docs/verifica-firenze.md`.
Fonti lette il **28/10/2026** e salvate in `data/raw/firenze/` (il build controlla che le frasi citate ci siano).

| Fatto | Fonte | File |
|---|---|---|
| Notti d'estate: *"Nei settori A, B, O, F e G la ZTL avrà validità anche nel periodo dell'anno compreso tra il primo giovedì di aprile e la prima domenica di ottobre, durante le notti comprese tra le giornate di Giovedì, Venerdì, Sabato"* | Disciplinare tecnico ZTL (Provv. Dir. 2011/M/04192 e integrazioni), punto 3: https://www.serviziallastrada.it/disciplinari/ztl/Disciplinare_ZTL.pdf | `disciplinare-ztl.txt` |
| La stessa regola sulla pagina ZTL di SAS: *"Dal primo giovedì di aprile alla prima domenica di ottobre (ZTL NOTTURNA ESTIVA …)"* | https://www.serviziallastrada.it/servizi-al-cittadino/autorizzazioni-circolazione-ztl-e-sosta-zcs-dei-veicoli/ztl | `sas-ztl.txt` |
| 2026: *"da giovedì 2 aprile è attiva la ZTL notturna estiva che durerà fino a domenica 4 ottobre"*, 23–3 su tutti i settori (DGC 2026/0099) | https://www.serviziallastrada.it/node/1023 | `sas-ztl-notturna-2026.txt` |
| Moto e scooter esenti: *"17 - Veicoli esenti. In deroga ai divieti di cui al punto 3, è consentito il transito su tutti i settori ZTL a: … Ciclomotori a due ruote (categoria L1) e motocicli (categoria L3)"*; restano i divieti antinquinamento (ord. 2018/00301) | Disciplinare, punto 17 (il cartello al varco: «eccetto veicoli a due ruote») | `disciplinare-ztl.txt` |

## Come è nel JSON
- **Stagione con la regola** (`Tools/seasons.py`, app 1.17.1): `"from": {"month": 4, "weekday": 5, "nth": 1}` (primo giovedì di aprile), `"to": {"month": 10, "weekday": 1, "nth": 1}` (prima domenica di ottobre). 2026: 2 aprile–4 ottobre; 2027: 1° aprile–3 ottobre; 2028: 6 aprile–1° ottobre. Le notti sono giovedì, venerdì, sabato 23→3: l'ultima è quella tra il sabato e la prima domenica di ottobre.
- **Date fisse per le app fino alla 1.17.0**: `fromMonth/fromDay` 1 aprile, `toMonth/toDay` 7 ottobre, cioè il giorno più presto e il più tardi possibili in qualunque anno. Una app vecchia segna qualche notte in più (mai una in meno) e non va ricostruita ogni anno. Prima c'erano le date del solo 2026 (2 aprile–3 ottobre), sbagliate dal 2027.
- **`exemptVehicleTypes: ["motorcycle"]`** su tutti e cinque i settori: con «Moto / scooter» nel Garage la risposta è «Sì» anche a ZTL attiva. Le app vecchie non hanno il tipo di veicolo e ignorano il campo.
