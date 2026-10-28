#!/usr/bin/env python3
# Stagioni con regole al posto delle date fisse («dal primo giovedì di aprile alla prima domenica di ottobre»).
#
# Lo schema (dalla 1.17.1, iPhone, sito e Android):
#   "season": {"fromMonth": 4, "fromDay": 1, "toMonth": 10, "toDay": 7,
#              "from": {"month": 4, "weekday": 5, "nth": 1}, "to": {"month": 10, "weekday": 1, "nth": 1}}
# weekday 1 = domenica … 7 = sabato (come in "weekdays"); nth 1…5, -1 = l'ultimo del mese; "offset" facoltativo in giorni
# («il giovedì dopo l'ultima domenica di marzo» = {"month": 3, "weekday": 1, "nth": -1, "offset": 4}).
#
# Le app fino alla 1.17.0 scaricano le città da GitHub e non conoscono "from"/"to": li ignorano (i lettori JSON di
# iPhone e Android saltano le chiavi che non conoscono) e leggono solo le date fisse. Per loro le date fisse sono
# scritte LARGHE: l'inizio più presto e la fine più tardi possibili in qualunque anno (per il primo giovedì di aprile
# il 1° aprile, per la prima domenica di ottobre il 7 ottobre). Così una app vecchia segna come accesa qualche sera in
# più ma mai una in meno, in ogni anno, senza dover ricostruire i dati a ogni stagione (con le date di un anno solo,
# l'anno dopo potrebbe dire «entra» in una sera vietata). Le app nuove usano la regola e hanno le date giuste.
import datetime


def rule_day(rule, year):
    """Il giorno della regola nell'anno dato (datetime.date)"""
    month, weekday, nth = rule["month"], rule["weekday"], rule["nth"]
    assert 1 <= month <= 12 and 1 <= weekday <= 7 and nth != 0 and -5 <= nth <= 5, rule
    first = datetime.date(year, month, 1)
    length = ((first.replace(day=28) + datetime.timedelta(days=4)).replace(day=1) - first).days
    py = lambda d: (d.isoweekday() % 7) + 1          # Python: lunedì = 1 … domenica = 7 → domenica = 1 … sabato = 7
    if nth > 0:
        day = 1 + (weekday - py(first)) % 7 + (nth - 1) * 7
    else:
        last = first.replace(day=length)
        day = length - (py(last) - weekday) % 7 + (nth + 1) * 7
    assert 1 <= day <= length, (rule, year)
    return datetime.date(year, month, day) + datetime.timedelta(days=rule.get("offset", 0))


def _md(d):
    return d.month * 100 + d.day


def widest(rule, earliest):
    """Il giorno (mese, giorno) più presto (earliest=True) o più tardi possibile per la regola, in 400 anni
    (il calendario gregoriano si ripete ogni 400 anni)"""
    days = [_md(rule_day(rule, y)) for y in range(2000, 2400)]
    md = min(days) if earliest else max(days)
    return md // 100, md % 100


def season(start, end):
    """Una stagione: start ed end sono (mese, giorno) fissi o una regola {"month", "weekday", "nth"[, "offset"]}"""
    out = {}
    if isinstance(start, dict):
        out["fromMonth"], out["fromDay"] = widest(start, True)
    else:
        out["fromMonth"], out["fromDay"] = start
    if isinstance(end, dict):
        out["toMonth"], out["toDay"] = widest(end, False)
    else:
        out["toMonth"], out["toDay"] = end
    if isinstance(start, dict):
        out["from"] = dict(start)
    if isinstance(end, dict):
        out["to"] = dict(end)
    return out


def bounds(s, year):
    """Inizio e fine (datetime.date) della stagione nell'anno dato, come le app dalla 1.17.1"""
    a = rule_day(s["from"], year) if "from" in s else datetime.date(year, s["fromMonth"], s["fromDay"])
    b = rule_day(s["to"], year) if "to" in s else datetime.date(year, s["toMonth"], s["toDay"])
    return a, b


def shown(s, today):
    """Le date da mostrare oggi (sito statico): la stagione in corso o, se è già finita, la prossima"""
    a, b = bounds(s, today.year)
    if a <= b and today > b:
        return bounds(s, today.year + 1)
    return a, b


if __name__ == "__main__":
    # Prova: Firenze 2026–2028 e Bergamo (ora legale) 2026
    fi = season({"month": 4, "weekday": 5, "nth": 1}, {"month": 10, "weekday": 1, "nth": 1})
    assert (fi["fromMonth"], fi["fromDay"], fi["toMonth"], fi["toDay"]) == (4, 1, 10, 7), fi
    assert bounds(fi, 2026) == (datetime.date(2026, 4, 2), datetime.date(2026, 10, 4))
    assert bounds(fi, 2027) == (datetime.date(2027, 4, 1), datetime.date(2027, 10, 3))
    assert bounds(fi, 2028) == (datetime.date(2028, 4, 6), datetime.date(2028, 10, 1))
    bg = season({"month": 3, "weekday": 1, "nth": -1, "offset": 4}, {"month": 10, "weekday": 1, "nth": -1, "offset": -1})
    assert (bg["fromMonth"], bg["fromDay"], bg["toMonth"], bg["toDay"]) == (3, 29, 10, 30), bg
    assert bounds(bg, 2026) == (datetime.date(2026, 4, 2), datetime.date(2026, 10, 24))
    assert bounds(bg, 2027) == (datetime.date(2027, 4, 1), datetime.date(2027, 10, 30))
    print("ok", fi, bg)
