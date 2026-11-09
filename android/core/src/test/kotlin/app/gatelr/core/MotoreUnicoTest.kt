package app.gatelr.core

import java.io.File
import java.time.LocalDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** 1.20.0 «Motore unico»: le differenze con l'iPhone corrette nel motore Android (oltre ai casi comuni di shared/) */
class MotoreUnicoTest {
    private val dir = File(System.getProperty("gatelr.cities"))
    private fun city(id: String) = CityLoader.decode(File(dir, "$id.json").readText())
    private fun date(y: Int, m: Int, d: Int, h: Int) = LocalDateTime.of(y, m, d, h, 0).atZone(RuleEngine.ROME).toInstant()
    private val car = Vehicle(id = "car", name = "Rental car", fuel = Fuel.PETROL, euro = 6)

    /** 1.20.4 (decisione di Ledion del 07/11): fuori dalle zone di una città che conosciamo grigio, mai verde; la stessa
     *  risposta «Fuori dalla ZTL» della 2.0; fuori copertura resta neutro */
    @Test fun outsideIsGreyNeverGreen() {
        val cities = listOf(city("bologna"))
        val engine = RuleEngine(now = { date(2026, 11, 3, 12) })
        val station = PlaceCheck.of(cities, Coordinate(44.5058, 11.3427), engine, car, emptyList(), false, date(2026, 11, 10, 10))
        assertEquals(PlaceCheck.Kind.OUTSIDE, station.kind)
        assertEquals(AnswerColor.GREY, station.color)
        assertEquals(Stato.FUORI_ZTL, station.finale.stato)
        val pistoia = PlaceCheck.of(cities, Coordinate(43.9330, 10.9170), engine, car, emptyList(), false, date(2026, 11, 10, 10))
        assertEquals(AnswerColor.NEUTRAL, pistoia.color)
    }

    /** holidaysAsSunday si legge dal file (prima Android lo ignorava) */
    @Test fun holidaysAsSundayDecodes() {
        val b = city("bergamo")
        assertEquals(true, b.zones.first { it.id == "bergamo-colli" }.holidaysAsSunday)
        assertEquals(null, b.zones.first { it.id == "bergamo-citta-alta" }.holidaysAsSunday)
    }

    /** Come l'iPhone dalla 1.19.2: un permesso senza zona non copre niente, uno con la zona solo quella */
    @Test fun permitOnlyForItsZone() {
        val f = city("firenze")
        val a = f.zones.first { it.id == "firenze-a" }; val b = f.zones.first { it.id == "firenze-b" }
        val at = date(2026, 11, 10, 10)
        val noZone = Permit(kind = Permit.Kind.HOTEL, cityId = "firenze", zoneId = null, vehicleId = car.id,
            from = at.toEpochMilli() - 3_600_000, to = at.toEpochMilli() + 3_600_000, status = Permit.Status.CONFIRMED)
        assertFalse(noZone.covers(a, car, at))
        val forA = noZone.copy(zoneId = "firenze-a")
        assertTrue(forA.covers(a, car, at))
        assertFalse(forA.covers(b, car, at))
        val engine = RuleEngine(now = { date(2026, 11, 3, 12) })
        assertTrue(engine.answer(a, car, listOf(forA), false, at).verdict is Verdict.Yes)
        assertTrue(engine.answer(b, car, listOf(forA), false, at).verdict is Verdict.No)
    }

    /** 2.3 (decisione di Ledion del 09/11): l'hotel nella ZTL. Senza conferma rosso con «Chiedi all'hotel…»; con la conferma
     *  per il veicolo scelto, nei giorni giusti e dove l'hotel può registrare verde con «L'hotel ha registrato la targa · dal … al …»;
     *  date scadute, altra auto, zona senza registrazione dell'hotel, richiesta in attesa: rosso */
    @Test fun hotelRegistration() {
        val f = city("firenze")
        val a = f.zones.first { it.id == "firenze-a" }
        val at = date(2026, 11, 10, 10)
        val engine = RuleEngine(now = { date(2026, 11, 3, 12) })
        val day = 86_400_000L
        val conf = Permit(kind = Permit.Kind.HOTEL, cityId = "firenze", zoneId = a.id, vehicleId = car.id,
            from = at.toEpochMilli() - day, to = at.toEpochMilli() + day, status = Permit.Status.CONFIRMED)
        val none = engine.answer(a, car, emptyList(), true, at)
        assertTrue(none.verdict is Verdict.No)
        val red = RispostaFinale.forZone(none, a)
        assertEquals(Stato.NON_ENTRARE, red.stato)
        assertEquals(HotelNota.DaChiedere, red.hotel)
        assertEquals(L("Ask the hotel to register your plate"), red.reasonLine)

        val ok = engine.answer(a, car, listOf(conf), true, at)
        assertTrue(ok.verdict is Verdict.Yes)
        val green = RispostaFinale.forZone(ok, a)
        assertEquals(Stato.ENTRA_PURE, green.stato)
        assertEquals(HotelNota.Registrata(conf.from, conf.to), green.hotel)
        assertTrue(green.reasonLine!!.startsWith(L("The hotel registered your plate · from %@ to %@").substringBefore("%@")))

        // Date scadute, altra auto, richiesta in attesa: rosso con la riga dell'hotel
        val expired = conf.copy(from = at.toEpochMilli() - 5 * day, to = at.toEpochMilli() - 3 * day)
        val other = conf.copy(vehicleId = "un'altra auto")
        val waiting = conf.copy(status = Permit.Status.WAITING)
        for (p in listOf(expired, other, waiting)) {
            val r = RispostaFinale.forZone(engine.answer(a, car, listOf(p), true, at), a)
            assertEquals(Stato.NON_ENTRARE, r.stato, p.toString())
            assertEquals(HotelNota.DaChiedere, r.hotel, p.toString())
        }
        // Una zona dove l'hotel non può registrare la targa: la conferma non vale, rosso senza la riga dell'hotel
        val noHotel = a.copy(hotelCanRegister = false)
        assertFalse(conf.covers(noHotel, car, at))
        val r = RispostaFinale.forZone(engine.answer(noHotel, car, listOf(conf), true, at), noHotel)
        assertEquals(Stato.NON_ENTRARE, r.stato)
        assertEquals(null, r.hotel)
        // Un permesso di residente in attesa resta «a una condizione» (giallo): solo l'hotel cambia
        val resident = conf.copy(kind = Permit.Kind.RESIDENT, status = Permit.Status.WAITING)
        assertTrue(engine.answer(a, car, listOf(resident), false, at).verdict is Verdict.Conditional)
        // Il ticket resta mai verde (giallo «A una condizione»)
        val bologna = city("bologna").zones.first { it.id == "bologna-ztl" }
        assertEquals(Stato.CONDIZIONE, RispostaFinale.forZone(engine.answer(bologna, car, emptyList(), false, at), bologna).stato)
    }

    /** Fonte non ufficiale: il «sì» si mostra «non sicuro»; il «no» resta «no» (rosso, «Probabilmente no»), come l'iPhone */
    @Test fun unofficialYesIsShownUnsure() {
        assertTrue(Verdict.Yes("x").shown(true) is Verdict.Unsure)
        assertTrue(Verdict.Yes("x").shown(false) is Verdict.Yes)
        assertTrue(Verdict.No("x").shown(true) is Verdict.No)
        assertTrue(city("salerno").zones.all { it.isUnofficial })
    }
}
