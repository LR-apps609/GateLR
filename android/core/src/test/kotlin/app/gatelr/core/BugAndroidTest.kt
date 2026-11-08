package app.gatelr.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import java.time.Instant
import java.time.LocalDateTime
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** 2.0.1: i bug Android confermati dai tester (test20, android-2.0.json), uno o più test per bug */
class BugAndroidTest {
    private val dir = File(System.getProperty("gatelr.cities"))
    private val cities: List<City> by lazy {
        val man = Json.parseToJsonElement(File(dir, "manifest.json").readText()).jsonObject
        (man["cities"]!!.jsonArray + (man["unofficialCities"]?.jsonArray ?: emptyList()))
            .map { CityLoader.decode(File(dir, it.jsonObject["file"]!!.jsonPrimitive.content).readText()) }
    }
    private val engine = RuleEngine()
    private val i18n = File(System.getProperty("gatelr.i18n"))
    private val app = File(System.getProperty("gatelr.app"))
    private fun src(path: String): String = File(app, path).readText()
    private fun table(lang: String): Map<String, String> =
        Json.parseToJsonElement(File(i18n, "strings_$lang.json").readText()).jsonObject.mapValues { it.value.jsonPrimitive.content }
    private fun at(y: Int, m: Int, d: Int, h: Int, min: Int = 0): Instant = LocalDateTime.of(y, m, d, h, min).atZone(RuleEngine.ROME).toInstant()
    private val rental = Vehicle(name = "Rental car", model = "Fiat 500", fuel = Fuel.PETROL, euro = 6, isRental = true)
    private val oldDiesel = Vehicle(name = "Panda", fuel = Fuel.DIESEL, euro = 1)

    @AfterTest fun english() { Strings.language = "en"; Strings.table = emptyMap() }

    // ---- B03 «Leggi il cartello»: mai verde, e «marzo» non è martedì

    @Test fun b03MarchIsNotTuesday() {
        val r = SignReader.parse("Zona traffico limitato\ndal 1 marzo al 31 ottobre\n0-24")
        assertTrue(r.understood)
        assertEquals(setOf(1, 2, 3, 4, 5, 6, 7), r.rules.single().days, "«marzo» non è «martedì»")
        // mercoledì 15/07/2026 alle 12: secondo il cartello è accesa (0-24)
        assertEquals(SignReader.Reading.ACTIVE, SignReader.reading(r, at(2026, 7, 15, 12)))
        assertNull(SignReader.days("dal 1 marzo"), "nessun giorno in «marzo»")
        assertNull(SignReader.days("domani venti giorni merci"))
        assertEquals(setOf(3), SignReader.days("solo mar. 8-14"))
        assertEquals(setOf(3), SignReader.days("martedì"))
        assertEquals(setOf(2, 3, 4, 5, 6), SignReader.days("da lunedì a venerdì"))
        assertEquals(setOf(2, 3, 4, 5, 6, 7), SignReader.days("lun-sab"))
    }

    @Test fun b03SignNeverGreen() {
        val r = SignReader.parse("7.30-20.00 feriali")
        // domenica 12/07/2026 alle 12: spenta secondo il cartello → giallo «sembra spenta», mai «puoi entrare»
        assertEquals(SignReader.Reading.SEEMS_OFF, SignReader.reading(r, at(2026, 7, 12, 12)))
        assertEquals(SignReader.Reading.ACTIVE, SignReader.reading(r, at(2026, 7, 13, 12)))
        assertEquals(SignReader.Reading.UNREADABLE, SignReader.reading(SignReader.parse("Zona traffico limitato"), at(2026, 7, 13, 12)))
        assertEquals(Tono.GIALLO, SignReader.Reading.SEEMS_OFF.tono)
        assertEquals(Tono.GIALLO, SignReader.Reading.UNREADABLE.tono)
        assertEquals(Tono.ROSSO, SignReader.Reading.ACTIVE.tono)
        assertTrue(SignReader.Reading.entries.none { it.tono == Tono.VERDE || it.tono == Tono.SPENTO })
        val tools = src("java/app/gatelr/Tools.kt")
        assertFalse("Palette.green" in tools.substringAfter("fun SignReaderScreen").substringBefore("fun FineGuide"), "mai verde dal cartello")
        assertFalse("you may drive in" in tools)
        assertTrue("SignReader.reading(result, now)" in tools)
    }

    // ---- B11 «Adesso» e widget come PlaceCheck

    private fun adesso(p: Coordinate, v: Vehicle, t: Instant) = Adesso.resolve(cities, p, null, t) { z, w -> engine.trustedAnswer(z, v, emptyList(), false, w) }
    private fun place(p: Coordinate, v: Vehicle, t: Instant) = PlaceCheck.of(cities, p, engine, v, emptyList(), false, t)

    @Test fun b11AdessoAnswersLikePlaceCheck() {
        val cases = listOf(
            Triple(Coordinate(45.06251, 7.68623), rental, at(2026, 11, 11, 11)),          // Torino, via Accademia Albertina
            Triple(Coordinate(43.76934, 11.25563), oldDiesel, at(2026, 11, 11, 23)),      // Firenze, Palazzo Vecchio
            Triple(Coordinate(43.77310, 11.25596), oldDiesel, at(2026, 11, 11, 23)),      // Firenze, Duomo
        )
        for ((p, v, t) in cases) {
            val expected = place(p, v, t).finale
            val got = adesso(p, v, t)
            assertEquals(expected.stato, got.final.stato, "Adesso = PlaceCheck in $p")
            assertEquals(0.0, got.meters)
        }
        assertTrue("Adesso.resolve(" in src("java/app/gatelr/NowAnswer.kt"), "Adesso e widget leggono Adesso.resolve")
    }

    @Test fun b11ManyPointsSameAnswerAsPlaceCheck() {
        // Tutti i varchi delle città: dentro (un passo verso il centro della zona) Adesso e PlaceCheck dicono lo stesso
        val t = at(2026, 11, 11, 23)
        var inside = 0
        for (c in cities) for (z in c.zones) for (g in z.gates.take(3)) {
            val p = Coordinate(g.location.lat + (c.center.lat - g.location.lat) * 0.05, g.location.lon + (c.center.lon - g.location.lon) * 0.05)
            val pc = place(p, oldDiesel, t)
            if (pc.hits.isEmpty() && pc.pedestrian == null) continue
            inside++
            assertEquals(pc.finale.stato, adesso(p, oldDiesel, t).final.stato, "${z.id} vicino a ${g.name}")
        }
        assertTrue(inside > 20, "abbastanza punti dentro ($inside)")
    }

    // ---- B12 mappa colorata per risposta

    private fun zone(id: String) = cities.flatMap { c -> c.zones.map { c to it } }.first { it.second.id == id }

    @Test fun b12MapColorsByAnswer() {
        val diesel4 = Vehicle(name = "Golf", fuel = Fuel.DIESEL, euro = 4)
        val (milano, areaB) = zone("milano-b")
        val tue = at(2026, 11, 10, 10)
        val a = engine.trustedAnswer(areaB, diesel4, emptyList(), false, tue)
        assertNotEquals(Tono.VERDE, MappaRisposte.tono(a, areaB, milano), "Area B non è verde per un diesel Euro 4")
        assertEquals(RispostaFinale.forZone(a, areaB, milano.status, milano).color, MappaRisposte.tono(a, areaB, milano))
        // Una ZTL spenta non è rossa: è la ZTL non attiva (STATE_OFF)
        val (firenze, settoreA) = zone("firenze-a")
        val night = at(2026, 11, 11, 23)
        val off = engine.trustedAnswer(settoreA, rental, emptyList(), false, night)
        if (!off.gatesOn) assertEquals(RispostaFinale.STATE_OFF, MappaRisposte.tono(off, settoreA, firenze))
        // La legenda: risposte, non tipi
        assertTrue(MappaRisposte.legend.isNotEmpty())
        assertEquals(Tono.ROSSO, MappaRisposte.pedestrian)
        val map = src("java/app/gatelr/MapScreen.kt")
        assertFalse("Palette.kind(" in map, "la mappa non colora più per tipo")
        assertTrue("MappaRisposte.tono(" in map && "MappaRisposte.legend" in map)
    }

    // ---- B31 widget

    @Test fun b31WidgetWakesAtChangeAndEvery30Minutes() {
        val now = at(2026, 11, 11, 7, 10)
        val change = at(2026, 11, 11, 7, 30)
        assertEquals(change.plusMillis(WidgetSchedule.AFTER_CHANGE_MS), WidgetSchedule.next(change, now))
        assertEquals(now.plusMillis(WidgetSchedule.MAX_WAIT_MS), WidgetSchedule.next(null, now))
        assertEquals(now.plusMillis(WidgetSchedule.MAX_WAIT_MS), WidgetSchedule.next(at(2026, 11, 11, 20), now))
        assertEquals(now.plusMillis(WidgetSchedule.MAX_WAIT_MS), WidgetSchedule.next(at(2026, 11, 11, 6), now), "mai nel passato")
        assertEquals("Updated 7:31", WidgetSchedule.updatedLine(at(2026, 11, 11, 7, 31)))
        val w = src("java/app/gatelr/ZoneWidget.kt")
        assertTrue("setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP" in w, "allarme che vale anche in Doze")
        assertFalse(".set(AlarmManager.RTC" in w)
        assertTrue("WidgetSchedule.updatedLine" in w, "il widget dice quando si è aggiornato")
    }

    // ---- B80 permesso dato dalle Impostazioni

    @Test fun b80LocationPermissionReadOnResumeAndAsk() {
        val main = src("java/app/gatelr/MainActivity.kt")
        val resume = main.substringAfter("override fun onResume()").substringBefore("override fun")
        assertTrue("Here.allowed = GuardianService.canStart(this)" in resume)
        val perm = src("java/app/gatelr/Permissions.kt").substringAfter("fun ask(")
        assertTrue(perm.indexOf("Here.allowed = GuardianService.canStart(ctx)") in 0 until perm.indexOf("if (needs.isEmpty()"))
    }

    // ---- B81 Indietro

    @Test fun b81BackClosesPlaceThenGoesHome() {
        assertEquals(BackStep.Action.CLOSE_PLACE, BackStep.next(2, hasPlace = true, hasPin = false))
        assertEquals(BackStep.Action.GO_NOW, BackStep.next(2, hasPlace = false, hasPin = false))
        assertEquals(BackStep.Action.CLOSE_PIN, BackStep.next(1, hasPlace = true, hasPin = true))
        assertEquals(BackStep.Action.GO_NOW, BackStep.next(1, hasPlace = true, hasPin = false))
        assertEquals(BackStep.Action.GO_NOW, BackStep.next(3, hasPlace = true, hasPin = true))
        assertEquals(BackStep.Action.EXIT, BackStep.next(0, hasPlace = true, hasPin = true))
        assertTrue("BackStep.next(Nav.tab, AppState.place != null, Nav.mapPin != null)" in src("java/app/gatelr/MainActivity.kt"))
    }

    // ---- B82 rotazione

    @Test fun b82ChoicesSurviveRotation() {
        val trip = src("java/app/gatelr/TripScreen.kt")
        for (s in listOf("var arrival by rememberSaveable(", "var hotelInside by rememberSaveable(", "var nights by rememberSaveable(", "var saved by rememberSaveable("))
            assertTrue(s in trip, s)
        val garage = src("java/app/gatelr/GarageScreen.kt")
        for (f in listOf("name", "model", "plate", "fuel", "euro", "year", "rental", "type")) assertTrue("var $f by rememberSaveable(" in garage, f)
        assertTrue("var editingId by rememberSaveable" in garage)
    }

    // ---- B83 ora d'arrivo tradotta

    @Test fun b83ArrivalChoicesTranslated() {
        val keys = listOf("Now", "In 1 hour", "This evening", "Tomorrow morning")
        for (lang in Lingua.SUPPORTED - "en") {
            val t = Json.parseToJsonElement(File(i18n, "strings_$lang.json").readText()).jsonObject
            for (k in keys) {
                val v = t[k]?.jsonPrimitive?.content
                assertNotNull(v, "$lang: $k"); assertNotEquals(k, v, "$lang: $k")
            }
        }
        Strings.language = "it"; Strings.table = table("it")
        assertEquals(listOf("Adesso", "Tra un'ora", "Stasera", "Domani mattina"), keys.map { L(it) })
    }

    // ---- B85 backup

    @Test fun b85NoCloudBackup() {
        val m = src("AndroidManifest.xml")
        assertTrue("android:allowBackup=\"false\"" in m)
        assertTrue("android:dataExtractionRules=\"@xml/data_extraction_rules\"" in m)
        val rules = src("res/xml/data_extraction_rules.xml")
        assertTrue("<cloud-backup>" in rules && "<device-transfer>" in rules)
        assertEquals(2, Regex("""<exclude domain="sharedpref" path="\." />""").findAll(rules).count())
    }

    // ---- B86 promemoria

    @Test fun b86RemindersSurviveReboot() {
        val now = at(2026, 11, 11, 8).toEpochMilli()
        var book = ReminderBook.add(emptyList(), SavedReminder("ticket|bologna-ztl", now + 3_600_000, "t", "b"), now)
        book = ReminderBook.add(book, SavedReminder("ticket|bologna-ztl", now + 7_200_000, "t2", "b2"), now)
        assertEquals(1, book.size, "stessa chiave: sostituito")
        book = ReminderBook.add(book, SavedReminder("stay|x", now - 60_000, "s", "b"), now)
        val after = ReminderBook.toReschedule(book, now)
        assertEquals(2, after.size)
        assertTrue(after.all { it.at >= now }, "un promemoria scaduto a telefono spento arriva subito, non mai")
        assertEquals(emptyList(), ReminderBook.prune(book, now + 3 * 24 * 3_600_000L))
        assertEquals(1, ReminderBook.remove(book, "stay|x").size)
        val m = src("AndroidManifest.xml")
        assertTrue("android.permission.RECEIVE_BOOT_COMPLETED" in m && "android.intent.action.BOOT_COMPLETED" in m && ".BootReceiver" in m)
        val r = src("java/app/gatelr/Reminders.kt")
        assertTrue("setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP" in r)
        assertFalse(".set(AlarmManager.RTC_WAKEUP" in r)
    }

    // ---- B87 ticket solo con la zona attiva e fuori dalle aree pedonali

    @Test fun b87TicketOnlyWhenActive() {
        val (milano, areaC) = zone("milano-c")
        val sunday = at(2026, 11, 8, 11); val tuesdayNight = at(2026, 11, 10, 23); val tuesday = at(2026, 11, 10, 10)
        assertFalse(TicketShow.visible(areaC, null, engine.isActive(areaC, sunday)), "domenica Area C spenta")
        assertFalse(TicketShow.visible(areaC, null, engine.isActive(areaC, tuesdayNight)))
        assertTrue(TicketShow.visible(areaC, null, engine.isActive(areaC, tuesday)))
        val ped = milano.pedestrian!!.first()
        assertFalse(TicketShow.visible(areaC, ped, true), "nell'area pedonale niente ticket")
        assertFalse(TicketShow.visible(null, null, true))
        assertTrue("TicketShow.visible(" in src("java/app/gatelr/TripScreen.kt"))
    }

    // ---- B88 avviso «Bozza»

    @Test fun b88DraftBanner() {
        val (firenze, a) = zone("firenze-a")
        assertEquals(City.Status.DRAFT, firenze.status)
        assertEquals("Draft: from official sources, not yet reviewed by a person", CityBanner.text(firenze, a))
        assertNull(CityBanner.text(firenze.copy(status = City.Status.VERIFIED), a))
        assertEquals("Sample data, not real", CityBanner.text(firenze.copy(status = City.Status.SAMPLE), a))
        val unofficial = cities.flatMap { c -> c.zones.map { c to it } }.firstOrNull { it.second.isUnofficial }
        unofficial?.let { (c, z) -> assertNull(CityBanner.text(c, z), "fonte non ufficiale: l'avviso è già nella risposta") }
        assertNull(CityBanner.text(null, null))
        assertTrue("CityBanner.text(" in src("java/app/gatelr/HomeScreen.kt") && "CityBanner.text(" in src("java/app/gatelr/TripScreen.kt"))
    }

    // ---- B160 posizione vecchia

    @Test fun b160OldPositionIsNotWhereYouAre() {
        val now = 1_800_000_000_000L
        assertTrue(Freshness.isFresh(now - 60_000, now))
        assertFalse(Freshness.isFresh(now - 24 * 3_600_000L, now), "di ieri non vale")
        assertFalse(Freshness.isFresh(0, now), "senza ora non vale")
        assertFalse(Freshness.isFresh(now + 3_600_000, now))
        assertTrue("val here = Here.fresh" in src("java/app/gatelr/HomeScreen.kt"))
        assertTrue("Freshness.isFresh(it.time" in src("java/app/gatelr/MainActivity.kt"))
    }

    // ---- B161 lingua dell'app

    @Test fun b161AppLanguageReloaded() {
        assertEquals("de", Lingua.pick("de")); assertEquals("zh", Lingua.pick("zh-Hans")); assertEquals("en", Lingua.pick("ja"))
        assertEquals("en", Lingua.pick(null)); assertEquals("en", Lingua.pick("pt"))
        val main = src("java/app/gatelr/MainActivity.kt").substringAfter("override fun onCreate(").substringBefore("setContent")
        assertTrue("AppState.loadStrings(this)" in main)
    }

    // ---- B162 testi della prima pagina

    @Test fun b162HomeTexts() {
        Strings.language = "it"; Strings.table = table("it")
        assertEquals("1 attiva", HomeText.activeCount(1))
        assertEquals("3 attive", HomeText.activeCount(3))
        assertEquals("Tutto libero", HomeText.activeCount(0))
        assertEquals("ZTL non attiva", HomeText.zoneLine(ZoneKind.RESTRICTED, false), "non «ZTL · ZTL non attiva»")
        assertEquals(L("Green zone") + " · ZTL attiva", HomeText.zoneLine(ZoneKind.GREEN, true))
        val home = src("java/app/gatelr/HomeScreen.kt")
        assertFalse("GateLR covers Florence" in home)
        assertTrue("HomeText.activeCount(" in home && "HomeText.zoneLine(" in home)
    }

    // ---- B164, B165 mappa in orizzontale e tastiera

    @Test fun b164MapCardScrolls() {
        val card = src("java/app/gatelr/MapScreen.kt").substringAfter("pin?.let { p ->").substringBefore("Text(p.name")
        assertTrue("heightIn(max = maxH)" in card && "verticalScroll(" in card)
    }

    @Test fun b165SearchAboveKeyboard() {
        assertTrue(".imePadding()" in src("java/app/gatelr/WhereTo.kt"))
    }

    // ---- B166 città dalla posizione a ogni apertura

    @Test fun b166CityFromPositionEveryOpening() {
        val g = CityFromPositionGate()
        assertTrue(g.shouldAdopt()); assertFalse(g.shouldAdopt(), "una volta per apertura")
        g.newOpening(); assertTrue(g.shouldAdopt(), "riaperta: di nuovo")
        g.newOpening(); g.choseByHand(); assertFalse(g.shouldAdopt(), "scelta a mano: la posizione non la cambia")
        assertTrue("if (savedInstanceState == null) AppState.newOpening()" in src("java/app/gatelr/MainActivity.kt"))
    }

    // ---- B169, B173 widget

    @Test fun b169WidgetTitleFits() {
        for (lang in Lingua.SUPPORTED) {
            if (lang == "en") { Strings.language = "en"; Strings.table = emptyMap() } else { Strings.language = lang; Strings.table = table(lang) }
            for (st in Stato.entries) {
                val lines = WidgetText.titleLines(st)
                assertTrue(lines.size in 1..2, "$lang $st: al massimo due righe")
                val size = WidgetText.titleSize(st, 82, 19)
                assertTrue(size in 12..19)
                val longest = lines.maxOf { it.length }
                assertTrue(longest * 0.62 * size <= 82 || size == 12, "$lang $st: «${lines}» sta in 82 dp a ${size}sp")
            }
        }
        Strings.language = "it"; Strings.table = table("it")
        assertEquals(listOf("CONTROLLA IL", "CARTELLO"), WidgetText.titleLines(Stato.CONTROLLA_CARTELLO))
    }

    @Test fun b173WidgetShowsUnofficial() {
        val unofficial = cities.flatMap { c -> c.zones.map { c to it } }.first { it.second.isUnofficial }
        val (c, z) = unofficial
        val no = RispostaFinale.forZone(Answer(Verdict.No("r"), true, null), z, c.status, c)
        assertTrue(WidgetText.extra(no, null)!!.startsWith("⚠︎"), WidgetText.extra(no, null))
        val yes = RispostaFinale.forZone(Answer(Verdict.Yes("r"), true, null), z, c.status, c)
        assertTrue(WidgetText.extra(yes, "until 20:00")!!.startsWith("⚠︎"))
        val (fc, fz) = zone("firenze-a")
        assertEquals("until 20:00", WidgetText.extra(RispostaFinale.forZone(Answer(Verdict.No("r"), true, null), fz, fc.status, fc), "until 20:00"))
        val desc = src("res/values-it/strings.xml")
        assertFalse("La ZTL che hai scelto" in desc)
    }

    // ---- B176 un solo formato del prezzo

    @Test fun b176OnePriceFormat() {
        fun n(s: String) = s.replace(' ', ' ').replace(' ', ' ')
        assertEquals("7,50 €", n(Money.euro(7.5, "it")))
        assertEquals("€7.50", n(Money.euro(7.5, "en")))
        Strings.language = "it"; Strings.table = table("it")
        val (_, areaC) = zone("milano-c")
        val a = engine.answer(areaC, rental, emptyList(), false, at(2026, 11, 10, 10))
        val cond = (a.verdict as Verdict.Conditional).condition
        assertTrue(Money.euro(areaC.ticket!!.price) in cond, cond)
        assertFalse("€7" in cond.replace("7,50 €", ""), cond)
        assertFalse("String.format(Locale.ITALY, \"€" in src("java/app/gatelr/TripScreen.kt"))
        assertFalse("String.format(Locale.ITALY, \"€" in src("java/app/gatelr/ZoneDetail.kt"))
    }
}
