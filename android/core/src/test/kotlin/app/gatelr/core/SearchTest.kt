package app.gatelr.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** 1.19.5: ricerca orientata alla città giusta e memoria delle risposte */
class SearchTest {
    private val firenze = Coordinate(43.7712, 11.2550)
    private val milano = Coordinate(45.4642, 9.1900)

    @Test fun nearUsesLocationInsideTheCity() {
        val inFirenze = Coordinate(43.78, 11.24)
        assertEquals(inFirenze, SearchPlan.near(inFirenze, firenze))
    }

    @Test fun nearUsesTheChosenCityWhenFarAway() {
        // da Milano, preparando il viaggio a Firenze: i risultati vicino a Firenze
        assertEquals(firenze, SearchPlan.near(milano, firenze))
        assertEquals(firenze, SearchPlan.near(null, firenze))
    }

    @Test fun sameQuestionSameKey() {
        val a = SearchPlan.key("  Hotel Brunelleschi ", "it", Coordinate(43.7731, 11.2580))
        val b = SearchPlan.key("hotel brunelleschi", "it", Coordinate(43.7712, 11.2610))
        assertEquals(a, b)
        assertNotEquals(a, SearchPlan.key("hotel brunelleschi", "en", firenze))
        assertNotEquals(a, SearchPlan.key("hotel brunelleschi", "it", milano))
    }

    @Test fun shortQueriesDontAsk() {
        assertTrue(!SearchPlan.worthAsking("ab "))
        assertTrue(SearchPlan.worthAsking("via"))
    }

    @Test fun recentCacheKeepsTheLastOnes() {
        val c = RecentCache<String, Int>(3)
        c["a"] = 1; c["b"] = 2; c["c"] = 3
        c["a"]                       // usata di recente: resta
        c["d"] = 4
        assertNull(c["b"]); assertEquals(1, c["a"]); assertEquals(3, c.size)
    }

    /** Misura nel JVM: chiave e memoria costano microsecondi, contro centinaia di ms di una richiesta a Photon */
    @Test fun cacheLookupIsCheap() {
        val c = RecentCache<String, List<Place>>(40)
        val keys = (0 until 40).map { SearchPlan.key("via numero $it", "it", firenze) }
        keys.forEach { c[it] = emptyList() }
        val t0 = System.nanoTime()
        repeat(100_000) { c[keys[it % 40]] }
        val perLookupUs = (System.nanoTime() - t0) / 100_000.0 / 1000
        println("RecentCache: %.3f µs per ricerca in memoria".format(perLookupUs))
        assertTrue(perLookupUs < 50)
    }
}
